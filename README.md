# ASTRA

**Local-first. No account. No cloud. Proof over promises.**

ASTRA is a **local-first** wellness ecosystem: a Flutter mobile Hub App that collects and visualizes movement data from your phone's sensors, with a proprietary wearable planned in later phases. Your data stays on your device, under your control.

> *"The step counter that works in airplane mode."*

---

## Project status

| | |
|---|---|
| **Current phase** | Phase 0 — Sandbox (Flutter learning + architecture foundations) |
| **Code status** | **Pre-implementation** — PRD, architecture, and UX are specified; the Flutter scaffold is not initialized yet |
| **Reference platform** | Android (iOS secondary, with reduced background expectations) |
| **License** | [Apache License 2.0](LICENSE) *(to be added before public release)* |

---

## Vision

ASTRA is built on a simple premise: **your health data belongs to you**. No mandatory account, no cloud dependency in Phase 0 / V1, no moralizing coaching or engagement loops.

Phase 0 is not a throwaway prototype. It is a **learning sandbox** that must deliver a credible open-source app — proof that the Hub architecture holds before encryption, BLE, and the wearable arrive.

**Product category:** **behavioral visibility tool** (General Wellness Product). ASTRA helps you see your own movement patterns — it does not diagnose, prescribe, or score "readiness."

---

## Product principles

1. **Proof over promises** — airplane mode, export, purge, storage footprint: verifiable behavior, not marketing claims.
2. **Local-first by default** — the device is the source of truth.
3. **No mandatory account** — no email, no auth layer in V1.
4. **Calm UX** — no streak shame, no DAU optimization.
5. **Data minimization** — interpretable aggregates, not raw sensor exhaust.
6. **Transparency** — footprint, export, purge, and background status are visible.
7. **Background autonomy** — value accrues when the app is closed (Android).
8. **User sovereignty** — CSV export and re-import keep you in control.
9. **My Data is first-class** — the My Data surface is the primary differentiator.

---

## Phase 0 — What the app does (and does not)

### Included

- Step counter via phone sensors (`PhonePedometerSource`)
- Background collection (Android = reference; iOS = foreground backfill)
- Local SQLite storage (`timeseries_samples`, 5-minute buckets)
- Three surfaces: **Today** · **History** · **My Data**
- Trust-first onboarding (permissions, daily goal)
- CSV export / import ([Open Wearables](https://github.com/theopenwearables/open-wearables)-aligned columns — vocabulary only, no OW server dependency)
- Full health-data purge
- DB lifecycle (downsampling, maintenance) to bound growth (< 50 MB / year)
- `DataIngestionSource` abstraction + `AdpBleSource` stub for Phase 1

### Excluded (later phases)

- SQLCipher encryption (Phase 1)
- Functional BLE / Wearable / ADP protocol (Phase 1–2)
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

**Visual tone:** quiet instrument panel — dark mode by default, clear hierarchy, no aggressive gamification.

---

## Architecture (overview)

Phase 0 data pipeline:

```
OS sensor (pedometer)
    → DataIngestionSource (PhonePedometerSource)
    → StepNormalizer (deltas, reboot, counter reset)
    → BackgroundCollector (sole ingestion writer)
    → StepRepository → SQLite (timeseries_samples)
    → UI (Today / History / My Data)
    → DataLifecycleService (downsampling, VACUUM)
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
├── core/          # DB, DI, time, background services
├── data/          # datasources, models, repositories
└── presentation/  # cubits, onboarding, screens, widgets
```

Full decisions: [`_bmad-output/planning-artifacts/architecture.md`](_bmad-output/planning-artifacts/architecture.md)

---

## Tech stack (Phase 0)

| Layer | Choice |
|-------|--------|
| Framework | Flutter 3.44+ (Dart 3.x), `--empty`, Android + iOS |
| Persistence | `sqflite` — on-device SQLite, WAL, versioned migrations |
| Background | `workmanager` + FGS health (Android) |
| Sensors | `pedometer` |
| Charts | `fl_chart` |
| Notifications | `flutter_local_notifications` (local only) |
| Export | `share_plus` |
| State | Cubit (`flutter_bloc`) |
| Bundle ID | `com.astraapp` |

**Naming:** repo `astra-app` · Dart package `astra_app` · DB file `astra_app.db`

---

## Data model (summary)

Primary table `timeseries_samples` — one sample = one aggregated **Time Bucket** (e.g. steps over 5 minutes):

| Field | Example |
|-------|---------|
| `type` / `unit` | `steps` / `count` |
| `resolution` | `5min` · `1hour` · `1d` |
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
5. Reopen **Today** → steps should have accumulated in the background (Android)
6. Go to **My Data** → export CSV, verify footprint, test purge

This is the OSS hero demo — not a marketing claim, a verifiable behavior.

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

Planning artifacts (source of truth for implementation):

| Document | Contents |
|----------|----------|
| [PRD](_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md) | Functional requirements, NFRs, user journeys |
| [Technical addendum](_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md) | SQL DDL, ADP/firmware details (future phases) |
| [Architecture](_bmad-output/planning-artifacts/architecture.md) | Technical decisions, structure, patterns |
| [UX specification](_bmad-output/planning-artifacts/ux-design-specification.md) | Tokens, screens, flows, accessibility |
| [Decision log](_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/.decision-log.md) | Product decision journal |
| [Market research](_bmad-output/planning-artifacts/research/market-astra-local-first-health-hub-research-2026-05-22.md) | Competitive positioning |
| [Domain research](_bmad-output/planning-artifacts/research/domain-astra-local-first-health-hub-research-2026-05-22.md) | Regulatory, health data, OW alignment |

---

## Roadmap

| Phase | Focus |
|-------|-------|
| **0 — Sandbox** *(current)* | Flutter learning · phone steps · SQLite lifecycle · OSS beta |
| **1 — Hub V1** | SQLCipher · BLE simulator · ADP reconciliation |
| **2 — DevKit firmware** | Zephyr HAL · PPG/IMU drivers on Nordic DK |
| **3 — Integrated prototype** | PCB · battery · enclosure · ADP end-to-end |
| **4 — Industrialization** | CE/FCC · manufacturing · crowdfunding |

---

## What ASTRA is not

- A medical device or diagnostic tool
- A gamified fitness app (streaks, leaderboards, paid coaching)
- An Apple Health / Google Fit clone with cloud sync
- An Open Wearables server — only **schema vocabulary** is aligned

---

## Contributing

The project is in advanced planning; implementation is upcoming. Contributions will be welcome once the Flutter scaffold and the first story (ingestion + persistence) are in place.

In the meantime:

- Read the PRD and architecture before opening a PR
- Respect invariants: local-first, no-cloud release, `DataIngestionSource` abstraction, storage bounds
- Do not add analytics, HTTP, or cloud SDKs to the health pipeline

---

## License

Application code: **Apache License 2.0** (planned).

Proprietary: ASTRA trademark, official brand identity, industrial design, app signing keys.

---

*Built by Baptiste Landrodie. Phase 0 = OSS credibility + foundations for a sovereign wearable ecosystem.*
