# ASTRA

**Local-first. No account. No cloud. Proof over promises.**

ASTRA is a **local-first** wellness ecosystem: a Flutter mobile Hub App that collects and visualizes movement data from your phone's sensors, with a proprietary wearable planned in later phases. Your data stays on your device, under your control.

> *"The step counter that works in airplane mode."*

---

## Project status

| | |
|---|---|
| **Current phase** | Phase 0 â€” Sandbox (Flutter learning + architecture foundations) |
| **Code status** | **Pre-implementation** â€” PRD, architecture, and UX are specified; the Flutter scaffold is not initialized yet |
| **Reference platform** | Android (iOS secondary, with reduced background expectations) |
| **License** | [Apache License 2.0](LICENSE) |

---

## Vision

ASTRA is built on a simple premise: **your health data belongs to you**. No mandatory account, no cloud dependency in Phase 0 / V1, no moralizing coaching or engagement loops.

Phase 0 is not a throwaway prototype. It is a **learning sandbox** that must deliver a credible open-source app â€” proof that the Hub architecture holds before encryption, BLE, and the wearable arrive.

**Product category:** **behavioral visibility tool** (General Wellness Product). ASTRA helps you see your own movement patterns â€” it does not diagnose, prescribe, or score "readiness."

---

## Product principles

1. **Proof over promises** â€” airplane mode, export, purge, storage footprint: verifiable behavior, not marketing claims.
2. **Local-first by default** â€” the device is the source of truth.
3. **No mandatory account** â€” no email, no auth layer in V1.
4. **Calm UX** â€” no streak shame, no DAU optimization.
5. **Data minimization** â€” interpretable aggregates, not raw sensor exhaust.
6. **Transparency** â€” footprint, export, purge, and background status are visible.
7. **Background autonomy** â€” value accrues when the app is closed (Android).
8. **User sovereignty** â€” CSV export and re-import keep you in control.
9. **My Data is first-class** â€” the My Data surface is the primary differentiator.

---

## Phase 0 â€” What the app does (and does not)

### Included

