# ASTRA

**Local-first. No account. No cloud. Proof over promises.**

ASTRA is a **local-first** wellness ecosystem: a Flutter mobile Hub App that collects and visualizes movement data from your phone's sensors, with a proprietary wearable planned in later phases. Your data stays on your device, under your control.

> *"The step counter that works in airplane mode."*

---

## Project status

| | |
|---|---|
| **Current phase** | Phase 0: OSS beta (exit gate passed 2026-06-08) |
| **Version** | `0.15.2+40` (see `pubspec.yaml`; displayed on About screen) |
| **Code status** | **Implemented**: Epics 1–13 + post-audit passes (21–33) complete |
| **Beta gate** | [docs/BETA_CHECKLIST.md](docs/BETA_CHECKLIST.md) — Phase 0 field pass logged; post-close items tracked in checklist |
| **Reference platform** | Android (iOS secondary, with reduced background expectations) |
| **License** | [Apache License 2.0](LICENSE) |

---

## Vision

ASTRA is built on a simple premise: **your health data belongs to you**. No mandatory account, no cloud dependency in Phase 0 / V1, no moralizing coaching or engagement loops.

Phase 0 is not a throwaway prototype. It is a **learning sandbox** that delivers a credible open-source app. Proof that the Hub architecture holds before encryption, BLE, and the wearable arrive.

**Product category:** **behavioral visibility tool** (General Wellness Product). ASTRA helps you see your own movement patterns. It does not diagnose, prescribe, or score "readiness."

---

## Product principles

1. **Proof over promises**: airplane mode, export, purge, storage footprint: verifiable behavior, not marketing claims.
2. **Local-first by default**: the device is the source of truth.
3. **No mandatory account**: no email, no auth layer in V1.
4. **Calm UX**: no streak shame, no DAU optimization.
5. **Data minimization**: interpretable aggregates, not raw sensor exhaust.
6. **Transparency**: footprint, export, purge, and background status are visible.
7. **Background autonomy**: value accrues when the app is closed (Android).
8. **User sovereignty**: CSV export and re-import keep you in control.
9. **My Data is first-class**: the My Data surface is the primary differentiator.

---

## Phase 0: What the app does (and does not)

### Included

