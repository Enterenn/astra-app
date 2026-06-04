---
title: ASTRA — Local-First Wearable & Mobile Ecosystem
status: final
created: 2026-05-22
updated: 2026-06-04
peer_review: 2026-05-22 (Gemini + ChatGPT, 2 rounds)
---

# PRD: ASTRA — Local-First Wearable & Mobile Ecosystem

## 0. Document Purpose

This PRD defines product capabilities and requirements for **ASTRA** — a local-first health data ecosystem comprising a Flutter mobile **Hub App** and, in later phases, a proprietary **Wearable** connected via the **Astra Device Protocol (ADP)**. It is written for the solo builder (UI/UX + front-end background), downstream UX/architecture/epics workflows, and future embedded partners.

**Structure:** Glossary-anchored vocabulary; features grouped with globally numbered FRs; assumptions tagged `[ASSUMPTION]` and indexed in §16. Technical depth (hardware, firmware HAL, ADP wire format, SQL DDL) lives in `addendum.md`.

**Primary inputs (2026-05-22):**
- External PRD v3.0 (French) — vision, KPIs, hardware/firmware intent
- `_bmad-output/brainstorming/brainstorming-session-2026-05-22-1521.md` — Phase 0 architecture and sprint plan
- `_bmad-output/planning-artifacts/research/market-astra-local-first-health-hub-research-2026-05-22.md`
- `_bmad-output/planning-artifacts/research/domain-astra-local-first-health-hub-research-2026-05-22.md`
- Peer review — Gemini + ChatGPT (2026-05-22, 2 rounds); §1.1–1.5, §4.3.1, FR-11/18/30, §6.3

**Current execution focus:** Phase 0 Sandbox — learn Flutter and local data persistence while shipping a beta-ready, open-source step-tracking Hub App. Future wearable, BLE, encryption, and sync capabilities are context only unless explicitly marked as Phase 0.

**Amendment (2026-06-04, approved):** Four-tab shell (Today · Trends · Data · Profil), Figma layouts, six accent presets with bi-tone selector on Profil → Appearance, Phosphor icons. Data sovereignty on **Data** tab (screen title **My Data**); profile prefs on **Profil**. Today: no greeting; Set goal on Today; stats row visible but empty until Epic 6 (FR-33). Full delta: `planning-artifacts/sprint-change-proposal-2026-06-04.md`.

---

## 1. Vision

ASTRA is a consumer wellness ecosystem built on a radical premise: **your health data belongs on your device, under your control, with no account and no cloud dependency in Phase 0 / V1.** The Phase 0 Hub App collects phone step data, aggregates it into readable trends, and stores everything locally. A companion Wearable (later phases) extends passive monitoring without changing the sovereignty model.

The product rejects the dominant wearable pattern — cloud lock-in, opaque analytics, subscription-gated insights, and moralizing AI coaching. Instead, ASTRA offers **proof over promises**: offline operation, visible storage footprint, exportable data, and purge controls that users can verify themselves.

Phase 0 is deliberately a **learning sandbox and credibility foundation**, not a throwaway prototype. The builder (solo UI/UX designer, Flutter novice) uses Phase 0 to master Flutter and local data lifecycle patterns while delivering an investor/beta-ready open-source app that validates the Hub architecture before hardware, BLE, and encryption layers arrive in later phases.

**Product category (regulatory + brand):** ASTRA is a **behavioral visibility tool**, not a health authority. It helps users see their own movement patterns — it does not diagnose, score readiness, or prescribe action.

---

## 1.1 Product Principles

These principles govern trade-offs when scope, architecture, or copy is ambiguous. Downstream workflows (UX, architecture, epics, Cursor) should treat them as non-negotiable unless explicitly overridden in `.decision-log.md`.

1. **Proof over promises** — Canonical brand line (README, onboarding, OSS manifesto, landing copy). Demonstrate privacy with verifiable behavior — airplane mode, export, purge, footprint — never marketing claims alone.
2. **Local-first by default** — Device is source of truth; cloud is never silent.
3. **No mandatory account** — No email, no auth, no identity layer in V1.
4. **Calm UX over engagement loops** — No streak shame, no DAU optimization, no moralizing nudges.
5. **Data minimization over exhaustive tracking** — Store interpretable aggregates, not raw sensor exhaust (see §1.2).
6. **Transparency over AI interpretation** — Show footprint, export, purge, background status; no opaque scores.
7. **Background autonomy over active interaction** — Value must accrue when the app is closed (Android reference platform).
8. **User ownership over ecosystem lock-in** — Export and re-import must keep users sovereign across reinstalls and devices (see §1.4).
9. **Protect My Data** — The **Data** tab (screen title **My Data**) is the primary sovereignty surface; footprint, export, import, purge, and background honesty are first-class features, not settings afterthoughts. Personal prefs and appearance live on **Profil**.

---

## 1.2 Data Doctrine & Storage Policy

**Doctrine:** ASTRA privileges **interpretable, useful aggregates** over exhaustive raw-signal collection. Raw accelerometer traces, PPG waveforms, high-frequency IMU logs, and debug sensor dumps must never enter the Hub database. Firmware may filter at the edge; the Hub persists only **Time Buckets** and lifecycle-compressed **Timeseries Samples**.

**Storage volume targets** (with **DataLifecycleService** active, steps-only Phase 0; wearable metrics addendum in Phase 2+):

| Horizon | Target DB size | Validates |
|---------|----------------|-----------|
| 1 year continuous history | < 50 MB | NFR-7 |
| 5 years continuous history | < 200 MB | NFR-8 |

These bounds guide SQL schema design, downsampling tiers, chart queries, and future wearable series — not "store because we can."

**Open Wearables alignment:** ASTRA aligns **conceptually** with Open Wearables vocabulary (column names, resolution tiers, series types) for export readability and future interoperability. ASTRA remains **implementation-independent** — no OW server dependency, no implied direct OW API compatibility in V1.

---

## 1.3 Time Semantics

**Source of truth:** All **Timeseries Sample** timestamps are persisted in **UTC** (`start_time`, `end_time` as ISO 8601 strings, e.g. `2026-05-22T14:30:00Z`). The **`zone_offset`** field captures the device's local offset **at ingestion time** (e.g. `+02:00`), preserved immutably on each row.

