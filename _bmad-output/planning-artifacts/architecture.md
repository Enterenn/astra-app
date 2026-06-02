---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - prds/prd-astra-app-2026-05-22/prd.md
  - prds/prd-astra-app-2026-05-22/addendum.md
  - ux-design-specification.md
  - research/market-astra-local-first-health-hub-research-2026-05-22.md
  - research/domain-astra-local-first-health-hub-research-2026-05-22.md
  - ../brainstorming/brainstorming-session-2026-05-22-1521.md
workflowType: architecture
project_name: astra-app
user_name: Baptiste
date: 2026-05-22
lastStep: 8
status: complete
completedAt: 2026-05-22
amended: 2026-05-22 — adversarial review pass (naming, write path, SQL local_day, idempotency, DI, iOS, lifecycle, notifications)
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

ASTRA Phase 0 defines 31 FRs across a layered mobile architecture. The core data pipeline is: `DataIngestionSource` implementations (phone pedometer today, ADP BLE stub tomorrow) → `StepNormalizer` → `BackgroundCollector` (single ingestion writer) → SQLite `timeseries_samples` → UI queries and `DataLifecycleService` maintenance. This abstraction (FR-1–3, FR-7–8) is the primary extensibility mechanism for Phase 1+ without refactoring persistence.

Three user-facing surfaces (Today, History, My Data) plus onboarding map directly to architectural modules. My Data is architecturally first-class — footprint, background status, CSV export/import, and purge (FR-5, FR-13, FR-18–21, FR-30) are sovereignty features, not settings afterthoughts. Background collection (FR-4–6) and local notifications (FR-25) require platform-native services decoupled from UI lifecycle.

Dev/OSS FRs (FR-26–29) impose architectural observability: 90-day inject benchmark, lifecycle simulator, dependency audit, and beta checklist traceability.

**Non-Functional Requirements:**

| NFR | Architectural driver |
|-----|---------------------|
| NFR-1 (<100ms charts) | Pre-aggregated `ChartDayAggregate` via `LocalDayCalculator`; benchmark p95 < 100ms; no animation on chart rebind |
| NFR-2 (<50MB install) | Minimal dependency set; no analytics/cloud SDKs |
| NFR-3 (100% offline) | No network in health pipeline; release builds without INTERNET permission |
| NFR-4 (plaintext OK Phase 0) | SQLCipher migration path documented; Keystore escrow Phase 1 |
| NFR-5 (WCAG AA aspirational) | Semantics, contrast tokens in light and dark themes, reduce-motion variants in UX spec |
| NFR-6 (English UI) | i18n-ready structure but single locale Phase 0 |
| NFR-7/8 (storage budgets) | Tiered downsampling + scheduled/opportunistic VACUUM; destructive compaction |
| NFR-9 (time semantics) | UTC storage + immutable `zone_offset`; local-day aggregation for goals |

**Scale & Complexity:**

- Primary domain: **Flutter mobile app** (local-first health hub)
- Complexity level: **Medium-high** for Phase 0 scope — constrained feature breadth but demanding non-functional guarantees (background persistence, chart perf, zero-network proof, lifecycle bounds)
- Estimated architectural components: **8–10 modules** (ingestion, collector, persistence/DAO, lifecycle, export/import, notifications, UI shell, onboarding, dev tools)

### Technical Constraints & Dependencies

**Platform:**

- Android = reference platform (WorkManager, `FOREGROUND_SERVICE_HEALTH`, continuous background target)
- iOS = secondary (foreground backfill + rare BGAppRefresh; honest stale UI — no parity promise)

**Background trust & GPS guardrails:** See [background-trust-and-movement-validation.md](./background-trust-and-movement-validation.md) — process-alive vs killed promises, layered catch-up (live monitor, WM, backfill), sovereignty-safe GPS rules (ephemeral on-device only, no stored trails).

**Stack (Phase 0, from addendum):** `pedometer`, `sqflite`, `workmanager`, `flutter_local_notifications`, `fl_chart`, `share_plus`, `permission_handler`. Explicitly excluded: `open_wearables_health_sdk`, analytics SDKs, HTTP in health pipeline.

**Android manifest (FR-6, FR-29):** `FOREGROUND_SERVICE_HEALTH` and related FGS declarations are configured in `AndroidManifest.xml`, not via `permission_handler`. Release manifest verification (no INTERNET, correct FGS type) must be part of dev tooling and beta checklist — not assumed from runtime permission flows alone.

**Data model:** OW-aligned `timeseries_samples` + `user_preferences`; 5-minute default buckets; steps/count only Phase 0. Canonical shape in PRD §4.3.1 / addendum §2.

**Regulatory guardrails:** General Wellness Product only; CNIL local-only exemption valid while no cloud/account. V2+ sync hub reintroduces full GDPR/HDS obligations (documented, out of Phase 0 scope).

**Team:** Solo builder, Flutter novice — architecture must favor mature packages, clear module boundaries, and learning-friendly patterns over premature abstraction.

**Product maturity clause (PRD §1.5):** Implementation may evolve during Flutter learning provided invariants hold: local-first, no-cloud/no-account, `DataIngestionSource` abstraction, lifecycle bounds, proof over promises.

### Cross-Cutting Concerns Identified

1. **Ingestion write path** — Only `BackgroundCollector` may call `StepRepository.upsertIngestionBucket()` (sensor → bucket pipeline). All SQLite writes go through `StepRepository`; see Administrative writes below.

2. **Isolate-aware persistence + WAL** — WorkManager runs in a separate Dart isolate. Each isolate opens its own DB handle via `getDatabasesPath()`. On every connection open, execute explicitly:
   ```dart
   await db.execute('PRAGMA journal_mode=WAL;');
   await db.execute('PRAGMA foreign_keys = ON;');
   ```
   Do not rely on implicit defaults — concurrent UI + WorkManager access depends on WAL.

3. **Privacy-by-architecture** — Release manifest without INTERNET; dependency audit; no silent cloud; verifiable export/purge/airplane-mode flows.

4. **Time semantics** — UTC + immutable `zone_offset` per row. **`local_day` is always computed using each row's stored `zone_offset`, never the device's current timezone.** Applies to Today totals, History aggregation, goal evaluation, celebration flags, and chart queries. Prevents travel/DST refactor from shifting historical days.

5. **Bucket identity** — Each 5-minute bucket is uniquely identified by `(provider, device_id, type, start_time, end_time, resolution)`. Enforced via `UNIQUE` index. Ingestion uses upsert/replace on bucket identity; CSV import uses `INSERT OR IGNORE` on UUID `id`. Prevents double ingestion, reboot duplicates, and ambiguous imports.

6. **Step normalization** — Android/iOS pedometer APIs expose cumulative since-boot values, not storage-ready deltas. A dedicated `StepNormalizer` converts raw readings → bucket increments (reboot, counter reset, negative delta, overflow, day rollover). Must not be split across datasource and repository.