- Step counter via phone sensors (`PhonePedometerSource`)
- Background collection (Android = reference; iOS = foreground backfill)
- Local SQLite storage (`timeseries_samples`, 5-minute buckets) — **not encrypted at rest** in Phase 0 (SQLCipher planned Phase 1; disclosed on My Data → Footprint)
- Three tabs: **Steps** · **Trends** · **Menu** — Profile, My Data, Settings, and About open from Menu
- Trust-first onboarding (activity permission, optional weight / height; daily goal defaults to 8000)
- UI localization (**EN** / **FR**) and display-unit preferences (metric / imperial)
- Daily goal history (historical goal line on Trends charts); edit goal from Steps (goal ring)
- CSV export / import ([Open Wearables](https://github.com/theopenwearables/open-wearables)-aligned columns, vocabulary only, no OW server dependency)
- Full health-data purge
- DB lifecycle (downsampling, maintenance) to bound growth (< 50 MB / year)
- Derived Today metrics (distance, walking time, kcal), UI-computed, not separate series types
- `DataIngestionSource` abstraction + `AdpBleSource` stub for Phase 1

### Excluded (later phases)

- SQLCipher encryption (Phase 1)
- Functional BLE / Wearable / ADP protocol (Phase 1–2)
- Health Connect / HealthKit (Phase 1)
- Cloud sync, user accounts, third-party analytics
- Leaderboards, coaching, opaque scores

---

## Interface

| Tab / entry | Screen | Purpose |
|-------------|--------|---------|
| **Steps** | Steps (Today) | Week view, day picker, goal ring (tap to edit), derived stats, collection health, subtle celebration |
| **Trends** | Trends | 7d / 30d / 12-month charts, period averages, peak-day card, historical goal line |
| **Menu** | Menu hub | Routes to Profile, My Data, Settings, About |
| **Menu → Profile** | Profile | Display name, weight, height |
| **Menu → My Data** | My Data | DB footprint, last optimization, background status, export / import / purge |
| **Menu → Settings** | Settings | Language, display units, notifications, theme, accent preset |
| **Menu → About** | About | App identity and version |
| **Onboarding** | (first launch) | Intro, activity permission (with denial / settings CTA), optional weight and height |

**Visual tone:** quiet instrument panel. **System theme default** (follows OS); Light, Dark, and accent presets in Settings. Clear hierarchy, no aggressive gamification.

---

## Architecture (overview)

Phase 0 data pipeline:

```
OS sensor (pedometer)
    → DataIngestionSource (PhonePedometerSource)
    → StepNormalizer (deltas, reboot, counter reset)
    → BackgroundCollector (sole ingestion writer)
    → StepRepository → SQLite (timeseries_samples)
    → UI (Steps / Trends / My Data)
    → DataLifecycleService (downsampling, VACUUM)
```

**Key rules:**

- Single ingestion write path to SQLite
- Timestamps in **UTC** + immutable `zone_offset` per sample (stable local-day aggregation)
- Chart aggregates in the repository (`ChartDayAggregate`), not in widgets
- **Release builds without INTERNET permission** (privacy by architecture)
- SQLite transactions for all multi-row operations

`lib/` structure:

```
lib/
├── core/          # DB, DI, time, background services
├── data/          # datasources, models, repositories
└── presentation/  # cubits, onboarding, screens, widgets
```

Full decisions: [`_bmad-output/planning-artifacts/architecture.md`](_bmad-output/planning-artifacts/architecture.md)

---

## Tech stack (Phase 0)

| Layer | Choice |
|-------|--------|
| Framework | Flutter 3.44+ (Dart 3.x), Android + iOS |
| Persistence | `sqflite`, on-device SQLite, WAL, versioned migrations |
| Background | `workmanager` + FGS health (Android) |
| Sensors | `pedometer` |
| Charts | Native `CustomPainter` (bar charts) |
| Notifications | `flutter_local_notifications` (local only) |
| Export | `file_picker` (OS save dialog) |
| State | Cubit (`flutter_bloc`) |
| i18n | `flutter_localizations` + ARB (`en`, `fr`) |
| Bundle ID | `com.astraapp` |

**Naming:** repo `astra-app` · Dart package `astra_app` · DB file `astra_app.db`

---

## Data model (summary)

Primary table `timeseries_samples`: one sample = one aggregated **Time Bucket** (e.g. steps over 5 minutes):

| Field | Example |
|-------|---------|
| `type` / `unit` | `steps` / `count` |
| `resolution` | `5min` · `1hour` · `1d` |
| `provider` / `device_id` | `internal_phone` / `smartphone` |
| `start_time` / `end_time` | ISO 8601 UTC |
| `zone_offset` | `+02:00` (captured at ingestion) |

Full schema: [`docs/SERIES_TYPES.md`](docs/SERIES_TYPES.md) · OW CSV mapping: [`docs/OPEN_WEARABLES_ALIGNMENT.md`](docs/OPEN_WEARABLES_ALIGNMENT.md)

---

## Airplane mode protocol (privacy proof)

Reference test to validate the local-first promise on a **release** build:

1. Install the release APK (no network permission)
2. Complete onboarding (no account)
3. Enable **airplane mode**
4. Walk ~500 steps without keeping the app open
5. Reopen **Steps** → step count should have accumulated in the background (Android)
6. Open **Trends** → bar chart renders from local DB (no network)
7. Open **Menu** → **My Data** → export CSV, verify footprint, test purge

Automated manifest gate: `flutter test test/release_manifest_test.dart`

This is the OSS hero demo. Not a marketing claim, a verifiable behavior.

---

## Developer setup

**Prerequisites:** Flutter stable 3.44+, Android SDK, Xcode (for iOS)

```bash
flutter channel stable
flutter upgrade

# From repo root (astra-app/)
flutter pub get
flutter run          # debug on connected device/emulator
flutter test --tags critical   # default verify; full suite: flutter test
flutter build apk --release
```

KGP plugin patches apply automatically on Android builds (see [`docs/DEPENDENCIES.md`](docs/DEPENDENCIES.md)). Implement features per documented architecture and active sprint stories.

---

## Project documentation

**Start here:** [`docs/README.md`](docs/README.md), index of contributor docs and FR-27 bundle.

| Document | Contents |
|----------|----------|
| [Agent workflow rules](docs/project-context.md) | Review-before-commit gate, commit conventions *(mandatory for contributors)* |
| [Open Wearables alignment](docs/OPEN_WEARABLES_ALIGNMENT.md) | CSV column mapping, bucket identity |
| [Series types](docs/SERIES_TYPES.md) | Phase 0 `steps` / `count` definitions |
| [Dependencies audit](docs/DEPENDENCIES.md) | Full package inventory, network policy |
| [Regulatory position](docs/REGULATORY_POSITION.md) | General Wellness scope statement |
| [Epics (Phase 0)](_bmad-output/planning-artifacts/epics.md) | Epics 1–13 acceptance criteria |
| [Epic index](_bmad-output/planning-artifacts/EPIC-INDEX.md) | All 33 epics — phase, source file, audit link |
| [Sprint tracker](_bmad-output/implementation-artifacts/sprint-status.yaml) | Consolidated story status (Epics 1–33) |
| [PRD](_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md) | Functional requirements, NFRs, user journeys |
| [Architecture](_bmad-output/planning-artifacts/architecture.md) | Technical decisions, structure, patterns |
| [UX specification](_bmad-output/planning-artifacts/ux-design-specification.md) | Tokens, screens, flows, accessibility |

Planning hub: [`_bmad-output/README.md`](_bmad-output/README.md)

---

## Roadmap

| Phase | Focus |
|-------|-------|
| **0: Sandbox** *(current)* | Flutter learning · phone steps · SQLite lifecycle · OSS beta |
| **1: Hub V1** | SQLCipher · BLE simulator · ADP reconciliation |
| **2: DevKit firmware** | Zephyr HAL · PPG/IMU drivers on Nordic DK |
| **3: Integrated prototype** | PCB · battery · enclosure · ADP end-to-end |
| **4: Industrialization** | CE/FCC · manufacturing · crowdfunding |

---

## What ASTRA is not

- A medical device or diagnostic tool
- A gamified fitness app (streaks, leaderboards, paid coaching)
- An Apple Health / Google Fit clone with cloud sync
- An Open Wearables server, only **schema vocabulary** is aligned

See also: [`docs/REGULATORY_POSITION.md`](docs/REGULATORY_POSITION.md)

---

## Contributing

The app is implemented and actively maintained. Contributions are welcome.

**Before contributing:**

1. Read [`docs/project-context.md`](docs/project-context.md), mandatory review-before-commit workflow
2. Read [`docs/README.md`](docs/README.md), documentation index
3. Check [`_bmad-output/README.md`](_bmad-output/README.md) and [`sprint-status.yaml`](_bmad-output/implementation-artifacts/sprint-status.yaml) for current status

**Invariants:**

- Local-first, no-cloud release health pipeline
- `DataIngestionSource` abstraction for all ingestion
- Storage bounds and lifecycle maintenance
- Do not add analytics, HTTP, or cloud SDKs to the health pipeline

---

## License

Application code: [Apache License 2.0](LICENSE).

Proprietary: ASTRA trademark, official brand identity, industrial design, app signing keys.

---

*Built by Baptiste Landrodie. Phase 0 = OSS credibility + foundations for a sovereign wearable ecosystem.*