| Concern | Rule |
|---------|------|
| **Storage** | UTC only in `start_time` / `end_time` |
| **Daily goal aggregation** | Sum steps into local calendar days using each sample's stored `zone_offset` — not the device's current timezone after travel |
| **DST transitions** | Historical `zone_offset` on each row prevents retroactive day-boundary shifts when clocks change |
| **Travel / timezone change** | New samples carry new `zone_offset`; past days remain stable. `[ASSUMPTION: no automatic re-bucketing of historical data on timezone change in Phase 0]` |
| **Charts (7d/30d)** | Query UTC range; display labels may localize using stored offsets |

**NFR-9** validates this doctrine. Canonical record shape: §4.3.1.

---

## 1.4 Data Ownership

**Unit of ownership:** The user owns **every persisted Timeseries Sample** in the Hub database, regardless of **DataIngestionSource** (`internal_phone`, future `astra_wearable_v1`, imported CSV). Ingestion source affects `provider` / `device_id` metadata only — not ownership, export rights, or purge scope.

| Operation | Phase 0 | Future (not Phase 0) |
|-----------|---------|----------------------|
| **Export** | Full database CSV (FR-19) | Selective export by date/type/device |
| **Import** | Full CSV restore (FR-30) | Merge strategies for multi-device |
| **Purge** | Full health-data wipe: all Timeseries Samples and derived collection state, while preserving setup preferences (FR-20) | Selective purge by source or date range; optional full app reset |

Phase 0 implements **full export / full import / full health-data purge** only. Purge deletes persisted health data and derived collection state, but keeps non-health setup preferences such as `daily_step_goal`, onboarding completion, and permission choices so the user does not have to re-onboard after deleting their data. Selective operations and a full app reset are deferred without changing the ownership model above.

---

## 1.5 Product Maturity Note (Phase 0)

Phase 0 intentionally prioritizes **architectural correctness**, **privacy guarantees**, and **lifecycle learning** over feature breadth. The builder is learning Flutter and mobile platform constraints in parallel with shipping.

Implementation details may evolve during platform learning **provided that these invariants hold:**

- Local-first guarantees remain intact (no silent cloud)
- No-cloud / no-account principles remain intact
- **DataIngestionSource** abstraction is preserved
- **Timeseries Sample** lifecycle and storage bounds (§1.2, NFR-7/8) are preserved
- **Proof over promises** remains demonstrable on release builds

This clause prevents the PRD from becoming a prison while protecting non-negotiable product DNA.

---

## 2. Target User

### 2.1 Primary Persona — *Privacy Pragmatist*

**Alex, 32, product designer.** Uses Apple Health or Google Fit but distrusts cloud retention policies. Wants a simple step and activity view without creating an account, without ads, and without wondering where data goes. Values visual polish and would recommend a tool that *demonstrates* privacy (airplane mode works, export works, purge works) rather than claiming it in marketing copy.

### 2.2 Secondary Persona — *Builder-as-User*

**Baptiste (project owner).** Solo web/UI designer with front-end notions (HTML/CSS, Vue/React), learning Flutter. Phase 0 serves dual JTBD: ship a credible OSS demo and acquire the technical foundation (background collection, SQLite lifecycle, ingestion abstraction) required for ADP integration later.

### 2.3 Jobs To Be Done

- **Functional:** See today's movement, review history, understand trends, set a daily goal, know data persists without opening the app.
- **Emotional:** Feel in control of personal health data; avoid surveillance anxiety from mainstream fitness apps.
- **Social:** Share the project as an OSS reference (`[ASSUMPTION: beta audience = close network first, then GitHub/HN privacy communities]`).
- **Contextual:** Use the app fully offline; export CSV for personal analysis; re-import CSV after reinstall or device change.

### 2.4 Non-Users (V1 / Phase 0)

- Users seeking clinical diagnosis, medical alerts, or provider-integrated care.
- Users needing social leaderboards, coaching subscriptions, or cloud sync across devices (V2+ only, opt-in).
- Mainstream fitness users who prioritize ecosystem integrations (Strava, etc.) over local sovereignty.

### 2.5 Key User Journeys

**UJ-1. Alex verifies privacy on first launch.**

Alex installs the APK from a beta link. No account, no email. Onboarding shows a trust screen explaining local-only storage, requests activity recognition (and optional notification permission), and asks for a daily step goal (set-once philosophy). Alex enables airplane mode, walks 500 steps, and sees the Today ring update after background collection. **Climax:** data appears without network. **Resolution:** Alex trusts the app enough to keep it installed. **Edge case:** if background delivery is delayed (iOS), a stale-data indicator on the Data tab explains why.

**UJ-2. Alex checks progress mid-day.**

Alex opens the Hub App to the **Today** surface. A donut shows current steps vs daily target; **Set goal** sits below the ring; a **This week** row shows goal-met days. Kcal / distance / walking-time slots are visible but empty until derived metrics ship (FR-33). No personal greeting on Today. A subtle pulse animation celebrates goal completion once per day. Alex closes the app; **BackgroundCollector** continues writing **Time Buckets** without further interaction. Realizes FR-4, FR-14, FR-15.

**UJ-3. Alex reviews weekly trends.**

From **Trends** (same chart experience as former History), Alex toggles 7-day and 30-day bar views with a goal reference line and weekly trend. Charts render in under 100 ms even with 90+ days of injected test data (KPI-01). Realizes FR-16, FR-17.

**UJ-4. Alex exports, re-imports, and purges on Data.**

On the **Data** tab (screen title **My Data**), Alex sees storage footprint (sample count, approximate size), **last database optimization** timestamp, background collection status, and actions to export CSV (Open Wearables–aligned columns), **import a previously exported ASTRA CSV**, or purge all health data. After purge, counters show zero events / zero KB while setup and profile preferences remain. Export-before-purge is encouraged. Realizes FR-5, FR-13, FR-19, FR-20, FR-21, FR-30.

**UJ-4b. Alex updates profile and appearance.**

On **Profil**, Alex edits display name, height, and weight; toggles goal notifications; chooses System / Light / Dark and an accent color preset (six bi-tone circles). Realizes FR-9 (extended), FR-31, FR-32.

**UJ-5. Builder-as-User validates the ADP-ready architecture (Phase 0).**

The **Builder-as-User** runs dev tools to inject 90 days of simulated **Timeseries Samples**, triggers **DataLifecycleService** downsampling, and confirms chart query performance. **DataIngestionSource** accepts **PhonePedometerSource** today and an empty **AdpBleSource** stub for Phase 1+. Realizes FR-1, FR-3, FR-7, FR-11, FR-28.

---

## 3. Glossary