7. **Destructive lifecycle** — Downsampling is irreversible; export-before-compaction matters; footprint UI must reflect post-compaction state.

8. **Platform abstraction with honest UX** — `DataIngestionSource` + platform-specific background strategies; UI reflects iOS limitations without blaming users. **WorkManager is orchestration, not guaranteed realtime execution** — on Android, FGS health + periodic sync + opportunistic reconciliation coexist; WorkManager alone does not promise continuous 5-minute cadence.

9. **Performance as architecture constraint** — KPI-01 drives repository-side aggregation into `ChartDayAggregate` via `LocalDayCalculator`; UI/widgets perform zero business aggregation.

10. **Background health evaluation** — `BackgroundHealthCapabilityEvaluator` centralizes permission/capability checks (activity recognition, battery optimization, notifications, FGS health, OEM restrictions). Prevents scattered permission logic across screens.

11. **Extensibility without over-engineering** — ADP stub, SQLCipher migration path, Health Connect deferred Phase 1.

12. **OSS credibility** — Apache 2.0, schema docs, inject tools, beta checklist.

13. **Transaction boundaries** — Multi-row operations (CSV import, lifecycle downsampling, batch ingestion, purge, reconciliation) **MUST** run inside SQLite transactions. Repository methods own transaction scope; UI/Cubits never compose or open transactions. Prevents partial writes and 500 non-transactional inserts from agent drift.

### Recommended lib/ Structure (Preview)

Simplified clean architecture aligned with PRD modules and solo-builder learning curve:

```
lib/
├── core/
│   ├── constants/        # Design tokens, default goal (8000)
│   ├── database/         # sqflite init, migrations, isolate-safe factory + WAL PRAGMAs
│   ├── di/               # app_dependencies.dart — composition root
│   ├── time/             # time_provider.dart, local_day_calculator.dart
│   └── services/         # BackgroundCollector, DataLifecycleService, BackgroundHealthCapabilityEvaluator, WorkManager, notifications
├── data/
│   ├── datasources/      # PhonePedometerSource, AdpBleSource stub, StepNormalizer
│   ├── models/           # TimeseriesSampleModel, ChartDayAggregate, ImportResult
│   └── repositories/     # StepRepository — all SQLite reads/writes
└── presentation/
    ├── cubits/
    ├── onboarding/       # Trust-first flow (FR-22)
    ├── screens/          # Today, History, My Data
    └── widgets/          # GoalRing, chart wrappers
```

_Confirmed in Project Structure & Boundaries section._

## Starter Template Evaluation

### Primary Technology Domain

**Flutter mobile application** (Android + iOS) — local-first health hub with no backend, based on project context analysis.

### Starter Options Considered

| Option | Assessment |
|--------|------------|
| **`flutter create` (official, `--empty`)** | ✅ Selected — minimal scaffold, mature docs, LLM-friendly, no unwanted dependencies |
| **`flutter create -t skeleton`** | ❌ Rejected — demo ListView/Settings UI not aligned with ASTRA three-surface shell |
| **FlutterForge / third-party boilerplates** | ❌ Rejected — impose Riverpod, Dio, Hive; incompatible with sqflite-only, zero-network PRD |
| **Very Good CLI / Mason bricks** | ⏸ Deferred — useful for CI/testing later, not Sprint 0 priority |

### Selected Starter: Flutter CLI Official (`--empty`)

**Rationale for Selection:**

- Greenfield project (no existing `pubspec.yaml` in repo)
- Solo Flutter novice — official template minimizes magic and maximizes documentation/examples
- `--empty` yields clean `main.dart` for custom `lib/` structure (preview in Project Context Analysis)
- `--platforms=android,ios` excludes web/desktop noise (PRD: mobile-only)
- Kotlin Android (recommended default) + Swift iOS (default since Flutter 3.44, SwiftPM migration)

**Initialization Command** (repo root = Flutter app root):

```bash
flutter channel stable
flutter upgrade
# From astra-app/ repo root (contains docs/, _bmad-output/, etc.)
flutter create . \
  --org com.astraapp \
  --project-name astra_app \
  --platforms=android,ios \
  --android-language=kotlin \
  --empty
```

> **Naming:** Product/repo = **`astra-app`**. Dart package (`pubspec.yaml` `name:`) = **`astra_app`** (hyphens invalid in Dart identifiers). DB file = **`astra_app.db`**. Bundle ID = **`com.astraapp`** (locked, D-18). Project initialization should be the **first implementation story**.

