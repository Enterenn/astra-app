# Story 2.4: Background Collector and Android WorkManager

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want steps to accumulate while the app is closed on Android,
So that I get value without opening the app constantly.

## Acceptance Criteria

1. **Given** a physical Android device (reference platform)
   **When** WorkManager callback runs with `@pragma('vm:entry-point')` and `WidgetsFlutterBinding.ensureInitialized()`
   **Then** a test bucket is written and readable by UI after resume (WorkManager spike)

2. **Given** activity permission granted and app backgrounded
   **When** 24 hours pass without opening the app on Android beta
   **Then** step count increases vs prior snapshot (FR4, SM-2)

3. **Given** Android 14+ manifest
   **When** inspected
   **Then** `FOREGROUND_SERVICE_HEALTH` is declared correctly — not `dataSync` misuse (FR6)

4. **Given** WorkManager isolate and UI isolate
   **When** both access SQLite
   **Then** each opens its own connection via isolate-safe factory with WAL

5. **Given** iOS build
   **When** background collection runs
   **Then** backfill-on-foreground model is implemented — no false promise of Android-parity 5-min cadence (FR4)

## Tasks / Subtasks

- [x] **Sub-task A — Isolate-safe database factory** (AC: #4)
  - [x] Add `lib/core/database/isolate_database_factory.dart` — thin wrapper around `openAstraDatabase()` documented for WorkManager/UI isolate use; each call returns a **new** connection (no static singleton).
  - [x] Refactor `app_database.dart` only if needed to share PRAGMA/migration logic; preserve existing test `databasePath` injection.
  - [x] Add unit test proving two sequential `openAstraDatabase()` calls on same path both succeed with WAL (file-backed via FFI in test).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — StepRepository last-ingestion query** (AC: #2 downstream for 2.5)
  - [x] Add `Future<DateTime?> getLastIngestionUtc()` — `MAX(end_time)` for `type = 'steps'`, parsed via `TimestampCodec`; returns `null` when no rows.
  - [x] Add `test/data/repositories/step_repository_last_ingestion_test.dart`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — BackgroundCollector core** (AC: #1, #5)
  - [x] Add `lib/core/services/background_collector.dart`:
    - [x] Constructor: `List<DataIngestionSource>`, `StepNormalizer`, `StepRepository`, `TimeProvider`; optional `VoidCallback? onIngestionComplete` (UI isolate only — document).
    - [x] `Future<int> collectOnce({int maxReadingsPerSource = 50})` — for each source with non-empty stream sample: `normalizer.normalize(source, maxReadings: …)` → `repository.upsertIngestionBucket()` per bucket; return count of buckets upserted.
    - [x] Guard live platform streams with a short timeout or equivalent bounded-read strategy so a WorkManager task cannot hang forever when `Pedometer.stepCountStream` emits no event.
    - [x] **Only** this class calls `upsertIngestionBucket()` in production code paths.
    - [x] Skip sources that emit no readings (ADP stub); catch/log stream errors without crashing isolate.
    - [x] No `DateTime.now()` — use injected `TimeProvider` only if timestamps needed locally (prefer normalizer/repository paths).
    - [x] No direct `Database` access — repository only.
  - [x] Add `test/core/services/background_collector_test.dart` with fake source + in-memory DB; assert upsert count and `onIngestionComplete` fired when buckets written.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — WorkManager callback + registration** (AC: #1, #4)
  - [x] Add `lib/core/services/workmanager_callback.dart`:
    - [x] Top-level `@pragma('vm:entry-point') void callbackDispatcher()` using **workmanager 0.9+** API: `Workmanager().executeTask((task, inputData) async { … })`.
    - [x] Inside task: `WidgetsFlutterBinding.ensureInitialized()` then `DartPluginRegistrant.ensureInitialized()` (required for sqflite/pedometer in background isolate).
    - [x] Bootstrap isolate-local deps: `openAstraDatabase()` → `StepRepository` + `StepNormalizer` + sources + `BackgroundCollector` → `collectOnce()`.
    - [x] On failure: log via `debugPrint` (no analytics); return `false` so WM can retry; never swallow silently without log.
  - [x] Add task name constants e.g. `kStepCollectionTaskName = 'astra_step_collection'`.
  - [x] Register in `main.dart` (Android only): `Workmanager().initialize(callbackDispatcher)` then `registerPeriodicTask` with frequency ≥ 15 minutes (Android minimum); use `ExistingPeriodicWorkPolicy.keep` on re-register.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Android manifest + FGS compliance** (AC: #3)
  - [x] Update `android/app/src/main/AndroidManifest.xml`:
    - [x] `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_HEALTH` permissions.
    - [x] `RECEIVE_BOOT_COMPLETED` if required by workmanager plugin docs.
    - [x] **Do not** use `foregroundServiceType="dataSync"` for health/pedometer work.
    - [x] Declare FGS service type per Android 14+ if/when a health FGS is started; at minimum permissions + correct type for future FGS — verify against [workmanager](https://pub.dev/packages/workmanager) and [pedometer](https://pub.dev/packages/pedometer) README for required receivers/services.
  - [x] Confirm `ACTIVITY_RECOGNITION` already present (Story 1.x deferred wiring).
  - [x] Document manifest changes in review brief; update `docs/DEPENDENCIES.md` network/manifest notes if new permissions listed.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task F — Foreground backfill + lifecycle wiring** (AC: #2, #5)
  - [x] Wire `BackgroundCollector` in `AppDependencies.create()` / `.test()`; expose getter.
  - [x] In `main.dart` or `AstraApp`: after deps ready, call `backgroundCollector.collectOnce()` once (foreground backfill on cold start).
  - [x] On `AppLifecycleState.resumed`: call `collectOnce()` again (mandatory fallback if WM isolate failed — architecture D-04).
  - [x] **iOS:** skip WorkManager init; rely on cold start + resume backfill only; add code comment referencing FR4 iOS model.
  - [x] **Android:** init WorkManager + foreground backfill (both paths active).
  - [x] Extend `test/core/di/app_dependencies_test.dart` for `backgroundCollector` presence.
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task G — Physical device verification + docs** (AC: #1, #2)
  - [x] Manual **WorkManager spike** on physical Android: grant activity permission → background app → trigger WM (wait or adb) → reopen app → verify new row in DB / `getTodaySteps()` increased / `getLastIngestionUtc()` updated. *(Emulator proxy run 2026-06-02: WM registered + jobscheduler force accepted; bucket write blocked by missing step sensor — physical phone still required for final AC #1 sign-off.)*
  - [x] Record spike steps and result in Dev Agent Record (pass/fail, device model, Android version).
  - [x] Run `flutter analyze` and full `flutter test`.
  - [x] Review brief explains spike in plain language for Baptiste.
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 2.4:**
- `BackgroundCollector` — sole production caller of `upsertIngestionBucket()`.
- `isolate_database_factory.dart` (or equivalent documented isolate entry) + WAL per connection.
- `workmanager_callback.dart` with 0.9+ `executeTask` API.
- WorkManager periodic registration (Android).
- Foreground backfill on app start + resume (Android **and** iOS).
- Android manifest FGS health permissions (FR6).
- `StepRepository.getLastIngestionUtc()` for Story 2.5 stale banner (readiness report dependency).
- `onIngestionComplete` callback hook (no Cubit wiring yet).

**Out of scope — defer to later stories:**
- `TodayCubit`, `GoalRing`, stale `StatusBanner` UI → **Story 2.5**.
- Goal celebration animation → **Story 2.6**.
- Goal local notification → **Story 2.7** (`NotificationService`).
- Full `BackgroundHealthCapabilityEvaluator` + OEM battery deep-links + `BackgroundStatusCard` → **Story 4.2** (minimal permission gate in collector OK if needed).
- Continuous Android FGS **runtime** notification UX → coordinate with 2.7 notifications; manifest declarations required now, full FGS service implementation only if needed for SM-2 on target devices.
- `DataLifecycleService`, dev inject → **Epic 3 / 4**.
- Data purge/import → **Epic 4**.

Do not over-implement. This story connects the **live ingestion pipeline** to SQLite in background and foreground — not dashboard UI.

### Pipeline position (Epic 2)

```text
PhonePedometerSource ──┐
                       ├──> StepNormalizer ──> NormalizedStepBucket[]
AdpBleSource (empty) ──┘                              │
                                                       v
                              BackgroundCollector.collectOnce()  ← THIS STORY
                                       │
                                       v
                              StepRepository.upsertIngestionBucket()
                                       │
                                       v
                              timeseries_samples (SQLite)
                                       │
                    getTodaySteps() / getLastIngestionUtc()  (reads)
                                       │
                              (2.5 TodayCubit / GoalRing)
```

Story 2.3 delivered repository + time semantics. Story 2.4 wires the collector. Story 2.5 reads totals for UI.

### Architecture contracts (must match exactly)

**Write path (D-03, D-19):**

| Caller | Method | Notes |
|--------|--------|-------|
| `BackgroundCollector` only (production) | `StepRepository.upsertIngestionBucket()` | UI/Cubits **never** call this |
| WorkManager callback | delegates to `BackgroundCollector.collectOnce()` | Opens own DB handle |
| Tests | direct upsert or collector | OK |

**BackgroundCollector responsibilities ([Source: `architecture.md` — Structure Patterns]):**

| Must do | Must not do |
|---------|-------------|
| Orchestrate sources → normalizer → repository | Open `Database` directly |
| Call `upsertIngestionBucket()` only | Put delta/reset logic here (D-20 → normalizer) |
| Invoke `onIngestionComplete` after successful writes (UI isolate) | Use `BuildContext`, widgets, Cubits |
| Log failures in WM isolate | Silent data loss |

**Isolate-safe persistence (D-06):**

- UI isolate: existing `AppDependencies.create()` DB handle.
- WM isolate: **new** `openAstraDatabase()` inside callback — same file path, separate connection.
- Both run WAL + foreign_keys PRAGMAs (already in `openAstraDatabase()`).
- No shared static `Database` singleton across isolates.

**WorkManager 0.9+ API (breaking change from 0.8):**

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    // bootstrap deps → BackgroundCollector.collectOnce()
    return true;
  });
}
```

- Do **not** use deprecated `Workmanager.defaultCallbackDispatcher`.
- Periodic task minimum frequency on Android: **15 minutes** (platform constraint).
- WorkManager is **orchestration**, not guaranteed realtime 5-min cadence (D-04).

**Android manifest (FR-6):**

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH" />
```

- Health step reads must **not** misuse `dataSync` FGS type.
- FGS permissions are manifest-level — not via `permission_handler`.

**iOS model (FR-4, A-13):**

- No WorkManager registration on iOS.
- `collectOnce()` on cold start + every `AppLifecycleState.resumed`.
- No code/docs implying 5-minute background cadence on iOS.

**getLastIngestionUtc (Story 2.5 dependency):**

```dart
/// Latest end_time among step samples, UTC. Null if no samples.
Future<DateTime?> getLastIngestionUtc();
```

Used by 2.5 compact stale banner (12h Android / 4h iOS thresholds) — implement query now, UI later.

### Current code state

| Path | Current state | What 2.4 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/core/database/app_database.dart` | `openAstraDatabase()` with WAL PRAGMAs | May extract shared logic; keep test `databasePath` param | Migration behavior unchanged |
| `lib/data/repositories/step_repository.dart` | `upsertIngestionBucket`, `getTodaySteps` | Add `getLastIngestionUtc()` | Upsert SQL preserves id on conflict |
| `lib/data/datasources/step_normalizer.dart` | Delta/reset logic complete | Consumed by collector; **no edits** unless bug | TimeProvider injection |
| `lib/data/datasources/phone_pedometer_source.dart` | Stream wrapper | Used by collector subscriptions | Test injectable stream factory |
| `lib/core/di/app_dependencies.dart` | DB, sources, normalizer, repository | Add `BackgroundCollector` | Existing factories |
| `lib/main.dart` | `ensureInitialized` + `AppDependencies.create()` | WM init (Android), lifecycle backfill | Onboarding gate unchanged |
| `android/app/src/main/AndroidManifest.xml` | ACTIVITY_RECOGNITION, POST_NOTIFICATIONS | FGS health + WM permissions | No INTERNET in release |
| `lib/core/services/` | **Does not exist** | Create collector + WM callback | — |

### Recommended file layout

```text
lib/core/database/isolate_database_factory.dart   # NEW (may alias openAstraDatabase)
lib/core/services/background_collector.dart       # NEW
lib/core/services/workmanager_callback.dart       # NEW
lib/core/services/workmanager_tasks.dart          # NEW (task name constants)
lib/data/repositories/step_repository.dart        # UPDATE — getLastIngestionUtc
lib/core/di/app_dependencies.dart                 # UPDATE
lib/main.dart                                     # UPDATE — WM + lifecycle
android/app/src/main/AndroidManifest.xml          # UPDATE

test/core/services/background_collector_test.dart           # NEW
test/data/repositories/step_repository_last_ingestion_test.dart  # NEW
test/core/di/app_dependencies_test.dart                     # UPDATE
```

### BackgroundCollector sketch (suggested API)

```dart
class BackgroundCollector {
  BackgroundCollector({
    required List<DataIngestionSource> sources,
    required StepNormalizer normalizer,
    required StepRepository repository,
    required TimeProvider clock,
    void Function()? onIngestionComplete,
  });

  /// One ingestion pass. Returns number of buckets upserted.
  Future<int> collectOnce({int maxReadingsPerSource = 50});

  void Function()? onIngestionComplete;
}
```

Keep `maxReadingsPerSource` modest for WM task time limits; foreground backfill may use same default initially.

Implementation guard: live pedometer streams are not guaranteed to emit during a short background task. `collectOnce()` must complete even with zero readings, either by applying a short timeout around `normalizer.normalize(...)` or by using an equivalent bounded collection helper before normalization. This prevents WorkManager from being killed for a hung task and preserves foreground backfill as the recovery path.

### WorkManager registration sketch (Android main)

```dart
if (Platform.isAndroid) {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    kStepCollectionUniqueName,
    kStepCollectionTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
```

Use `dart:io` `Platform.isAndroid` or `defaultTargetPlatform` — guard iOS builds.

### Foreground backfill pattern

```dart
// After deps created:
await deps.backgroundCollector.collectOnce();

// In WidgetsBindingObserver:
if (state == AppLifecycleState.resumed) {
  unawaited(deps.backgroundCollector.collectOnce());
}
```

Architecture: foreground backfill is **mandatory** even when WM works — handles isolate init failures and OEM deferral.

### Physical device spike checklist (AC #1)

1. Install debug/release APK on physical Android with activity permission granted.
2. Note `getTodaySteps()` or sample count baseline.
3. Force-close app; wait for WM periodic task OR use plugin debug trigger if available.
4. Reopen app → `getLastIngestionUtc()` should be newer than baseline OR step total increased after walking.
5. Document device model + Android version in Dev Agent Record.

SM-2 (24h without opening app) is a **beta acceptance** test — note in review brief; cannot be automated in CI.

### Architecture compliance

| Decision / invariant | Requirement for 2.4 |
|----------------------|---------------------|
| D-03 | Only `BackgroundCollector` calls `upsertIngestionBucket()` in production |
| D-04 | WM orchestrates; foreground backfill always active; no realtime guarantee |
| D-06 | Separate DB connection per isolate; WAL explicit |
| D-20 | No delta logic in collector — normalizer only |
| D-25 | No `DateTime.now()` in collector/callback |
| FR4 | Android background persistence + iOS foreground backfill |
| FR6 | FGS health manifest — not dataSync |
| NFR3 | No network in pipeline |

### Anti-patterns

- Do not call `upsertIngestionBucket()` from Cubits, widgets, onboarding, or WM callback directly (always via collector).
- Do not share a static `Database` instance across UI and WM isolates.
- Do not use workmanager 0.8 `defaultCallbackDispatcher` API.
- Do not skip `DartPluginRegistrant.ensureInitialized()` in WM isolate.
- Do not register WorkManager on iOS expecting Android parity.
- Do not implement `TodayCubit`, `GoalRing`, or notifications in this story.
- Do not add delta/reset logic to collector — stays in `StepNormalizer`.
- Do not use `DateTime.now()` in collector or callback bootstrap.
- Do not add Riverpod, global ingestion streams, or reactive repositories.
- Do not promise continuous 5-min background on iOS in code comments or user strings.
- Do not add `INTERNET` permission to release manifest.

### Previous Story Intelligence (Story 2.3 — done)

- Review-before-commit is **mandatory** per `docs/project-context.md`.
- `StepRepository.upsertIngestionBucket()` implemented with UUID-on-insert and bucket-identity upsert updating `value` only.
- `getTodaySteps()` uses `LocalDayCalculator` per-row stored `zone_offset` — collector does not compute today totals.
- `AppDependencies` exposes `stepRepository` with shared UI-isolate DB handle.
- `FakeTimeProvider` at `test/core/time/fake_time_provider.dart` — reuse in collector tests if needed.
- Story 2.3 explicitly deferred `BackgroundCollector`, WorkManager, FGS — **implement now**.
- Travel semantics tests prove repository time logic — collector tests focus on **pipeline wiring**, not local-day math.
- Full test suite green after 2.3 — keep `flutter test` green.

### Git Intelligence Summary

| Commit | Relevance |
|--------|-----------|
| `54523c7` | Latest time semantics hardening — collector must not bypass repository |
| `50d74d8` | DI pattern for `StepRepository` — extend similarly for `BackgroundCollector` |
| `06d544b` | Repository upsert SQL — collector calls as-is |
| `fa86764` | TimeseriesSampleModel — collector uses normalizer output → repository |
| Story 2.2 commits | Normalizer + sources — collector orchestrates without changing delta logic |

### Latest Tech Information

- **workmanager ^0.9.0+3** (pub.dev): federated plugin; **breaking** — use `Workmanager().executeTask` inside `callbackDispatcher`, not `defaultCallbackDispatcher`. Call `DartPluginRegistrant.ensureInitialized()` in background isolate before sqflite/pedometer. Periodic tasks fixed for correct frequency in 0.9.0.
- **pedometer ^4.2.0**: cumulative since boot; WM task must complete quickly — use bounded `maxReadingsPerSource`. Stream may not deliver events in killed-app state on all OEMs — foreground backfill compensates.
- **sqflite ^2.4.2+1**: separate connections per isolate OK with WAL; Android PRAGMA via `rawQuery` (already in `app_database.dart`).
- **Android 14+ FGS**: declare `FOREGROUND_SERVICE_HEALTH`; runtime FGS start requires matching `foregroundServiceType="health"` on service declaration when continuous collection service is added.
- No new pub dependencies expected — workmanager already in `pubspec.yaml`.

### Project Structure Notes

- Matches architecture `lib/core/services/background_collector.dart` and `workmanager_callback.dart`.
- Tests mirror `lib/` under `test/`.
- Story file: `_bmad-output/implementation-artifacts/stories/2-4-background-collector-and-android-workmanager.md`.
- Update `docs/DEPENDENCIES.md` if manifest permission section added.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 2.4, FR4, FR6]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — §FR-4 Background step persistence, §FR-6 FGS]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-03, D-04, D-06, D-20, D-25, WorkManager spike, isolate factory, write path]
- [Source: `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-25.md` — last-sync query in 2.4 for 2.5]
- [Source: `_bmad-output/implementation-artifacts/stories/2-3-step-repository-and-time-semantics.md` — upsert contract, deferrals]
- [Source: `_bmad-output/implementation-artifacts/stories/2-2-data-ingestion-abstraction-and-step-normalizer.md` — normalizer/sources]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` — manifest wiring deferred from 1.1]
- [Source: `docs/project-context.md` — review-before-commit workflow]
- [Source: `lib/core/database/app_database.dart` — WAL open pattern]
- [Source: `lib/data/repositories/step_repository.dart` — upsert API]
- [Source: https://pub.dev/packages/workmanager — 0.9 callback + isolate init]

## Dev Agent Record

### Agent Model Used

GPT-5.5

### Debug Log References
- 2026-06-02: RED `flutter test test/core/database/isolate_database_factory_test.dart` failed because `isolate_database_factory.dart` and `openIsolateAstraDatabase()` did not exist.
- 2026-06-02: GREEN `flutter test test/core/database/isolate_database_factory_test.dart` passed after adding the isolate database factory.
- 2026-06-02: REGRESSION `flutter test` passed, 91 tests.
- 2026-06-02: QUALITY `flutter analyze` passed with no issues.
- 2026-06-02: RED `flutter test test/data/repositories/step_repository_last_ingestion_test.dart` failed because `StepRepository.getLastIngestionUtc()` did not exist.
- 2026-06-02: GREEN `flutter test test/data/repositories/step_repository_last_ingestion_test.dart` passed after adding the last-ingestion query.
- 2026-06-02: REGRESSION `flutter test` passed, 93 tests.
- 2026-06-02: QUALITY `flutter analyze` passed with no issues.
- 2026-06-02: RED `flutter test test/core/services/background_collector_test.dart` failed because `BackgroundCollector` did not exist.
- 2026-06-02: GREEN `flutter test test/core/services/background_collector_test.dart` passed after adding the collector.
- 2026-06-02: REGRESSION `flutter test` passed, 97 tests.
- 2026-06-02: QUALITY `flutter analyze` passed with no issues.
- 2026-06-02: RED `flutter test test/core/services/workmanager_callback_test.dart` failed because WorkManager callback/registration files did not exist.
- 2026-06-02: GREEN `flutter test test/core/services/workmanager_callback_test.dart` passed after adding callback, task constants, and registration helper.
- 2026-06-02: REGRESSION `flutter test` passed, 101 tests.
- 2026-06-02: QUALITY `flutter analyze` passed with no issues.
- 2026-06-02: RED `flutter test test/android/android_manifest_test.dart` failed because `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_HEALTH` were missing.
- 2026-06-02: GREEN `flutter test test/android/android_manifest_test.dart` passed after adding Android health FGS permissions and manifest guard tests.
- 2026-06-02: REGRESSION `flutter test` passed, 103 tests.
- 2026-06-02: QUALITY `flutter analyze` passed with no issues.
- 2026-06-02: BLOCKER `flutter test` crashed with `PathAccessException` on `build/native_assets/windows/sqlite3.dll` (Accès refusé). Root cause: a concurrent `flutter run` debug session (+ lingering `flutter_tester`) held the host native-asset DLL while `flutter test` tried to replace it. Not a code issue. Resolved by stopping the `flutter run` session before running tests.
- 2026-06-02: BLOCKER `flutter test test/widget_test.dart` hung indefinitely (idle `flutter_tester`). Root cause: the foreground-backfill tests ran `BackgroundCollector.collectOnce()` (fire-and-forget in `initState`) and `StepRepository.getLastIngestionUtc()` outside `tester.runAsync()`, so real SQLite I/O never completed in the fake-async zone. Fixed by wrapping `pumpWidget` + collection + DB reads in `tester.runAsync()` with deterministic polling.
- 2026-06-02: GREEN `flutter test test/widget_test.dart` passed, 7 tests.
- 2026-06-02: GREEN `flutter test test/core/di/app_dependencies_test.dart` passed.
- 2026-06-02: REGRESSION `flutter test` passed, 105 tests.
- 2026-06-02: QUALITY `flutter analyze` passed with no issues.
- 2026-06-02: SPIKE emulator `sdk_gphone16k_x86_64` Android 17 (API 37): debug APK installed; WM periodic job registered (`androidx.work.systemjobscheduler` id 2); `cmd jobscheduler run -f -u 0 -n androidx.work.systemjobscheduler com.astraapp 2` accepted but WM rescheduled (`executed before schedule`); pedometer unavailable (`StepCount not available`); 0 step rows in DB. Physical-device bucket write still pending.
- 2026-06-02: REGRESSION `flutter test` passed, 105 tests (Sub-task G gate).
- 2026-06-02: QUALITY `flutter analyze` passed with no issues (Sub-task G gate).

### Completion Notes List
- Sub-task A implementation ready for review: added an isolate-safe database factory wrapper that returns a fresh `Database` connection on every call while reusing `openAstraDatabase()` for WAL, foreign keys, migrations, and `databasePath` test injection.
- No `app_database.dart` refactor was needed because the existing `openAstraDatabase()` already centralizes PRAGMA and migration behavior.
- Added a file-backed FFI test proving two sequential factory opens on the same database path both succeed with WAL enabled.
- Sub-task B implementation ready for review: added `StepRepository.getLastIngestionUtc()` using `MAX(end_time)` filtered to step samples and parsed through `TimestampCodec.parseUtc()`.
- Added repository tests for the empty-table `null` case and for ignoring newer non-step samples when calculating last step ingestion.
- Sub-task C implementation ready for review: added `BackgroundCollector.collectOnce()` to orchestrate bounded source reads, normalization, repository upserts, and the UI-isolate completion callback.
- Added collector tests for successful upsert/callback, empty sources, source errors, and live streams that emit no events.
- Verified `upsertIngestionBucket()` is only called by `BackgroundCollector` in `lib/` production code.
- Sub-task D implementation ready for review: added WorkManager 0.9 callback dispatcher, isolate-local task bootstrap, task constants, and Android-only periodic registration from `main.dart`.
- Added WorkManager tests proving a background task writes via an isolate-local DB connection readable by a separate UI connection, returns `false` on bootstrap failure, skips non-Android registration, and uses `ExistingPeriodicWorkPolicy.keep`.
- Sub-task E implementation ready for review: added Android `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_HEALTH` permissions while preserving `ACTIVITY_RECOGNITION` and avoiding `foregroundServiceType="dataSync"`.
- Verified local `workmanager` and `pedometer` README/manifests: `pedometer` requires `ACTIVITY_RECOGNITION`; WorkManager docs/package manifest did not require app-level `RECEIVE_BOOT_COMPLETED`, so it was not added.
- Updated `docs/DEPENDENCIES.md` with health pipeline manifest notes and the no-network/no-`dataSync` constraint.
- Sub-task F implementation ready for review: exposed `BackgroundCollector` through `AppDependencies.create()`/`.test()`, and `AstraApp` now triggers `collectOnce()` on cold start (`initState`) and on every `AppLifecycleState.resumed` via `WidgetsBindingObserver` (D-04 mandatory foreground fallback, FR4 iOS model documented in code).
- The test factory defaults `ingestionSources` to the no-op `AdpBleSource` so widget tests never start live platform streams; `app_dependencies_test.dart` passes a live source explicitly when needed.
- Fixed a test-only hang: foreground-backfill widget tests now run all real-async work (widget build, fire-and-forget collection, SQLite reads) inside `tester.runAsync()` with bounded polling instead of asserting DB state from the fake-async zone.
- The `PathAccessException` blocker was environmental (concurrent `flutter run` locking the Windows native-asset `sqlite3.dll`), not a defect in the app or pipeline.
- Sub-task G implementation ready for review: ran automated quality gates (`flutter analyze`, 105 tests), documented WorkManager spike procedure in `docs/DEPENDENCIES.md`, and executed an emulator proxy spike. WM registration and jobscheduler force succeeded; bucket write could not be validated on emulator because the pedometer reports `StepCount not available`. AC #1 end-to-end bucket write still needs confirmation on a physical Android device with a step counter; AC #2 (24 h closed-app beta test) remains out of CI scope.

### File List
- `lib/core/database/isolate_database_factory.dart`
- `test/core/database/isolate_database_factory_test.dart`
- `lib/data/repositories/step_repository.dart`
- `test/data/repositories/step_repository_last_ingestion_test.dart`
- `lib/core/services/background_collector.dart`
- `test/core/services/background_collector_test.dart`
- `lib/core/services/workmanager_callback.dart`
- `lib/core/services/workmanager_tasks.dart`
- `lib/main.dart`
- `test/core/services/workmanager_callback_test.dart`
- `android/app/src/main/AndroidManifest.xml`
- `docs/DEPENDENCIES.md`
- `test/android/android_manifest_test.dart`
- `lib/core/di/app_dependencies.dart`
- `lib/app.dart`
- `test/widget_test.dart`
- `docs/DEPENDENCIES.md`

### Change Log
- 2026-06-02: Implemented Sub-task A isolate-safe database factory and WAL connection test.
- 2026-06-02: Implemented Sub-task B last step ingestion query and repository tests.
- 2026-06-02: Implemented Sub-task C BackgroundCollector core and service tests.
- 2026-06-02: Implemented Sub-task D WorkManager callback, Android registration, and tests.
- 2026-06-02: Implemented Sub-task E Android health FGS manifest permissions and documentation.
- 2026-06-02: Implemented Sub-task F foreground backfill + lifecycle wiring (DI exposure, cold-start/resume `collectOnce()`), and fixed the widget-test runAsync hang. Full suite green at 105 tests.
- 2026-06-02: Sub-task G — automated gates green (105 tests, analyze clean); WorkManager spike procedure documented; emulator proxy spike recorded (WM registered, pedometer unavailable on emulator).

## Story Completion Status

- Status: **review**
- All implementation sub-tasks A–G complete. AC #1 physical-device bucket write pending final sign-off on a real phone (emulator lacks step sensor). AC #2 deferred to beta acceptance (SM-2).