- **Hub App** — The Flutter mobile application; local-first health data hub. Sole product surface in Phase 0.
- **Wearable** — ASTRA ring or bracelet hardware (Phase 2+). Collects PPG, IMU, and optional skin temperature; stores bursts locally until Hub sync.
- **ADP (Astra Device Protocol)** — Proprietary BLE application-layer protocol for Wearable ↔ Hub data transfer, batching, and ACK-based flash reconciliation. Phase 1+.
- **Timeseries Sample** — A single aggregated measurement over a **Time Bucket** (e.g., step count for a 5-minute window). Stored in **timeseries_samples**. Aligns with Open Wearables vocabulary. Canonical shape: §4.3.1.
- **Time Bucket** — Fixed-duration window (default 5 minutes in Phase 0) into which raw sensor readings are summarized before persistence. No raw accelerometer or PPG waveforms are stored in the Hub database.
- **zone_offset** — Local UTC offset captured at ingestion time (e.g. `+02:00`), stored per **Timeseries Sample**. Used with UTC timestamps for local-day aggregation (§1.3).
- **Data Ownership** — User owns all persisted **Timeseries Samples** regardless of ingestion source (§1.4).
- **BackgroundCollector** — Single ingestion writer that receives **StepNormalizer** bucket output and inserts **Timeseries Samples** into SQLite.
- **DataIngestionSource** — Interface abstracting data origin (phone pedometer today; ADP Wearable tomorrow).
- **DataLifecycleService** — Background routine applying tiered downsampling and database maintenance (VACUUM) to bound storage growth.
- **Resolution** — Granularity tier of stored samples (e.g., `5min`, `1hour`, `1d`). Matches Open Wearables resolution concept.
- **Data** (tab label) / **My Data** (screen title) — Hub sovereignty surface: footprint, export, purge, background status.
- **Profil** — Local profile and appearance: informations, notifications, theme mode, accent preset.
- **Open Wearables (OW)** — External MIT-licensed self-hosted health aggregation platform. ASTRA uses OW **vocabulary only** (schema naming, resolution concept, CSV column semantics). No OW server dependency; no implied direct OW API compatibility in V1.
- **General Wellness Product** — Regulatory category: lifestyle/activity tracking without clinical diagnosis or treatment claims.
- **Phase 0 Sandbox** — Current R&D phase: phone-only Hub App, no SQLCipher, no BLE, no official brand assets in repo.

---

## 4. Features

### 4.1 Data Ingestion Abstraction

**Description:** All sensor data enters the Hub through **DataIngestionSource** implementations. Sources expose platform readings; **StepNormalizer** converts those readings into 5-minute step bucket increments before persistence. Phase 0 ships **PhonePedometerSource** (direct pedometer / activity recognition). An **AdpBleSource** stub exists with no functional BLE logic — it documents the extension point for Phase 1. Single-writer rule: only **BackgroundCollector** writes to SQLite. Realizes UJ-5.

**Functional Requirements:**

#### FR-1: DataIngestionSource interface

The Hub App defines a **DataIngestionSource** interface that yields raw platform **StepReading** events plus source metadata. **StepNormalizer** is the only component that converts cumulative readings, resets, and rollovers into storage-ready step **Timeseries Samples**.

**Consequences (testable):**
- A new source can be registered without modifying SQLite write logic or duplicating step-delta logic.
- **PhonePedometerSource** and **AdpBleSource** stub both implement the interface.

#### FR-2: Phone step ingestion

**PhonePedometerSource** reads step counts from the phone OS sensor APIs. **Android is the reference platform** for Phase 0 and Phase 1; iOS is secondary (see FR-4, A-2, A-13).

**Consequences (testable):**
- Samples include `type=steps`, `unit=count`, `provider=internal_phone`, `device_id=smartphone`.
- Ingestion respects platform permission flows (activity recognition / Health Connect path deferred to Phase 1 upgrade).
- **Hardware counter reset handling:** When the OS step counter resets (phone reboot, sensor rollover, or value lower than last read), ingestion computes a **delta** from the last known baseline and writes correct **Time Bucket** increments without negative or corrupted totals. Unit test covers at least one simulated reset scenario.

#### FR-3: ADP-ready stub

An **AdpBleSource** class implements **DataIngestionSource** but returns no data in Phase 0.

**Consequences (testable):**
- Stub is wired in dependency injection / factory alongside **PhonePedometerSource**.
- Documentation references ADP as Phase 1 activation point.

---

### 4.2 Background Collection

**Description:** Steps must persist when the app is closed. **BackgroundCollector** runs on platform-native background mechanisms (WorkManager on Android; BGAppRefresh on iOS). My Data shows honest background health (last sync time, stale warning if delivery fails). Realizes UJ-1, UJ-2.

**Functional Requirements:**

#### FR-4: Background step persistence

**BackgroundCollector** receives normalized **Time Buckets** and writes them to SQLite without requiring the user to open the Hub App.

**Platform behavior (explicit):**

| Platform | Phase 0 expectation |
|----------|---------------------|
| **Android (reference)** | Continuous or near-continuous bucket writes via WorkManager / FGS when OS permits |
| **iOS (secondary)** | **No continuous 5-minute real-time collection.** **PhonePedometerSource** backfills buckets on app foreground and on rare `BGAppRefresh` wakes — not a live background stream |

**Consequences (testable):**
- **Same-day passive accumulation (Android beta — primary):** On a reference Android device, with activity permission granted and the app not in foreground (backgrounded or removed from recents, **not** force-stopped from system Settings), the user walks ≥500 steps over ≥30 minutes. Within **15 minutes** (one WorkManager cycle) **or** on next app open, Today's step total increases by ≥80% of walked steps (OEM/sensor variance allowed).
- **Daily goal morning check (Android beta — secondary):** User did not open the app since prior evening; on first open of the local day after walking, Today shows today's steps > 0 when the phone sensor recorded steps for that day.
- **Force-stop / OEM kill (documented limit):** Steps may lag until foreground backfill; this is **not** a beta failure — My Data (Epic 4.2) will explain the constraint.
- After 24 hours without opening the app remains a **stress / SM-2 long-run** check, not the primary daily-goal acceptance path.
- Only one writer path exists to **timeseries_samples** (single-writer rule).
- iOS UI copy and **My Data** stale indicator reflect backfill model; no false promise of Android-parity background cadence.

#### FR-5: Background status visibility

**My Data** displays background collection status (last successful collection timestamp, stale-data warning when threshold exceeded).

**Consequences (testable):**
- Stale warning is platform-specific: **12 hours** without a new sample on Android beta (A-4), **4 hours** on iOS because foreground/backfill is best-effort and should be explained sooner.
- Copy does not blame the user; explains platform delivery constraints on iOS (backfill vs continuous collection).

#### FR-6: Android foreground service compliance