**Verified baseline (2026-05-22):** Flutter **3.44.0** stable ([Flutter CLI docs](https://docs.flutter.dev/reference/flutter-cli), updated 2026-05-05).

**Architectural Decisions Provided by Starter:**

| Area | Decision |
|------|----------|
| **Language & Runtime** | Dart 3.x; Kotlin (Android native); Swift (iOS native) |
| **Styling** | Material/Cupertino widgets (customized via Astra design tokens in Phase 0) |
| **Build Tooling** | Gradle (Android), Xcode/SwiftPM (iOS), `flutter build apk` / `flutter build ipa` |
| **Testing** | Default `flutter_test` widget test scaffold |
| **Linting** | `analysis_options.yaml` + `flutter_lints` package |
| **Code Organization** | Default `lib/main.dart` — replaced by layered `lib/` structure in Sprint 0 |
| **Dev Experience** | Hot reload, DevTools, platform runners |

**Not provided by starter (Sprint 0 additions):** sqflite, workmanager, pedometer, fl_chart, flutter_local_notifications, share_plus, permission_handler, state management (Cubit/Provider), Astra design tokens, release manifest hardening.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**

| # | Decision | Choice | Version |
|---|----------|--------|---------|
| D-01 | Local database | SQLite via `sqflite` | ^2.4.2+1 |
| D-02 | Data model | OW-aligned `timeseries_samples` + `user_preferences` | PRD §4.3.1 |
| D-03 | Ingestion write path | Only `BackgroundCollector` → `StepRepository.upsertIngestionBucket()` | FR-4 |
| D-04 | Background orchestration | `workmanager` orchestrates; FGS + periodic sync for Android; not guaranteed realtime | ^0.9.0+3 |
| D-05 | Step ingestion | `pedometer` direct sensor (Health Connect Phase 1) | ^4.2.0 |
| D-06 | DB access pattern | Isolate-safe factory + explicit WAL + foreign_keys PRAGMAs | ChatGPT + Gemini |
| D-07 | Chart data queries | SQL aggregation by local day — max ~31 points to `fl_chart` | NFR-1 |
| D-08 | Release network policy | No INTERNET in release manifest; debug exception only | FR-18 |

**Important Decisions (Shape Architecture):**

| # | Decision | Choice | Version |
|---|----------|--------|---------|
| D-09 | State management | **Cubit** (`flutter_bloc`) — lighter than full BLoC | ^9.1.1 |
| D-10 | Navigation | Bottom tab shell (Today / History / My Data) + onboarding modal stack | UX §2.1 |
| D-11 | Charts | `fl_chart` bar charts with pre-aggregated daily data | ^1.2.0 |
| D-12 | Notifications | `flutter_local_notifications` — local only, no FCM | ^21.0.0 |
| D-13 | Permissions | `permission_handler` for activity recognition; manifest for FGS | ^12.0.1 |
| D-14 | CSV export | `share_plus` — platform share sheet, no upload | ^13.1.0 |
| D-15 | Schema migrations | Numbered migrations from v1 (`sqflite` `onUpgrade`) | FR-10 |
| D-16 | CSV import idempotency | `INSERT OR IGNORE` on UUID `id` field | FR-30 |
| D-17 | Build variants | Debug (INTERNET allowed for Flutter tooling) vs Release (no INTERNET) | FR-18, A-14 |
| D-18 | Bundle ID | `com.astraapp` | Locked |
| D-26 | Project naming | Repo/product `astra-app`; Dart package `astra_app`; DB `astra_app.db` | User decision |
| D-19 | Bucket identity | `UNIQUE(provider, device_id, type, start_time, end_time, resolution)` | ChatGPT review |
| D-20 | Step normalization | `StepNormalizer` — cumulative sensor → bucket deltas | FR-2, ChatGPT |
| D-21 | Chart view models | Repository returns `ChartDayAggregate`; UI never aggregates | NFR-1, ChatGPT |
| D-22 | Layering model | Pragmatic 3-layer (core / data / presentation) — no artificial DDD domain folder | ChatGPT review |
| D-23 | Background health | `BackgroundHealthCapabilityEvaluator` centralizes capability checks | ChatGPT review |
| D-24 | Transaction scope | Repository-owned SQLite transactions for all multi-row writes | ChatGPT review |
| D-25 | Clock source | Injected `TimeProvider` — no `DateTime.now()` in ingestion/lifecycle | ChatGPT review |

**Deferred Decisions (Post-MVP):**

| Decision | Target | Rationale |
|----------|--------|-----------|
| SQLCipher encryption | Phase 1 | Plaintext acceptable Phase 0 (NFR-4) |
| Health Connect / HealthKit path | Phase 1 | Pedometer sufficient for sandbox |
| BLE / ADP wire protocol | Phase 1–2 | Stub only in Phase 0 |
| CI/CD pipeline (GitHub Actions) | Post-beta | Not blocking Sprint 0 learning |
| i18n / French UI | Post Phase 0 | English UI Phase 0 (NFR-6) |
| ASTRA sync hub (self-host + managed) | V2+ | Full GDPR/HDS stack required |

### Data Architecture

**Database:** SQLite on-device via `sqflite ^2.4.2+1`. No Hive, Isar, or remote DB.

**Schema (Phase 0)** — canonical DDL (matches PRD addendum §2; implement in `migrations.dart` v1):

```sql
CREATE TABLE IF NOT EXISTS timeseries_samples (
    id TEXT PRIMARY KEY,              -- UUID v4
    start_time TEXT NOT NULL,         -- ISO 8601 UTC
    end_time TEXT NOT NULL,
    type TEXT NOT NULL,               -- 'steps' Phase 0
    value REAL NOT NULL CHECK (value >= 0),
    unit TEXT NOT NULL,               -- 'count'
    resolution TEXT NOT NULL,         -- '5min' | '1hour' | '1d'
    provider TEXT NOT NULL,
    device_id TEXT NOT NULL,
    zone_offset TEXT NOT NULL,        -- e.g. '+02:00', immutable per row
    CHECK (type <> 'steps' OR value = CAST(value AS INTEGER))
);
CREATE INDEX IF NOT EXISTS idx_timeseries_query
    ON timeseries_samples (type, start_time DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_bucket_identity
    ON timeseries_samples (provider, device_id, type, start_time, end_time, resolution);
CREATE TABLE IF NOT EXISTS user_preferences (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

**DB initialization PRAGMAs (every connection open):**

```dart
await db.execute('PRAGMA journal_mode=WAL;');
await db.execute('PRAGMA foreign_keys = ON;'); // no FK constraints Phase 0; enabled for future schema
```

**Write model (formalized):**

| Write category | Allowed callers | Repository method | Operations |
|----------------|-----------------|-------------------|------------|
| **Ingestion writes** | `BackgroundCollector` only | `StepRepository.upsertIngestionBucket()` | Upsert 5-min buckets from sensors |
| **Administrative writes** | `DataLifecycleService`, `MyDataCubit` (user actions) | `importCsv()`, `downsample()`, `purge()` | CSV import, lifecycle compaction, purge |

**All SQLite writes go through `StepRepository` methods** — no direct `db.insert()` outside the repository. `BackgroundCollector` is the **only caller** of ingestion write methods; it never opens the database itself. UI/Cubits call repository **read** methods and explicit administrative methods (import/purge) only. "Single-writer" refers to **ingestion callers**, not bypassing the repository.

**StepNormalizer (D-20):** Sits between `DataIngestionSource` implementations and `BackgroundCollector`. `DataIngestionSource` emits raw platform `StepReading` events plus source metadata; `StepNormalizer` is the only component that converts cumulative readings into storage-ready bucket increments. Handles cumulative step counter semantics: reboot baseline, counter reset (FR-2), negative delta rejection, overflow, day rollover. Unit tests mandatory for reset scenario.

**Isolate-safe persistence (D-06):** UI isolate and WorkManager isolate each open their own connection via `core/database/isolate_database_factory.dart`. Same file path via `getDatabasesPath()`. WAL mode explicit (see PRAGMAs above).

**WorkManager background isolate — acceptance criteria (Sprint 0 spike):**

- WorkManager callback MUST call `WidgetsFlutterBinding.ensureInitialized()` before any plugin/DB access
- Entrypoint: `lib/core/services/workmanager_callback.dart` with `@pragma('vm:entry-point')`
- Spike story validates: callback runs on physical Android device, writes a test bucket, UI reads it after resume
- **Fallback if isolate init fails:** log to debug channel; foreground `BackgroundCollector` backfill on app open remains mandatory (never silent data loss)
- Known risk: OEM battery optimization may defer WorkManager — handled by `BackgroundHealthCapabilityEvaluator` (see Platform Architecture)

**Local day aggregation (NFR-9):** SQLite `date()` does **not** accept ISO `zone_offset` strings. Each row may carry a different stored offset (travel). **`StepRepository` computes `local_day` in Dart** via `LocalDayCalculator` (UTC `start_time` + row's immutable `zone_offset` → calendar date key), then groups for `ChartDayAggregate`. Do not use `date(start_time, zone_offset)` in SQL — invalid.

**Read model:** Repository exposes chart-ready view models — UI performs no business aggregation:

```dart
class ChartDayAggregate {
  final DateTime localDay;  // computed from stored zone_offset per row
  final int totalSteps;
}
```

- `getTodaySteps()` — sum buckets for current local day (stored offset per row)
- `getChartDailyAggregates(days: 7|30)` → `List<ChartDayAggregate>` (~7 or ~31 items)
- `getFootprint()` — count + file size
- `exportCsv()` / `importCsv()` — OW-aligned columns

**CSV import idempotency (D-16)** — dual-key reconciliation:

| Key | Strategy | When |
|-----|----------|------|
| UUID `id` | `INSERT OR IGNORE` | Primary — ASTRA export preserves `id` column |
| Bucket identity `(provider, device_id, type, start_time, end_time, resolution)` | UNIQUE index blocks duplicates | Secondary guard if malformed CSV has new UUID but existing bucket |

**Export contract:** CSV export MUST include the `id` column unchanged. Round-trip test (export → purge → import) is mandatory (FR-30).

**Import flow:** All rows in a single transaction. `INSERT OR IGNORE` on `id`. Rows skipped due to bucket UNIQUE collision (new id, same bucket) increment `ImportResult.skippedDuplicates` — not silent corruption. Abort entire transaction on schema validation failure (FR-30).

**Transaction boundaries (D-24):** All multi-row writes run in `db.transaction()`. Applies to: CSV import, downsampling compaction, batch ingestion (dev inject), purge, reconciliation jobs. Repository methods own scope — never UI/Cubits.

```dart
await db.transaction((txn) async {
  for (final sample in samples) {
    await txn.insert('timeseries_samples', sample.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
});
```

**Clock source (D-25):** All ingestion timestamps and `zone_offset` capture MUST use an injected clock abstraction — never direct `DateTime.now()` in ingestion, lifecycle, or normalization code.

```dart
abstract class TimeProvider {
  DateTime nowUtc();
  Duration currentZoneOffset();
}
```

- Production: `SystemTimeProvider` wrapping `DateTime.now().toUtc()` + device offset
- Tests/dev simulators: `FakeTimeProvider` for DST, day-boundary, and lifecycle replay
- Rationale: deterministic tests, lifecycle simulation, import/replay correctness

**Lifecycle (addendum §3):** `DataLifecycleService` runs destructive downsampling inside transactions:

| Age | Resolution | Action |
|-----|------------|--------|
| 0–30 days | 5 min | Keep as-is |
| 31–365 days | 1 hour | Merge 12× 5-min buckets → 1 hourly; delete finer rows |
| > 365 days | 1 day | Merge 24× hourly → 1 daily; delete finer rows |

**Schedule:** Android runs a weekly WorkManager maintenance job; `PRAGMA optimize;` then `VACUUM` from a background isolate only. **`VACUUM` never on the UI thread** — can block for seconds. iOS maintenance is opportunistic: run after app foreground/resume when due, and optionally during `BGAppRefresh` if the OS grants time. Phase 0 does not rely on reliable iOS background `VACUUM` for acceptance.

**Post-compaction charts:** History queries aggregate whatever resolution exists in range — coarser buckets sum correctly. Footprint UI reflects post-compaction size (FR-13).

**Caching:** No separate cache layer — SQLite is the source of truth. Cubits refresh on triggers below.

**CSV export (FR-19):** Write file to app cache/temp directory first (`path_provider` or `getTemporaryDirectory()`), then invoke `share_plus` on the local file path. Never stream CSV directly to share sheet from in-memory-only without persisting.

**Fonts (strict offline-first):** Bundle Figtree + Darker Grotesque locally in `assets/fonts/`. Document in `docs/DEPENDENCIES.md` if any font path retains network dependency.

**Migrations:** Versioned from v1. Fresh install + upgrade paths tested (FR-10).

### Dependency Injection (Phase 0)

No DI framework Phase 0. **`AppDependencies`** class wired manually in `main.dart`:

```dart
void main() {
  final deps = AppDependencies.create(); // TimeProvider, StepRepository, collectors, evaluators
  runApp(AstraApp(deps: deps));
}
```

- `AppDependencies` holds singletons: `TimeProvider`, `StepRepository`, `UserPreferencesRepository`, `BackgroundCollector`, `BackgroundHealthCapabilityEvaluator`, `NotificationService`
- Pass `deps` to `AstraApp` → Cubits receive repositories via constructor
- Tests use `AppDependencies.test(FakeTimeProvider(...))` factory
- **Anti-pattern:** global service locator without explicit wiring in Sprint 0

### Platform Architecture (Android vs iOS)

**Android (reference platform):** FGS health + WorkManager orchestration + foreground backfill on app open. `BackgroundHealthCapabilityEvaluator` checks activity recognition, notification permission, battery optimization exemption, FGS health declaration. **OEM flows:** expose deep-link to battery optimization settings with honest copy for Samsung/Xiaomi/Huawei deferral patterns.

**iOS (secondary, no parity promise):**

- Pedometer + ingestion when app is foreground or briefly backgrounded
- Register `BGAppRefreshTask` for opportunistic backfill (best-effort, not guaranteed 5-min cadence)
- **Stale threshold:** My Data shows stale indicator if last sample > **4 hours** old
- Android stale threshold remains **12 hours** to avoid false "background dead" alerts after overnight sleep
- TestFlight deferred; architecture supports iOS build but beta targets Android sideload first
- Sprint 1 story validates BGAppRefresh registration and stale UI on simulator/device

### Notifications & Goal Celebration (FR-25)

| Trigger | Mechanism |
|---------|-----------|
| Goal reached (background) | `BackgroundCollector` after bucket upsert → `StepRepository.getTodaySteps()` → if ≥ goal and `celebration_shown_date` ≠ today → `NotificationService.showGoalReached()` + update preference |
| Goal reached (foreground) | `TodayCubit` detects on refresh → widget pulse animation (UX spec); **no duplicate notification** if preference already set |
| Dedup | `user_preferences.celebration_shown_date` = local day string; reset at local midnight via `TimeProvider` |

Evaluation uses cumulative daily steps from `timeseries_samples` aggregated by `LocalDayCalculator` — not raw pedometer delta.

### Authentication & Security

**Authentication:** None in Phase 0. No account, no OAuth, no API keys in health pipeline.

**Encryption at rest:** Plaintext SQLite Phase 0. SQLCipher migration path documented for Phase 1.

**Network security:** Release manifest must not declare INTERNET. Audit in `docs/DEPENDENCIES.md` — no FCM, Firebase, analytics, HTTP in data path. **Automated check:** `test/release_manifest_test.dart` parses `android/app/src/main/AndroidManifest.xml` and asserts no `INTERNET` permission (runs in CI post-beta or manually pre-release).

**Android 14+ compliance:** `FOREGROUND_SERVICE_HEALTH` in `AndroidManifest.xml`. Beta checklist verifies release manifest (FR-6, FR-29).

**Permissions:** Activity recognition via `permission_handler`; notification permission optional. Trust copy before permission requests (FR-22).

### API & Communication Patterns

**Remote API:** None in Phase 0.

**Inter-process:** UI isolate ↔ WorkManager isolate via DB file only (no shared memory). Platform channels for pedometer, notifications, share sheet.

**CSV interchange:** OW-aligned export/import only. No OW server API.

**Future:** ADP over BLE (Phase 1+); ASTRA sync hub REST (V2+).

### Frontend Architecture

**State management:** `flutter_bloc` Cubits only — `TodayCubit`, `HistoryCubit`, `MyDataCubit`, `OnboardingCubit`. **No reactive stream architecture Phase 0** — no Riverpod, no app-wide `Stream`/`BehaviorSubject` state graphs. Exceptions: (1) platform sensor streams (`pedometer`) owned by `LiveStepMonitor` in UI isolate — sole subscriber, fan-out via `MonitorDrainSource` to `BackgroundCollector`; (2) **approved derogation (2026-06-02):** `LiveStepMonitor.watchTodaySteps()` → `TodayCubit.attachLiveMonitor()` for real-time Today step display (throttled ~1s), not app-wide reactive state.

**Cubit refresh triggers:**

| Cubit | Refresh when |
|-------|--------------|
| `TodayCubit` | **Live steps:** `LiveStepMonitor.watchTodaySteps()` (throttled). **Metadata:** app resume → `collectOnce` + `refreshMetadata()`; `onIngestionComplete` → `refreshMetadata()` only; `AstraApp` 60s periodic persist (all tabs); returning to Today tab → `refreshMetadata()`; cold start → `refresh()` then attach live monitor; post import/purge |
| `HistoryCubit` | Tab selected; app resume; post import/purge/lifecycle |
| `MyDataCubit` | Tab selected; app resume; post import/purge/export |

**Navigation:** `AppScaffold` + `NavigationBar` (3 tabs). **No GoRouter Phase 0** — intentional solo-founder optimization: less friction, no deep-link noise, no rebuild complexity for 3 tabs.

**Components:** UX spec widgets in `presentation/widgets/`. Design tokens in `core/constants/`.

**Performance (NFR-1 / KPI-01):** Chart binds pre-aggregated `ChartDayAggregate` only; no animation on 7d/30d toggle. **Benchmark acceptance:** on mid-range Android reference device, 90-day injected dataset, History 7d↔30d toggle **p95 < 100ms** (measured in `lib/dev/` benchmark harness, FR-28). **Fonts bundled locally** in `assets/fonts/`.

**Theming:** `ThemeData.light()` + `ThemeData.dark()` + `AstraColors` extension. **System theme default** (`ThemeMode.system`); user override system/light/dark on My Data (FR-31). `ThemeCubit` drives `MaterialApp.themeMode`.

### Infrastructure & Deployment

**Hosting:** None — fully on-device.

**Distribution:** Sideload APK (Android beta primary); iOS TestFlight deferred.

**Open source:** Apache 2.0 GitHub repo (FR-26).

**Build variants:** Debug (INTERNET for Flutter tooling) vs Release (no INTERNET, health pipeline audit pass).

**CI/CD / monitoring:** Deferred post-beta. No crash analytics SDK Phase 0.

### Sprint 0 Initialization Reference

**Create project** (from repo root):

```bash
flutter channel stable
flutter upgrade
flutter create . \
  --org com.astraapp \
  --project-name astra_app \
  --platforms=android,ios \
  --android-language=kotlin \
  --empty
```

> Run from `astra-app/` root. Existing `docs/` and `_bmad-output/` remain alongside Flutter scaffold. Set `pubspec.yaml` `name: astra_app`.

**Locked `pubspec.yaml` dependencies** (verify with `flutter pub get` on target device before Sprint 0 lock):

```yaml
name: astra_app
description: ASTRA — local-first health hub
publish_to: 'none'

dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.1
  sqflite: ^2.4.2+1
  path: ^1.9.1
  uuid: ^4.4.0
  workmanager: ^0.9.0+3
  pedometer: ^4.2.0
  permission_handler: ^12.0.1
  fl_chart: ^1.2.0
  flutter_local_notifications: ^21.0.0
  share_plus: ^13.1.0
  path_provider: ^2.1.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

**Target `lib/` structure:**

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/        # astra_colors.dart, astra_typography.dart
│   ├── database/         # isolate_database_factory.dart, migrations.dart
│   ├── di/               # app_dependencies.dart
│   ├── time/             # time_provider.dart, local_day_calculator.dart, system_time_provider.dart
│   └── services/         # background_collector, data_lifecycle_service, background_health_capability_evaluator, workmanager_callback, notification_service
├── data/
│   ├── datasources/      # ingestion_source, phone_pedometer_source, adp_ble_source, step_normalizer
│   ├── models/           # timeseries_sample_model, chart_day_aggregate, import_result
│   └── repositories/     # step_repository, user_preferences_repository
├── presentation/
│   ├── cubits/           # today_cubit.dart, history_cubit.dart, my_data_cubit.dart, onboarding_cubit.dart, theme_cubit.dart
│   ├── onboarding/       # trust, permissions, goal pages
│   ├── screens/          # app_scaffold.dart, today_screen.dart, history_screen.dart, my_data_screen.dart
│   └── widgets/          # goal_ring.dart, step_bar_chart.dart
└── dev/                  # data_inject_service, lifecycle_simulator, chart_benchmark (kDebugMode)
```

### Decision Impact Analysis

**Implementation Sequence:**

1. `flutter create .` in `astra-app/` repo root + `pubspec.yaml` dependencies
2. `core/database/` — schema v1, UNIQUE bucket index, migrations, isolate-safe factory + WAL PRAGMAs
3. `data/datasources/` — `DataIngestionSource`, `PhonePedometerSource`, `StepNormalizer`, `AdpBleSource` stub
4. `BackgroundCollector` + WorkManager (Android: FGS + WM orchestration, not WM-only)
5. `DataLifecycleService` + dev inject (90-day benchmark)
6. Repositories with chart aggregation queries
7. Presentation Cubits + UX widgets
8. CSV export/import (`INSERT OR IGNORE`) + purge
9. Onboarding + local notifications
10. Release manifest hardening + beta checklist

**Cross-Component Dependencies:**

- WorkManager isolate → isolate-safe DB before background collection
- Chart perf → aggregation queries before History UI
- Goal notification → BackgroundCollector daily sum + local notifications
- CSV import → invalidate Cubits; round-trip export → purge → import test
- Purge → wipes all `timeseries_samples` and derived collection state; retains non-health setup preferences such as `daily_step_goal`, onboarding flag, and permission choices

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**12 conflict zones** identified where AI agents could diverge without these rules (extended by transaction, clock, and reactive-state guards).

### Naming Patterns

**Database (SQLite):**

- Tables: `snake_case` plural — `timeseries_samples`, `user_preferences`
- Columns: `snake_case` — match PRD §4.3.1 exactly (`start_time`, `zone_offset`, `device_id`)
- Indexes: `idx_{table}_{columns}` — e.g. `idx_timeseries_query`, `idx_bucket_identity` (UNIQUE)
- Migration versions: integer constant `DB_VERSION = N` in `migrations.dart`

**Dart code:**

- Files: `snake_case.dart` — `timeseries_sample_model.dart`, `today_cubit.dart`
- Classes: `PascalCase` — `TimeseriesSampleModel`, `TodayCubit`, `PhonePedometerSource`
- Interfaces: noun phrase — `DataIngestionSource` (not `IIngestionSource`)
- Cubits: `{Feature}Cubit` + `{Feature}State`
- Repositories: `{Domain}Repository` — `StepRepository`, `UserPreferencesRepository`
- Private fields: `_camelCase`; public API: `camelCase`
- Constants: `k` prefix — `kDefaultStepGoal = 8000`

### Structure Patterns

**Mandatory layout:**

- `BackgroundCollector` → `lib/core/services/background_collector.dart`
- `StepNormalizer` → `lib/data/datasources/step_normalizer.dart`
- `BackgroundHealthCapabilityEvaluator` → `lib/core/services/background_health_capability_evaluator.dart`
- `DataLifecycleService` → `lib/core/services/data_lifecycle_service.dart` (not a separate domain layer)
- `TimeProvider` → `lib/core/time/time_provider.dart` — inject everywhere timestamps are created
- `LocalDayCalculator` → `lib/core/time/local_day_calculator.dart` — UTC + zone_offset → local calendar day
- `AppDependencies` → `lib/core/di/app_dependencies.dart` — composition root
- WorkManager entrypoint → `lib/core/services/workmanager_callback.dart` with `@pragma('vm:entry-point')`
- Dev inject tools → `lib/dev/` — guarded by `kDebugMode`
- Tests mirror `lib/` under `test/`
- Docs at repo root `docs/` per FR-27

### Format Patterns

**Timestamps:**

- All ingestion timestamps via injected `TimeProvider` — not raw `DateTime.now()` in domain code
- Storage: ISO 8601 UTC with `Z` suffix — `'2026-05-22T14:30:00Z'`
- `zone_offset`: immutable string `'+02:00'` at ingestion
- CSV: OW-aligned headers; filename `astra-export-{yyyy-MM-dd}.csv`
- UUID v4 for `id` via `uuid` package

**Cubit states:**

- Immutable with `copyWith` or sealed classes
- Status: `{ initial, loading, loaded, error }` — consistent across features
- Error carries user-facing `String message` (English, calm tone)

### Communication Patterns

**DataIngestionSource contract:**

```dart
abstract class DataIngestionSource {
  String get providerId;
  Stream<StepReading> watchStepReadings();
}
```

`DataIngestionSource` does not emit `TimeseriesSampleModel` directly. Bucket creation, reset handling, and integer step-count validation belong to `StepNormalizer` so new sources cannot duplicate or bypass ingestion semantics.

**Write path enforcement (formalized):**

| Category | Callers | Repository method |
|----------|---------|-------------------|
| Ingestion writes | `BackgroundCollector` only | `StepRepository.upsertIngestionBucket()` |
| Administrative writes | `DataLifecycleService`, user actions via Cubits | `importCsv()`, `downsample()`, `purge()` |

- **All SQLite writes** go through `StepRepository` — no direct `db.insert()` elsewhere
- **Anti-pattern:** Cubits/widgets calling `db.insert()` or opening transactions
- **Anti-pattern:** `BackgroundCollector` opening database directly — must use repository

**Cubit refresh:** see Frontend Architecture refresh trigger table — no global event bus Phase 0. **No Riverpod, no app-wide reactive streams** — Cubit pull/refresh only.

**Transaction pattern:** Repository methods wrap multi-row operations:

```dart
await db.transaction((txn) async {
  for (final sample in samples) {
    await txn.insert(...);
  }
});
```

### Process Patterns

**Error handling:**

- Repository throws `DatabaseException`, `ImportValidationException`
- Cubit emits error state with user-facing message
- Import: abort transaction on validation failure (FR-30)

**Loading states:**

- Today: skeleton ring; History: 7-bar skeleton; My Data: button spinner only
- Chart 7d/30d toggle: instant rebind, no loading animation (KPI-01)

**VACUUM / maintenance:** Never run `VACUUM` on UI isolate/main thread. Android schedules maintenance from a background worker after compaction or purge; iOS starts async maintenance after foreground/resume when due, with BGAppRefresh as best-effort only.

**Export flow:** Write CSV to cache/temp file → share local path via `share_plus`. Never share in-memory string without persisting first.

**Permissions:** trust copy → activity recognition → optional notifications. FGS via manifest only.

### Enforcement Guidelines

**All AI agents MUST:**

1. Use isolate-safe DB factory with explicit `PRAGMA journal_mode=WAL` on every open
2. Route **all** SQLite writes through `StepRepository` methods — ingestion via `BackgroundCollector` only
3. Use administrative write methods for import/lifecycle/purge — never ad-hoc SQL from UI
4. Enforce dual idempotency: upsert on bucket identity (ingestion); `INSERT OR IGNORE` on UUID (import); export preserves `id`
5. Route all pedometer cumulative values through `StepNormalizer` — no delta logic in repository or UI
6. Compute `local_day` via `LocalDayCalculator` from each row's stored `zone_offset` — never device current timezone; never `date(start_time, zone_offset)` in SQL
7. Return `ChartDayAggregate` from repository — UI/widgets never aggregate steps
8. Pre-aggregate in repository — max ~31 points to `fl_chart`
9. Centralize background capability checks (incl. OEM battery optimization) in `BackgroundHealthCapabilityEvaluator`
10. Wrap all multi-row DB operations in repository-owned transactions (D-24)
11. Use injected `TimeProvider` for all ingestion/lifecycle timestamps — no raw `DateTime.now()` (D-25)
12. Bundle fonts locally; no runtime network font fetch Phase 0
13. Export CSV to cache file before `share_plus`
14. Keep release manifest free of INTERNET; include `test/release_manifest_test.dart`
15. No Riverpod / app-wide reactive stream architecture Phase 0
16. Wire dependencies via `AppDependencies` in `main.dart`
17. Gate dev tools with `kDebugMode`

**Verification:** beta checklist (FR-29), unit tests (counter reset, import idempotency, chart row count, local_day travel scenario), `docs/DEPENDENCIES.md` audit, `flutter analyze` clean, WorkManager isolate spike on physical Android, chart benchmark p95 < 100ms.

### Pattern Examples

**Good — chart aggregation (Dart-side local_day grouping):**

```dart
// StepRepository.getChartDailyAggregates — NOT raw SQL date(start_time, zone_offset)
final rows = await db.query('timeseries_samples', where: "type = 'steps'", ...);
final grouped = <DateTime, int>{};
for (final row in rows) {
  final localDay = LocalDayCalculator.localDay(
    utc: DateTime.parse(row['start_time'] as String),
    zoneOffset: row['zone_offset'] as String,
  );
  grouped[localDay] = (grouped[localDay] ?? 0) + (row['value'] as num).toInt();
}
return grouped.entries
    .map((e) => ChartDayAggregate(localDay: e.key, totalSteps: e.value))
    .toList()
  ..sort((a, b) => b.localDay.compareTo(a.localDay));
```

**Good — isolate DB open:**

```dart
Future<Database> openAstraDatabase() async {
  final path = join(await getDatabasesPath(), 'astra_app.db');
  final db = await openDatabase(path, version: dbVersion, onCreate: ..., onUpgrade: ...);
  await db.execute('PRAGMA journal_mode=WAL;');
  await db.execute('PRAGMA foreign_keys = ON;');
  return db;
}
```

**Good — bucket upsert on ingestion:**

```sql
INSERT INTO timeseries_samples (...) VALUES (...)
ON CONFLICT(provider, device_id, type, start_time, end_time, resolution)
DO UPDATE SET value = excluded.value;
```

**Anti-patterns:**

- ❌ `INSERT` without UUID — breaks import idempotency
- ❌ Static `Database? _db` shared across isolates
- ❌ 8640 chart points for 30-day view
- ❌ Adding `http`, `dio`, `firebase_*` to pubspec
- ❌ GoRouter for 3-tab Phase 0 app
- ❌ Delta/step-reset logic in repository or Cubit instead of `StepNormalizer`
- ❌ `date(start_time, zone_offset)` in SQL — invalid SQLite; use `LocalDayCalculator`
- ❌ Computing `local_day` from `DateTime.now().timeZoneOffset` for historical rows
- ❌ Chart aggregation in `StepBarChart` widget instead of repository
- ❌ Loop of 500+ `db.insert()` calls outside `db.transaction()`
- ❌ `DateTime.now()` in `BackgroundCollector`, `StepNormalizer`, or lifecycle code
- ❌ `VACUUM` triggered from UI thread or Cubit
- ❌ `share_plus` on in-memory CSV without writing to cache/temp file first
- ❌ Riverpod, `StreamBuilder` state graphs, or reactive repositories Phase 0

## Project Structure & Boundaries

### Complete Project Directory Structure

```
astra-app/                              # Git repo root = Flutter app root (D-18)
├── LICENSE                             # Apache 2.0 (FR-26)
├── README.md                           # Pitch deck + airplane mode protocol (FR-26)
├── pubspec.yaml                        # name: astra_app
├── analysis_options.yaml
├── .gitignore
├── assets/fonts/                       # Figtree + Darker Grotesque (bundled, no network)
├── android/app/src/
│   ├── debug/AndroidManifest.xml       # INTERNET allowed (D-17)
│   └── main/AndroidManifest.xml        # No INTERNET; FGS health (FR-6)
├── ios/Runner/
│   ├── Info.plist                      # NSMotionUsageDescription
│   └── PrivacyInfo.xcprivacy
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants/                  # astra_colors, astra_typography, app_constants
│   │   ├── database/                   # isolate_database_factory, migrations
│   │   ├── di/                         # app_dependencies
│   │   ├── time/                       # time_provider, local_day_calculator, fake_time_provider (tests)
│   │   └── services/                   # background_collector, data_lifecycle_service, background_health_capability_evaluator, workmanager_callback, notification_service
│   ├── data/
│   │   ├── datasources/                # ingestion_source, phone_pedometer_source, step_normalizer, adp_ble_source
│   │   ├── models/                     # timeseries_sample_model, chart_day_aggregate, import_result
│   │   └── repositories/               # step_repository, user_preferences_repository
│   ├── presentation/
│   │   ├── cubits/                     # today, history, my_data, onboarding
│   │   ├── onboarding/                 # trust, permissions, goal pages
│   │   ├── screens/                    # app_scaffold, today, history, my_data
│   │   └── widgets/                    # goal_ring, goal_celebration, step_bar_chart, etc.
│   └── dev/                            # data_inject_service, lifecycle_simulator, chart_benchmark (kDebugMode)
├── test/                               # mirrors lib/ — repository, lifecycle, manifest, widget tests
│   └── release_manifest_test.dart      # asserts no INTERNET in release manifest
├── docs/                               # FR-27 documentation bundle
│   ├── OPEN_WEARABLES_ALIGNMENT.md
│   ├── SERIES_TYPES.md
│   ├── DEPENDENCIES.md
│   ├── REGULATORY_POSITION.md
│   └── BETA_CHECKLIST.md               # FR-29 traceability
└── _bmad-output/                       # Planning artifacts (not shipped)
```

### Architectural Boundaries

**API Boundaries:** No remote API Phase 0. External: OS sensors, share sheet, local notifications only.

**Component Boundaries:**

| Layer | May call | Must NOT call |
|-------|----------|---------------|
| `presentation/` | Cubits → Repositories (read) | Direct sqflite, ingestion writes |
| `cubits/` | Repositories | Widgets, platform channels |
| `background_collector` | `StepNormalizer`, `DataIngestionSource`, `StepRepository.upsertIngestionBucket()` | Direct sqflite access, BuildContext, widgets |
| `step_normalizer` | Raw pedometer readings only | SQLite, UI |
| `data_lifecycle_service` | `StepRepository` (compact/downsample) | Ingestion sources |
| `background_health_capability_evaluator` | Platform permission APIs | Business logic scattered in screens |
| `dev/` | All (debug only) | Ship in release |

**Data Boundaries:** Single file `{getDatabasesPath()}/astra_app.db`. CSV only external interchange.

### Requirements to Structure Mapping

| FR range | Location |
|----------|----------|
| FR-1–3 | `lib/data/datasources/` |
| FR-4–6 | `lib/core/services/`, `android/.../AndroidManifest.xml` |
| FR-7–10 | `lib/core/database/`, `lib/data/repositories/step_repository.dart` |
| FR-11–12 | `lib/core/services/data_lifecycle_service.dart` |
| FR-13–21, FR-30–31 | `my_data_screen.dart`, `step_repository.dart`, `theme_cubit.dart` |
| FR-14–15 | `today_screen.dart`, `widgets/goal_ring.dart` |
| FR-16–17 | `history_screen.dart`, `widgets/step_bar_chart.dart` |
| FR-22–24 | `lib/presentation/onboarding/` |
| FR-25 | `notification_service.dart` |
| FR-26–29 | `LICENSE`, `README.md`, `docs/`, `lib/dev/` |

### Integration Points

**Data flow:** Pedometer → `StepNormalizer` → `BackgroundCollector` → `StepRepository` → SQLite → Cubits (read via `ChartDayAggregate`) / CSV export-import.

**Android background model:** FGS health (continuous when OS permits) + WorkManager (orchestration/reconciliation) + foreground backfill on app open. WorkManager alone is not a realtime guarantee.

**Build:** `flutter build apk --release` from repo root — manifest audit + `release_manifest_test.dart` before beta.

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:** Flutter 3.44 + sqflite 2.4 + workmanager 0.9 + Cubit stack is coherent. No network SDKs in health path. Release/debug manifest split (D-17) compatible with Flutter tooling. Isolate-safe DB factory resolves WorkManager/UI concurrency without shared singletons.

**Pattern Consistency:** Naming (snake_case SQL, PascalCase Dart), single-writer rule, chart aggregation, and CSV idempotency patterns reinforce D-01 through D-18. Anti-patterns explicitly block common agent mistakes.

**Structure Alignment:** Layered `lib/` at repo root; `BackgroundCollector` → `StepRepository` write path matches data flow. `docs/` and `_bmad-output/` coexist at repo root — planning artifacts not shipped.

### Requirements Coverage Validation ✅

**Functional Requirements Coverage:** All 31 FRs mapped to specific files (see Requirements to Structure Mapping). FR-28 dev inject in `lib/dev/`. FR-29 beta checklist in `docs/BETA_CHECKLIST.md`. FR-31 theme in `theme_cubit.dart` + My Data.

**Non-Functional Requirements Coverage:**

| NFR | Architectural support |
|-----|----------------------|
| NFR-1 | Pre-aggregated `ChartDayAggregate` + benchmark p95 < 100ms on 90-day dataset |
| NFR-2 | Minimal dependency set |
| NFR-3 | No INTERNET release + offline CSV |
| NFR-4 | Plaintext + Phase 1 SQLCipher path |
| NFR-5 | UX spec semantics; widget-level responsibility |
| NFR-6 | English UI; i18n-ready structure |
| NFR-7/8 | DataLifecycleService + storage targets |
| NFR-9 | UTC + zone_offset doctrine end-to-end |

### Implementation Readiness Validation ✅

**Decision Completeness:** 26 decisions (D-01–D-26) with versions, pubspec lock, init command, and Sprint 0 sequence.

**Structure Completeness:** Full tree with named files/directories; boundaries table defines allowed calls.

**Pattern Completeness:** 12 conflict zones, enforcement rules, good/anti-pattern examples.

### Gap Analysis Results

**Resolved by adversarial review (2026-05-22):**

- Project naming unified: **`astra-app`** (repo/product), **`astra_app`** (Dart package), **`astra_app.db`** (database)
- Write path clarified: all writes via `StepRepository`; `BackgroundCollector` sole ingestion caller
- Invalid SQL `date(start_time, zone_offset)` replaced with `LocalDayCalculator` Dart grouping
- CSV dual-key idempotency (UUID + bucket UNIQUE) documented
- DI via `AppDependencies`; Today foreground refresh; notifications/celebration; lifecycle schedule from addendum §3
- WorkManager isolate spike criteria; iOS stale threshold; OEM battery optimization flows
- Automated `release_manifest_test.dart` for INTERNET check

**Remaining (validate during implementation, not doc blockers):**

- WorkManager + sqflite isolate behavior on target OEM devices — Sprint 0 spike
- iOS BGAppRefresh reliability — Sprint 1 validation
- CI/CD pipeline deferred post-beta
- **Android Built-in Kotlin / KGP migration (Epic 6 Story 6.2):** Flutter 3.44 + AGP 9.x temporarily allow plugins that apply Kotlin Gradle Plugin (KGP) via `android.builtInKotlin=false` in `gradle.properties`. Story 1.1 build surfaced warnings for `pedometer`, `share_plus`, `workmanager_android`. Before beta release, verify plugin changelogs, upgrade where Built-in Kotlin is supported, remove legacy flags, and confirm `flutter build apk --release` is clean. Ref: [migrate-to-built-in-kotlin](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).

**Critical:** None — pending spike validations are normal pre-beta gates, not architecture gaps.

### Validation Issues Addressed

Gemini review items integrated: isolate-safe `getDatabasesPath()`, `INSERT OR IGNORE` import, manifest FGS verification, **`astra-app`** repo-root Flutter layout.

ChatGPT review items integrated (2026-05-22): explicit WAL + foreign_keys PRAGMAs, formalized ingestion vs administrative writes, bucket identity UNIQUE index, `StepNormalizer`, `ChartDayAggregate` view models, `local_day` from stored offset rule, WorkManager orchestration semantics, pragmatic 3-layer structure (no domain folder), `BackgroundHealthCapabilityEvaluator`, transaction boundaries (D-24), `TimeProvider` clock source (D-25), local font bundling, VACUUM off UI thread, cache-first CSV export, no reactive stream architecture Phase 0.

Adversarial review items integrated (2026-05-22): `LocalDayCalculator`, dual-key CSV idempotency, `AppDependencies` DI, Today Cubit refresh triggers, NFR-1 benchmark criteria, notification/celebration flow, lifecycle schedule table, WorkManager spike acceptance, iOS stale threshold, OEM battery flows, `release_manifest_test.dart`.

### Architecture Completeness Checklist

**Requirements Analysis**

- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**Architectural Decisions**

- [x] Critical decisions documented with versions
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance considerations addressed

**Implementation Patterns**

- [x] Naming conventions established
- [x] Structure patterns defined
- [x] Communication patterns specified
- [x] Process patterns documented

**Project Structure**

- [x] Complete directory structure defined
- [x] Component boundaries established
- [x] Integration points mapped
- [x] Requirements to structure mapping complete

### Architecture Readiness Assessment

**Overall Status:** READY FOR EPICS / IMPLEMENTATION

**Confidence Level:** High — with Sprint 0 WorkManager isolate spike as explicit validation gate

**Key Strengths:**

- Local-first privacy architecture with verifiable boundaries (no network, single-writer, CSV sovereignty)
- ADP-ready ingestion abstraction without Phase 0 over-engineering
- Agent-proof patterns preventing isolate, chart perf, and import idempotency bugs
- Clear FR → file mapping for solo builder + Cursor co-dev

**Areas for Future Enhancement:**

- Bundle fonts locally for strict offline-first first launch — **now required** (`assets/fonts/`)
- SQLCipher + BLE simulator (Phase 1)
- GitHub Actions CI post-beta
- Health Connect ingestion path (Phase 1)

### Implementation Handoff

**AI Agent Guidelines:**

- Follow this document for all architectural questions
- **All SQLite writes** go through `StepRepository` methods — `BackgroundCollector` is the only ingestion caller
- Never add packages without updating `docs/DEPENDENCIES.md`
- Gate all dev tools with `kDebugMode`
- Use **`astra-app`** repo root; Dart package **`astra_app`**

**First Implementation Priority:**

```bash
flutter channel stable && flutter upgrade
# From astra-app/ repo root:
flutter create . --org com.astraapp --project-name astra_app --platforms=android,ios --android-language=kotlin --empty
# Apply locked pubspec.yaml dependencies (name: astra_app)
# Scaffold lib/ structure per Project Structure section
# Sprint 0 spike: WorkManager callback writes test bucket on physical Android
```