- Step counter via phone sensors (`PhonePedometerSource`)
- Background collection (Android = reference; iOS = foreground backfill)
- Local SQLite storage (`timeseries_samples`, 5-minute buckets)
- Three surfaces: **Today** Â· **History** Â· **My Data**
- Trust-first onboarding (permissions, daily goal)
- CSV export / import ([Open Wearables](https://github.com/theopenwearables/open-wearables)-aligned columns â€” vocabulary only, no OW server dependency)
- Full health-data purge
- DB lifecycle (downsampling, maintenance) to bound growth (< 50 MB / year)
- `DataIngestionSource` abstraction + `AdpBleSource` stub for Phase 1

### Excluded (later phases)

- SQLCipher encryption (Phase 1)
- Functional BLE / Wearable / ADP protocol (Phase 1â€“2)
- Health Connect / HealthKit (Phase 1)
- Cloud sync, user accounts, third-party analytics
- Leaderboards, coaching, opaque scores

---

## Interface

| Surface | Purpose |
|---------|---------|
| **Today** | Goal ring, today's steps, sensor source label, subtle celebration |
| **History** | 7d / 30d charts, goal reference line, weekly trend |
| **My Data** | DB footprint, last optimization, background status, export / import / purge |
| **Onboarding** | Trust, permissions, goal (8000 steps default), optional notifications |

**Visual tone:** quiet instrument panel â€” **System theme default** (follows OS); Light and Dark available on My Data â€” clear hierarchy, no aggressive gamification.

---

## Architecture (overview)

Phase 0 data pipeline:

```
OS sensor (pedometer)
    â†’ DataIngestionSource (PhonePedometerSource)
    â†’ StepNormalizer (deltas, reboot, counter reset)
    â†’ BackgroundCollector (sole ingestion writer)
    â†’ StepRepository â†’ SQLite (timeseries_samples)
    â†’ UI (Today / History / My Data)
    â†’ DataLifecycleService (downsampling, VACUUM)
```

**Key rules:**

- Single ingestion write path to SQLite
- Timestamps in **UTC** + immutable `zone_offset` per sample (stable local-day aggregation)
- Chart aggregates in the repository (`ChartDayAggregate`), not in widgets
- **Release builds without INTERNET permission** (privacy by architecture)
- SQLite transactions for all multi-row operations

Planned `lib/` structure:

```
lib/
â”œâ”€â”€ core/          # DB, DI, time, background services
â”œâ”€â”€ data/          # datasources, models, repositories
â””â”€â”€ presentation/  # cubits, onboarding, screens, widgets
```

Full decisions: [`_bmad-output/planning-artifacts/architecture.md`](_bmad-output/planning-artifacts/architecture.md)

---

## Tech stack (Phase 0)

| Layer | Choice |
|-------|--------|
| Framework | Flutter 3.44+ (Dart 3.x), `--empty`, Android + iOS |
| Persistence | `sqflite` â€” on-device SQLite, WAL, versioned migrations |
| Background | `workmanager` + FGS health (Android) |
| Sensors | `pedometer` |
| Charts | `fl_chart` |
| Notifications | `flutter_local_notifications` (local only) |
| Export | `share_plus` |
| State | Cubit (`flutter_bloc`) |
| Bundle ID | `com.astraapp` |

**Naming:** repo `astra-app` Â· Dart package `astra_app` Â· DB file `astra_app.db`

---

## Data model (summary)

Primary table `timeseries_samples` â€” one sample = one aggregated **Time Bucket** (e.g. steps over 5 minutes):

| Field | Example |
|-------|---------|
| `type` / `unit` | `steps` / `count` |
| `resolution` | `5min` Â· `1hour` Â· `1d` |
| `provider` / `device_id` | `internal_phone` / `smartphone` |
| `start_time` / `end_time` | ISO 8601 UTC |
| `zone_offset` | `+02:00` (captured at ingestion) |

No raw accelerometer, PPG, or IMU traces in the database.

Full schema: [`_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md`](_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md)

---

## Airplane mode protocol (privacy proof)

Reference test to validate the local-first promise on a **release** build:

1. Install the release APK (no network permission)
2. Complete onboarding (no account)
3. Enable **airplane mode**
4. Walk ~500 steps without keeping the app open
5. Reopen **Today** â†’ steps should have accumulated in the background (Android)
6. Go to **My Data** â†’ export CSV, verify footprint, test purge

This is the OSS hero demo â€” not a marketing claim, a verifiable behavior.

---

## Developer setup

**Prerequisites:** Flutter stable 3.44+, Android SDK, Xcode (for iOS)

Flutter code is not scaffolded yet. First implementation story:

```bash
flutter channel stable
flutter upgrade

# From repo root (astra-app/)
flutter create . \
  --org com.astraapp \
  --project-name astra_app \
  --platforms=android,ios \
  --android-language=kotlin \
  --empty
```

Then add dependencies (`sqflite`, `workmanager`, `pedometer`, etc.) and implement per the documented architecture.

---

## Project documentation

**Start here:** [`_bmad-output/README.md`](_bmad-output/README.md) â€” navigation hub for all BMAD artifacts.

Planning artifacts (source of truth for implementation):

| Document | Contents |
|----------|----------|
| [Agent workflow rules](docs/project-context.md) | Review-before-commit gate, commit conventions *(mandatory for contributors)* |
| [Epics & stories](_bmad-output/planning-artifacts/epics.md) | 26 stories with acceptance criteria |
| [Implementation readiness](_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-25.md) | Alignment verdict â€” READY FOR IMPLEMENTATION |
| [Sprint tracker](_bmad-output/implementation-artifacts/sprint-status.yaml) | Story status (all backlog) |
| [PRD](_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md) | Functional requirements, NFRs, user journeys |
| [Technical addendum](_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md) | SQL DDL, ADP/firmware details (future phases) |
| [Architecture](_bmad-output/planning-artifacts/architecture.md) | Technical decisions, structure, patterns |
| [UX specification](_bmad-output/planning-artifacts/ux-design-specification.md) | Tokens, screens, flows, accessibility |
| [Decision log](_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/.decision-log.md) | Product decision journal |
| [Brainstorming](_bmad-output/brainstorming/brainstorming-session-2026-05-22-1521.md) | Phase 0 ideation session |
| [Market research](_bmad-output/planning-artifacts/research/market-astra-local-first-health-hub-research-2026-05-22.md) | Competitive positioning |
| [Domain research](_bmad-output/planning-artifacts/research/domain-astra-local-first-health-hub-research-2026-05-22.md) | Regulatory, health data, OW alignment |

---

## Roadmap

| Phase | Focus |
|-------|-------|
| **0 â€” Sandbox** *(current)* | Flutter learning Â· phone steps Â· SQLite lifecycle Â· OSS beta |
| **1 â€” Hub V1** | SQLCipher Â· BLE simulator Â· ADP reconciliation |
| **2 â€” DevKit firmware** | Zephyr HAL Â· PPG/IMU drivers on Nordic DK |
| **3 â€” Integrated prototype** | PCB Â· battery Â· enclosure Â· ADP end-to-end |
| **4 â€” Industrialization** | CE/FCC Â· manufacturing Â· crowdfunding |

---

## What ASTRA is not

- A medical device or diagnostic tool
- A gamified fitness app (streaks, leaderboards, paid coaching)
- An Apple Health / Google Fit clone with cloud sync
- An Open Wearables server â€” only **schema vocabulary** is aligned

---

## Contributing

The project is in advanced planning; implementation is upcoming. Contributions will be welcome once the Flutter scaffold and the first story (ingestion + persistence) are in place.

**Before contributing:**

1. Read [`docs/project-context.md`](docs/project-context.md) â€” mandatory review-before-commit workflow
2. Read [`_bmad-output/README.md`](_bmad-output/README.md) â€” artifact navigation and reading order
3. Check [`sprint-status.yaml`](_bmad-output/implementation-artifacts/sprint-status.yaml) for current story status

In the meantime:

- Read the PRD and architecture before opening a PR
- Respect invariants: local-first, no-cloud release, `DataIngestionSource` abstraction, storage bounds
- Do not add analytics, HTTP, or cloud SDKs to the health pipeline

---

## License

Application code: [Apache License 2.0](LICENSE).

Proprietary: ASTRA trademark, official brand identity, industrial design, app signing keys.

---

*Built by Baptiste Landrodie. Phase 0 = OSS credibility + foundations for a sovereign wearable ecosystem.*