On Android 14+, background health collection uses the appropriate foreground service type (`health`) when required.

**Consequences (testable):**
- Manifest declares correct FGS type; no misuse of `dataSync` for health reads.

---

### 4.3 Local Persistence & Schema

**Description:** Hub stores aggregated **Timeseries Samples** in SQLite via `sqflite`. Schema aligns with Open Wearables unified model (`timeseries_samples` table, resolution column, provider/device metadata, zone_offset on timestamps). Phase 0 uses unencrypted SQLite with a documented migration path to SQLCipher in Phase 1. Realizes UJ-5.

**Functional Requirements:**

#### FR-7: timeseries_samples storage

The Hub persists **Timeseries Samples** in a `timeseries_samples` table with OW-aligned columns (id, start_time, end_time, type, value, unit, resolution, provider, device_id, zone_offset).

**Consequences (testable):**
- No raw sensor waveforms (PPG, accelerometer traces) exist in any table.
- Composite index supports type + start_time DESC queries for chart rendering.

#### FR-8: Five-minute default Time Buckets

Step samples are aggregated into **Time Buckets** of 5 minutes by default before insert.

**Consequences (testable):**
- Consecutive samples for the same type do not exceed one row per 5-minute window per device.
- Dev tooling can override bucket size for benchmarks.

#### FR-9: User preferences

A `user_preferences` table stores at minimum `daily_step_goal` (integer), `theme_mode` (`system` | `light` | `dark`), and `accent_preset` (`orange` | `red` | `green` | `cyan` | `purple` | `pink`, default `orange`).

Optional local-only profile fields: `display_name` (trimmed string), `height_cm` (integer centimeters), `weight_kg` (number, kilograms). Optional `goal_notifications_enabled` (boolean). **No** `age` or sex/gender fields in Phase 0 (not required for derived metrics; inclusivity).

**Derived-metrics defaults** (when height/weight unset): stride **0.76 m**; weight **70 kg** for calorie estimate.

**Consequences (testable):**
- Goal, theme, accent, and profile fields persist across app restarts.
- Default goal applied if user skips setup `[ASSUMPTION: 8000 steps]`.
- Default `theme_mode` is `system` on first launch — app follows OS light/dark setting until user overrides.
- `display_name` is **not** shown as a Today greeting in Phase 0 redesign (Profil only).

#### FR-10: Versioned schema migrations

Database schema changes use numbered migrations from project inception.

**Consequences (testable):**
- Fresh install and upgrade from prior schema version both succeed without data loss in Phase 0 test matrix.

#### 4.3.1 Canonical Sample Shape

Every ingestion path, dev inject tool, CSV export/import, and future ADP adapter must produce or consume rows conforming to this shape. Full DDL: `addendum.md` §2.

**Table:** `timeseries_samples`

```sql
CREATE TABLE IF NOT EXISTS timeseries_samples (
    id           TEXT PRIMARY KEY,   -- UUID v4
    start_time   TEXT NOT NULL,      -- ISO 8601 UTC, e.g. '2026-05-22T14:30:00Z'
    end_time     TEXT NOT NULL,      -- ISO 8601 UTC
    type         TEXT NOT NULL,      -- e.g. 'steps'
    value        REAL NOT NULL CHECK (value >= 0),
    unit         TEXT NOT NULL,      -- e.g. 'count'
    resolution   TEXT NOT NULL,      -- '5min' | '1hour' | '1d'
    provider     TEXT NOT NULL,      -- e.g. 'internal_phone'
    device_id    TEXT NOT NULL,      -- e.g. 'smartphone'
    zone_offset  TEXT NOT NULL,      -- e.g. '+02:00' at ingestion time
    CHECK (type <> 'steps' OR value = CAST(value AS INTEGER))
);
```

**Example row (logical / JSON interchange):**

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "start_time": "2026-05-22T14:30:00Z",
  "end_time": "2026-05-22T14:35:00Z",
  "type": "steps",
  "value": 132,
  "unit": "count",
  "resolution": "5min",
  "provider": "internal_phone",
  "device_id": "smartphone",
  "zone_offset": "+02:00"
}
```

**Invariants:** One row = one **Time Bucket** for one `type` + `device_id`. `value` is the aggregate for that window (step count sum, not a raw sensor reading). `value` remains `REAL` for future non-step series, but Phase 0 `type=steps` rows must be non-negative whole counts.

---

### 4.4 Data Lifecycle & Storage Management

**Description:** **DataLifecycleService** prevents unbounded database growth through tiered downsampling and weekly maintenance. Footprint is visible on My Data. Realizes UJ-4, UJ-5.

**Functional Requirements:**

#### FR-11: Tiered downsampling

**DataLifecycleService** applies resolution reduction on schedule:

| Data age | Storage resolution | Action |
|----------|-------------------|--------|
| 0–30 days | 5 min | Retain fine buckets |
| 31–365 days | 1 hour | Aggregate 12× five-minute buckets → 1 hourly sample |
| > 365 days | 1 day | Aggregate hourly → daily sample |

**Compaction policy:** Downsampling is **destructive and irreversible** once compaction completes — finer-resolution source rows are deleted after coarser aggregates are written. No archive tier retains original 5-minute buckets after hourly compaction. Export after compaction reflects coarser `resolution` only.

**Consequences (testable):**
- After simulated aging + lifecycle run, row count drops predictably; finer-resolution rows for compacted periods no longer exist.
- Downsampled rows carry updated `resolution` field.
- Test confirms pre-compaction export contains finer buckets; post-compaction export does not.

#### FR-12: Weekly database maintenance

Database maintenance runs weekly when the platform permits it. Android uses a scheduled background job. iOS treats maintenance as opportunistic: run after app foreground/resume when due, and optionally during `BGAppRefresh` if the OS grants time. No Phase 0 acceptance criterion assumes reliable iOS background `VACUUM`.

**Consequences (testable):**
- File size does not grow unbounded after repeated purge/downsample cycles in 90-day inject test.

#### FR-13: Storage footprint display

**My Data** shows approximate database size, total sample count, and **last database optimization** timestamp (from FR-12 maintenance).

**Consequences (testable):**
- Footprint updates after inject, export, import, purge, and lifecycle operations.
- "Last optimized" displays relative time (e.g., "2 days ago") after at least one VACUUM run.

---

### 4.5 Today Surface

**Description:** Primary dashboard — donut progress, **Set goal** control, weekly goal-status row, reserved activity stats row, once-per-day celebration. No personal greeting. Respects active theme and accent preset. Realizes UJ-2.

**Functional Requirements:**

#### FR-14: Today activity dashboard

**Today** displays:

- Screen title **Today's activity** (or i18n equivalent).
- Circular **donut** comparing current day steps to **daily_step_goal** (center count + goal sublabel).
- **Set goal** control below the donut (same bounds as FR-23: integer 1,000–100,000).
- **This week** row: seven day pills with goal-met / missed / today / future states.
- **Activity stats row:** kcal, distance, walking time — **visible** with placeholder values (`—`) until FR-33.

**Consequences (testable):**
- Donut fills proportionally; reaches 100% at or above goal.
- Daily step total computed per §1.3 / NFR-9 (UTC storage + stored `zone_offset`).
- **No** `Hello, {display_name}` greeting on Today.
- Set goal persists `daily_step_goal` via `UserPreferencesRepository`.

#### FR-15: Goal celebration

On first goal completion each calendar day, a subtle pulse/celebration animation plays.

**Consequences (testable):**
- Animation fires at most once per local calendar day.
- No gamification score or streak shame messaging.

---

### 4.6 Trends Surface

**Description:** Bar charts for 7-day and 30-day views with goal reference line and weekly trend indicator. Bottom tab label **Trends** (short); same chart behavior as pre-redesign History. Must meet KPI-01 render performance. Realizes UJ-3.

**Functional Requirements:**

#### FR-16: Trends charts

**Trends** renders bar charts for 7-day and 30-day step totals with a goal reference line.

**Consequences (testable):**
- Chart query + render completes in < 100 ms with 90 days of continuous injected data (KPI-01).
- User can switch between 7-day and 30-day views.

#### FR-17: Weekly trend indicator

**Trends** shows a simple weekly trend (e.g., up/down vs prior week) derived from stored samples.

**Consequences (testable):**
- Trend calculation uses only local SQLite data; no network call.

---

### 4.7 Data & Sovereignty

**Description:** The sovereignty surface on the **Data** tab — export, **import**, purge, footprint, background status. Screen title **My Data**. Primary product differentiator per §1.1. Realizes UJ-1, UJ-4. (Appearance and profile prefs moved to §4.7b Profil.)

**Functional Requirements:**

#### FR-18: No network dependency (Release builds)

The Hub App performs **no outbound network requests** in the health data pipeline.

**Build policy:**

| Build | INTERNET permission (Android) | Rule |
|-------|------------------------------|------|
| **Release / production** | **Absent** | Airplane-mode proof applies (UJ-1, SM-3) |
| **Debug / development** | **Permitted** | Flutter/Dart VM tooling only (hot reload, debugger). Health pipeline and dependencies must not use network even if permission is present |

**Consequences (testable):**
- Release APK manifest has no INTERNET permission.
- `docs/DEPENDENCIES.md` audit lists zero network use in health pipeline; explicitly confirms notification stack is **local-only** (e.g., `flutter_local_notifications` without FCM/Firebase/Mixpanel telemetry).
- 24-hour airplane mode beta checklist passes on **release** build (UJ-1).

#### FR-19: CSV export

User can export **Timeseries Samples** to CSV with OW-aligned column headers. Export preserves the `id` column exactly so later imports can be idempotent.

**Consequences (testable):**
- Exported file opens in standard spreadsheet tools.
- Export includes `id`, type, unit, resolution, timestamps, provider, device_id, and `zone_offset`.
- ASTRA writes the CSV to local cache/temp storage before invoking the OS share sheet. If the user chooses a third-party share target, any network transmission is user-initiated outside ASTRA's health pipeline.

#### FR-20: Full local purge

User can delete **all** local **Timeseries Samples** and derived collection state from the **Data** tab (§1.4 — full health-data purge only in Phase 0). Purge preserves non-health setup preferences such as `daily_step_goal`, `theme_mode`, `accent_preset`, profile fields (`display_name`, `height_cm`, `weight_kg`), `goal_notifications_enabled`, onboarding completion, and permission choices.

**Consequences (testable):**
- Post-purge: sample count = 0, footprint ≈ 0 KB.
- Purge requires explicit confirmation.
- Purge removes samples from all ingestion sources equally (phone, imported, future wearable).
- Post-purge onboarding does not restart, and the daily goal remains unchanged.

#### FR-21: Export-before-purge prompt

When user initiates purge, the Hub encourages export first (non-blocking).

**Consequences (testable):**
- Confirmation dialog mentions export option; user can cancel purge.

#### FR-30: CSV import

User can import a previously exported ASTRA CSV (same schema as FR-19) to repopulate **timeseries_samples** after reinstall, device migration, or post-purge recovery.

**Consequences (testable):**
- Import validates column headers and rejects malformed rows with user-visible error (no silent partial corruption).
- Idempotent import strategy documented: preserve `id`, skip duplicate `id`, and skip duplicate bucket identity if a malformed CSV reuses an existing bucket with a new id.
- Round-trip test: export → purge → import restores chart-visible history.

#### FR-31: Theme mode selection

User can choose **System**, **Light**, or **Dark** appearance from **Profil → Appearance**. Selection applies immediately app-wide (Today, Trends, Data, Profil, onboarding if shown).

**Consequences (testable):**
- Preference stored in `user_preferences.theme_mode` and restored on cold start without incorrect theme flash.
- Default is `system` until user changes — app follows OS light/dark setting when `system` is selected.
- When OS theme changes and `theme_mode` is `system`, app updates without restart.
- Both light and dark token sets meet NFR-5 contrast baseline on all four tab surfaces.

---

### 4.7b Profil Surface

**Description:** Local profile and appearance — no account. Realizes UJ-4b.

#### FR-32: Accent color preset

User selects one of six accent presets from **Profil → Appearance** via **bi-tone circular chips** (diagonal split: effective surface base + accent color). Selection applies immediately to ring, navigation, charts, and CTAs. Persisted in `user_preferences.accent_preset`. Default: `orange`.

**Consequences (testable):**
- Chips re-render when `theme_mode` or OS theme changes under System.
- Selected chip shows visible border/ring per UX mockups.
- Six presets: orange, red, green, cyan, purple, pink — each with light and dark token mappings.

#### FR-33: Derived activity metrics (Epic 6)

**Today** activity stats row displays **distance (km)**, **calories (kcal)**, and **walking duration** computed locally from today's step data, today's active time buckets, and optional profile height/weight. Until Epic 6 ships, row remains visible with placeholder values (`—`).

**Formulas (locked 2026-06-04):**

| Metric | Formula | Inputs |
|--------|---------|--------|
| **Distance** | `todaySteps × stride_m / 1000` (km) | `stride_m = (height_cm / 100) × 0.414` if `height_cm` set; else **0.76 m** default |
| **Walking time** | Sum of `(end_time − start_time)` for today's `timeseries_samples` where `type = steps` and `value > 0` | SQLite buckets only (typically 5-minute windows) |
| **Calories** | `MET × weight_kg × (walking_seconds / 3600)` with **MET = 3.5** (moderate walking, ACSM-style) | `weight_kg` from profile or **70 kg** default |

**Live display (Today):**
- **Distance** uses the same step count as the donut (SQLite daily sum scaled by live overlay when `LiveStepMonitor` is active).
- **Walking time** and **calories** derive from persisted buckets — may lag slightly until the next ingestion cycle (documented, not a defect).

**Out of scope Phase 0:** sex/gender field; age field; incline/speed/ACSM speed-grade equation; clinical calorie claims.

**Consequences (testable):**
- Unit tests cover defaults (no height/weight), custom height/weight, empty buckets, and one active bucket.
- Uses local data only; no network.
- Copy remains General Wellness (estimates, not medical authority).

---

### 4.8 Onboarding & Trust

**Description:** First-run flow: trust/privacy explanation, goal setup, optional notification opt-in. No account creation. Realizes UJ-1.

**Functional Requirements:**

#### FR-22: Trust-first onboarding

First launch presents local-only privacy explanation before requesting permissions.

**Consequences (testable):**
- No account, email, or authentication screen exists.
- Permission requests occur after trust copy, not before.

#### FR-23: Goal setup

Onboarding collects **daily_step_goal** with set-once philosophy (editable later via **Set goal** on Today).

**Consequences (testable):**
- Skipping goal setup applies default from FR-9.

#### FR-24: Notification opt-in

Onboarding offers optional local notification permission with explanation tied to goal-celebration use case.

**Consequences (testable):**
- Hub functions fully if notifications denied.

---

### 4.9 Local Goal Notification

**Description:** One local notification per day when daily step goal is reached, triggered by background collection — not a moralizing coach. Realizes UJ-2.

**Functional Requirements:**

#### FR-25: Daily goal notification

When **BackgroundCollector** detects that cumulative daily steps (summed from **Timeseries Samples** for the current local calendar day) meet or exceed **daily_step_goal**, the Hub fires at most one local notification per calendar day.

**Consequences (testable):**
- Goal evaluation uses local-day aggregation from SQLite, not a single bucket in isolation.
- No notification if permission denied.
- No notification spam on subsequent opens after goal already met.

---

### 4.10 Developer & OSS Foundation

**Description:** Public Apache 2.0 repo with README as pitch deck, schema docs, dev inject tools, beta checklist. Realizes builder JTBD and market GTM. `[ASSUMPTION: stakes = internal/beta-ready OSS, not full commercial launch PRD]`

**Functional Requirements:**

#### FR-26: Apache 2.0 open source

Application source code is published under **Apache License 2.0**.

**Consequences (testable):**
- `LICENSE` file present in repo root.
- README states Apache 2.0.

#### FR-27: Project documentation bundle

Repo includes `docs/OPEN_WEARABLES_ALIGNMENT.md`, `docs/SERIES_TYPES.md`, `docs/DEPENDENCIES.md` (network/privacy audit), and `docs/REGULATORY_POSITION.md` (General Wellness scope statement).

**Consequences (testable):**
- OW alignment doc lists column mapping and supported series types for Phase 0 (`steps/count`).
- Dependencies doc lists packages and confirms zero network use in health pipeline **on release builds**; documents debug INTERNET exception; audits `flutter_local_notifications` and background packages for cloud telemetry (no FCM/Firebase).
- Regulatory doc states wellness-only boundary; references CNIL local-only architecture note.

#### FR-28: Dev data inject & lifecycle simulator

Developer tooling can inject 90 days of synthetic **Timeseries Samples** and simulate downsampling.

**Consequences (testable):**
- Inject + lifecycle + chart render benchmark reproducible on CI or documented manual script.
- KPI-01 validated on injected dataset.

#### FR-29: Beta acceptance checklist

Project maintains a documented beta checklist covering accuracy, background, notifications, footprint, export, airplane mode, and visual cohesion per §11 Aesthetic & Tone.

**Consequences (testable):**
- Checklist exists in repo; items trace to FRs above.
- Visual cohesion items reference system-default theme, light/dark override, accent presets, and four-tab shell (Today / Trends / Data / Profil).
- Includes: release-build airplane mode, CSV export→purge→import round-trip (FR-30), step-counter reset unit test (FR-2).

---

## 5. Non-Goals (Explicit)

- Cloud storage, user accounts, email authentication, or analytics SDKs (Firebase, Mixpanel, etc.) in V1 and Phase 0.
- Clinical diagnosis, treatment recommendations, emergency alerts, or medical-device positioning.
- Moralizing AI coaching, opaque optimization scores, or engagement-maximizing notification spam.
- **Readiness / recovery / strain scores**, sleep quality scoring, fatigue recommendations, or WHOOP-style coaching depth — ASTRA shows patterns, not authority (§1 Vision).
- Raw sensor waveform persistence in the Hub database.
- SQLCipher encryption in Phase 0 (deferred to Phase 1).
- Functional BLE / Wearable / ADP in Phase 0.
- Open Wearables server integration or mandatory OW dependency in V1.
- Multi-device sync (V2+ opt-in only — self-hosted or managed ASTRA sync hub).
- Social features, leaderboards, or Strava-style sharing in Phase 0.
- WHOOP/Garmin direct competitor framing while Phase 0 is phone-only (market research guardrail).
- Official ASTRA brand assets, industrial design files, or app-store signing keys in the OSS repo (proprietary).

---

## 6. MVP Scope

### 6.1 In Scope — Phase 0 Sandbox

- Flutter Hub App (**Android = reference platform**; iOS secondary / backfill model)
- **PhonePedometerSource** + **BackgroundCollector** + **timeseries_samples** SQLite
- **DataLifecycleService** (downsampling + VACUUM)
- Four tab surfaces: **Today**, **Trends**, **Data**, **Profil** (+ onboarding)
- Trust onboarding, goal setup, optional local notification
- CSV **export + import**, purge, storage footprint + last optimization, background status (Data tab)
- Theme mode + six accent presets (Profil); Phosphor icons; floating four-tab navigation
- Today stats row placeholders until FR-33 (Epic 6)
- **AdpBleSource** stub; **DataIngestionSource** abstraction
- Dev inject tools (90-day benchmark)
- Apache 2.0 public repo, OW vocabulary docs, README pitch, beta checklist
- No network in health pipeline; **release** builds without INTERNET permission (debug exception per FR-18)

### 6.2 Out of Scope for Phase 0

| Item | Reason | Target phase |
|------|--------|--------------|
| SQLCipher / Keystore key escrow | Learning sandbox; migration path documented | Phase 1 |
| BLE pairing, ADP wire protocol | Requires hardware/firmware | Phase 1–2 |
| Wearable hardware (PPG, IMU) | Industrialization track | Phase 2–4 |
| Official UI brand system | Designer-led polish without proprietary assets in OSS | Phase 1 |
| Health Connect / HealthKit read path | Optional upgrade; pedometer sufficient for sandbox | Phase 1 |
| Recovery phrase (BIP39) backup | Encryption prerequisite | Phase 1 |
| ASTRA sync hub (self-hosted / managed) | Explicit opt-in V2+ | V2+ |
| App Store / Play Store production release | Beta sideload first | Post–Phase 0 beta |

### 6.3 Prepared vs Planned (Phase 0)

| Capability | Prepared (architecture/docs) | Planned for Phase 0 implementation |
|------------|------------------------------|------------------------|
| **DataIngestionSource** abstraction | ✅ | ✅ |
| **PhonePedometerSource** | ✅ | ✅ |
| **AdpBleSource** stub | ✅ | ✅ (stub only) |
| **BackgroundCollector** (Android reference) | ✅ | ✅ |
| **BackgroundCollector** (iOS parity) | ✅ | ❌ — backfill only |
| **timeseries_samples** + lifecycle | ✅ | ✅ |
| **SQLCipher** / Keystore | ✅ (migration path) | ❌ |
| **ADP / BLE sync** | ✅ (stub + docs) | ❌ |
| **CSV export** | ✅ | ✅ |
| **CSV import** | ✅ | ✅ |
| **Wearable hardware pipeline** | ✅ (addendum) | ❌ |
| **ASTRA sync hub (V2+)** | ✅ (addendum) | ❌ |

---

## 7. Success Metrics

**Primary**

- **SM-1: Chart render performance (KPI-01)** — Trends chart query + render < 100 ms with 90 days of continuous injected step data. Validates FR-16, FR-28.
- **SM-2: Background persistence** — Primary: same-day passive accumulation per FR-4 (Android beta). Long-run stress: step count increases over 24 h without opening app. Validates FR-4.
- **SM-3: Airplane mode proof** — Full core flow (view Today, Trends, export from Data) works after 24 h offline. Validates FR-18, UJ-1.
- **SM-4: Phase 0 learning outcome** — Builder can independently implement a new **DataIngestionSource** and SQLite migration without AI scaffolding `[ASSUMPTION: self-assessed at Phase 0 exit]`. Validates FR-1, FR-10.

**Secondary**

- **SM-5: Onboarding friction (KPI-03 adapted)** — First launch to first visible step data < 60 s on Android beta (no BLE pairing in Phase 0). Validates FR-22.
- **SM-6: App install size (KPI-04)** — Release APK/IPA < 50 MB. Validates Phase 0 build config.
- **SM-7: OSS credibility** — Beta checklist 100% pass; README demo GIF; ≥ 1 external beta tester completes airplane mode protocol on **release** build `[ASSUMPTION: "proches" network]`.
- **SM-8: Storage budget** — 1-year inject + lifecycle → DB file < 50 MB; 5-year scenario < 200 MB. Validates NFR-7, NFR-8, FR-11.

**Counter-metrics (do not optimize)**

- **SM-C1: Daily opens** — Do not optimize engagement loops; background collection is the success signal, not DAU.
- **SM-C2: Feature count** — Do not add screens beyond the four-tab MVP (+ onboarding); polish over breadth.
- **SM-C3: Cloud convenience** — Do not reintroduce sync "for usability" in Phase 0; sovereignty is the product.

---

## 8. Cross-Cutting NFRs

| ID | Requirement | Phase 0 target |
|----|-------------|----------------|
| NFR-1 | Chart render latency | < 100 ms (KPI-01) |
| NFR-2 | Install artifact size | < 50 MB (KPI-04) |
| NFR-3 | Offline operation | 100% core features without network |
| NFR-4 | Data at rest | Plaintext SQLite acceptable; SQLCipher Phase 1 |
| NFR-5 | Accessibility | `[ASSUMPTION: WCAG 2.1 AA aspirational for Phase 0; not blocking beta]` — contrast baseline in **both** light and dark themes |
| NFR-6 | Localization | English UI for Phase 0 OSS; French copy in README acceptable |
| NFR-7 | Storage budget (1 year) | SQLite DB < 50 MB with lifecycle active (steps-only) |
| NFR-8 | Storage budget (5 years) | SQLite DB < 200 MB with lifecycle active (steps-only) |
| NFR-9 | Time semantics | UTC storage; `zone_offset` preserved at ingestion; daily goals use stored offset per §1.3 |

---

## 9. Constraints & Guardrails

### Privacy

- No account, no cloud, no third-party analytics in health pipeline.
- Dependency audit published (`docs/DEPENDENCIES.md`).
- Purge and export must be user-initiated and verifiable.

### Regulatory (General Wellness)

- Product category: **General Wellness Product** — no clinical claims (FDA/CNIL-aligned; see domain research).
- **Positioning:** Behavioral visibility tool, **not** a health authority — no readiness scores, clinical thresholds, or "consult a doctor" prompts in Phase 0.
- Copy guardrails: never "diagnose", "treat", "medical grade", or "HIPAA compliant."
- CNIL local-only exemption applies only while architecture remains fully local with no remote service (V1). V2+ managed cloud requires full compliance stack (see addendum).

### Team & Execution

- **Solo builder** — UI/UX designer, Flutter novice; scope frozen to Phase 0 Must Ship list.
- Cursor/LLM-assisted development permitted; architecture guardrails (no network in health pipeline) are non-negotiable.

### Open Source

- **Code:** Apache License 2.0 (mobile app, future firmware/algorithms per addendum).
- **Proprietary:** ASTRA trademark, brand identity, industrial design, app signing keys.

---

## 10. Information Architecture

| Surface | Tab label | Screen title (if any) | Key elements |
|---------|-----------|----------------------|--------------|
| **Today** | TODAY | Today's activity | Donut, Set goal, week pills, stats row (placeholders until FR-33), celebration |
| **Trends** | TRENDS | History or Trends (TBD polish) | 7d/30d charts, goal line, weekly trend |
| **Data** | DATA | **My Data** | Background, footprint, export/import CSV, purge |
| **Profil** | PROFIL | My Profile | Informations (name, height, weight), notifications, Appearance (theme mode + accent bi-tone circles) |
| **Onboarding** | — | — | Trust, permissions, goal, notification opt-in (modal stack) |

**Navigation:** floating pill bottom bar, four tabs, Phosphor icons. Onboarding overlays first launch only.

---

## 11. Aesthetic & Tone

- **Visual:** Modern minimal; **system theme default**; user override on Profil; six accent presets; design-token-lite dual palette per preset.
- **Tone:** Calm, transparent, non-judgmental. No streak shaming, no "you failed today."
- **Anti-references:** Gamified fitness apps with leaderboards; clinical hospital UI; cluttered wearable companion apps with subscription upsells.

---

## 12. Platform

**Android is the reference platform for Phase 0 and Phase 1.** All acceptance tests, beta checklist, and SM-2 background persistence target Android first. iOS is secondary with explicitly reduced background expectations (FR-4, A-13).

| Platform | Phase 0 role | Notes |
|----------|--------------|-------|
| **Android** | **Reference platform** | WorkManager, FGS health type; release builds without INTERNET; continuous background target |
| **iOS** | Secondary / best-effort | Backfill on foreground + rare BGAppRefresh; honest stale UI; no 5-min continuous background promise |
| Wearable | N/A | Phase 2+ |
| Web / desktop | Non-goal | Mobile-only Hub |

---

## 13. Roadmap Phases (Context)

| Phase | Focus | Exit criterion (summary) |
|-------|-------|---------------------------|
| **0 — Sandbox** | Flutter learning; phone steps; SQLite lifecycle | Beta checklist pass; KPI-01; OSS repo live |
| **1 — Hub V1** | SQLCipher, BLE simulator, UI freeze, key backup | Encrypted DB; ADP reconciliation tested in sim |
| **2 — DevKit firmware** | Zephyr HAL, PPG/IMU drivers on Nordic DK | Valid sensor acquisition via HAL |
| **3 — Integrated prototype** | PCB, battery, enclosure | End-to-end ADP with Hub |
| **4 — Industrialization** | CE/FCC, manufacturing, crowdfunding | Market-ready hardware + store apps |

Hardware, firmware, and ADP detail: `addendum.md`.

---

## 14. Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Solo execution bandwidth | High | Ruthless Phase 0 scope; brainstorming sprint plan |
| iOS background unreliability | High | **Android reference platform**; iOS backfill-only model (FR-4, A-13); stale-data honesty UI |
| Step counter hardware reset | Medium | Delta-based ingestion (FR-2); unit test for reboot scenario |
| Platform API changes (Health Connect) | Medium | **DataIngestionSource** abstraction |
| Storage fear / trust | Medium | **DataLifecycleService** + footprint UI |
| PPG motion artifacts (future) | Critical (V1+) | IMU gating in firmware (addendum) |
| Key loss after SQLCipher (Phase 1) | Moderate | Recovery phrase at init (Phase 1) |
| RF/CEM certification (hardware) | High (Phase 4) | Pre-certified Nordic modules |
| PRD over-specification before Flutter learning | Medium | §1.5 Product Maturity Note — invariants vs implementation flexibility |

---

## 15. Open Questions

| # | Question | Status | Owner | Revisit when |
|---|----------|--------|-------|--------------|
| 1 | Step accuracy baseline — ± margin vs native Health app for beta sign-off? | **Deferred** | Baptiste | First beta build ready |
| 2 | Health Connect vs pedometer-only in Phase 0? | **Resolved → Phase 1** | — | Health Connect path in §6.2 out-of-scope table |
| 3 | iOS TestFlight in Phase 0 or Android-only? | **Deferred** | Baptiste | Sprint 1 background pipeline validated on Android |
| 4 | Default daily step goal — 8000 or locale-based? | **Assumed 8000** (A-3) | Baptiste | Onboarding UX design |
| 5 | Settings tab vs goal edit location? | **Resolved → Today Set goal** (2026-06-04) | Baptiste | — |
| 6 | Legal review of CNIL local-only position | **Deferred** | Baptiste | Pre–commercial EU launch (not Phase 0 blocker) |

---

## 16. Assumptions Index

- **A-1:** Beta audience = close network first, then OSS/privacy communities (§2.3).
- **A-2:** Android is the **reference platform** for Phase 0 and Phase 1; iOS is secondary (FR-2, FR-4, §12).
- **A-3:** Default daily step goal = 8000 (FR-9).
- **A-4:** Stale-data threshold = **12 hours** on Android and **4 hours** on iOS (FR-5) — Android avoids overnight false positives; iOS explains best-effort backfill sooner.
- **A-5:** Bottom tab navigation for four surfaces (§10) — TODAY, TRENDS, DATA, PROFIL.
- **A-6:** WCAG 2.1 AA aspirational, not blocking Phase 0 beta (NFR-5).
- **A-7:** Phase 0 stakes = internal/beta-ready OSS, not commercial launch (FR-26).
- **A-8:** Self-assessed Flutter learning outcome at Phase 0 exit (SM-4).
- **A-9:** Goal edit lives on **Today** via Set goal (FR-14, FR-23); amended 2026-06-04.
- **A-10:** Schema uses `timeseries_samples` with 5-minute buckets (overrides external PRD `health_events` / 1-minute buckets).
- **A-11:** V2+ sync via ASTRA hub (self-hosted + managed), not OW server export (brainstorming amendement).
- **A-12:** SQLCipher deferred to Phase 1 (domain research).
- **A-13:** iOS **PhonePedometerSource** uses historical backfill on app open / rare OS wake — not continuous 5-minute background writes (FR-4).
- **A-14:** Debug builds may declare INTERNET for Flutter tooling; release builds must not (FR-18).
- **A-15:** Storage targets: 1 year < 50 MB, 5 years < 200 MB with lifecycle (§1.2, NFR-7, NFR-8).
- **A-16:** No automatic re-bucketing of historical samples when device timezone changes in Phase 0 (§1.3).
- **A-17:** Downsampling is destructive/irreversible after compaction (FR-11).
- **A-18:** Default `theme_mode` = `system`; user may override on Profil (FR-31). Default `accent_preset` = `orange` (FR-32).
- **A-19:** Today activity stats (kcal / km / duration) ship in Epic 6 (FR-33); visible placeholders until then (2026-06-04).
- **A-20:** Derived metrics use height/weight only — no age or sex/gender; defaults stride 0.76 m, weight 70 kg; calories via MET 3.5 × weight × walking duration (2026-06-04).
