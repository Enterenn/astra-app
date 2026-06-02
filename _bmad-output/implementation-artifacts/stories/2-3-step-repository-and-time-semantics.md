# Story 2.3: Step Repository and Time Semantics

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want today's step total computed correctly across timezone boundaries,
So that my daily goal reflects my local calendar day even when traveling.

## Acceptance Criteria

1. **Given** `TimeProvider` is injected (no raw `DateTime.now()` in repository/normalizer)
   **When** samples are written and read
   **Then** timestamps are ISO 8601 UTC with immutable per-row `zone_offset` (NFR9)

2. **Given** samples with different stored `zone_offset` values
   **When** `getTodaySteps()` is called
   **Then** `LocalDayCalculator` groups by each row's stored offset — not device current timezone
   **And** `local_day` is never computed via SQL `date(start_time, zone_offset)`

3. **Given** ingestion bucket upsert
   **When** `BackgroundCollector` calls `StepRepository.upsertIngestionBucket()`
   **Then** upsert uses bucket identity UNIQUE constraint — only ingestion path may call this method

## Tasks / Subtasks

- [x] **Sub-task A — LocalDayCalculator + unit tests** (AC: #2)
  - [x] Add `lib/core/time/local_day_calculator.dart` — pure function: UTC `DateTime` + immutable `zone_offset` string → local calendar date (`DateTime` at UTC midnight for that local date, or documented date-only key type).
  - [x] Parse `zone_offset` as `±HH:MM` (same format as `StepNormalizer._formatZoneOffset`).
  - [x] Add `test/core/time/local_day_calculator_test.dart` — **mandatory travel scenario**: two rows same UTC instant, different stored offsets → different local days; plus DST edge (offset change on new rows only).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — TimeseriesSampleModel + timestamp helpers** (AC: #1)
  - [x] Add `lib/data/models/timeseries_sample_model.dart` — full DB row map aligned with `timeseries_samples` DDL (Story 2.1).
  - [x] Add shared ISO 8601 UTC formatting/parsing helpers (e.g. `lib/core/time/timestamp_codec.dart` or static methods on model) — storage always `…Z` suffix; never store local time in `start_time`/`end_time`.
  - [x] Map from `NormalizedStepBucket` + generated UUID → insert map (repository uses this; normalizer stays id-free).
  - [x] Add focused model/codec unit tests.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — StepRepository upsertIngestionBucket** (AC: #1, #3)
  - [x] Add `lib/data/repositories/step_repository.dart` — takes `Database` + `TimeProvider` (clock used for `getTodaySteps` reference day only, not for rewriting stored offsets on upsert).
  - [x] Implement `Future<void> upsertIngestionBucket(NormalizedStepBucket bucket)`:
    - [x] Generate UUID v4 on **insert** via `uuid` package.
    - [x] Persist all canonical columns; integer `value` for `type=steps`.
    - [x] Upsert on bucket identity `(provider, device_id, type, start_time, end_time, resolution)` using `ON CONFLICT … DO UPDATE SET value = excluded.value` — **preserve existing `id` on conflict** (do not use blind `ConflictAlgorithm.replace` on full row).
  - [x] Document in dartdoc: **only `BackgroundCollector` may call this method** (Story 2.4 wires the caller; tests may call directly).
  - [x] Add `test/data/repositories/step_repository_upsert_test.dart` — insert, duplicate bucket updates value not id, negative value rejected by DB CHECK.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — getTodaySteps + travel semantics tests** (AC: #2)
  - [x] Implement `Future<int> getTodaySteps()` on `StepRepository`:
    - [x] Compute reference **today** via `LocalDayCalculator.localDay(utc: timeProvider.nowUtc(), zoneOffset: formatted current offset from timeProvider)` — this is the user's current local calendar day anchor.
    - [x] Load step rows (query `type = 'steps'`; acceptable to load day-relevant UTC window or all rows for Phase 0 test DB sizes).
    - [x] For **each row**, compute `localDay` with **that row's stored `zone_offset`** via `LocalDayCalculator`.
    - [x] Sum `value` where row `localDay` equals reference today.
  - [x] **Never** use SQL `date(start_time, zone_offset)` or `DateTime.now().timeZoneOffset` for historical rows.
  - [x] Add `test/data/repositories/step_repository_today_test.dart` — travel fixture:
    - [x] Row A: UTC evening, `zone_offset +02:00` → counts toward Paris-local today.
    - [x] Row B: same UTC instant, `zone_offset -05:00` → different local day; must not pollute today total when reference today is Paris-local.
    - [x] Assert totals change correctly when `FakeTimeProvider` shifts reference day.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — AppDependencies wiring** (AC: #1)
  - [x] Extend `lib/core/di/app_dependencies.dart` — expose `StepRepository stepRepository` constructed from shared DB handle + `timeProvider`.
  - [x] Update `create()` and `test()` factories; extend `test/data/repositories/` or `test/core/di/app_dependencies_test.dart` if needed.
  - [x] **Do not** add `BackgroundCollector`, WorkManager, or UI Cubits.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task F — Verification** (AC: #1–#3)
  - [x] Run `flutter analyze`.
  - [x] Run `flutter test test/core/time/local_day_calculator_test.dart test/data/repositories/`.
  - [x] Run full `flutter test`.
  - [x] Review brief explains travel test in plain language.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 2.3:**
- `LocalDayCalculator` — UTC + immutable per-row `zone_offset` → local calendar day (NFR9).
- `TimeseriesSampleModel` + timestamp codec aligned with Story 2.1 DDL.
- `StepRepository` with `upsertIngestionBucket()` and `getTodaySteps()`.
- Repository unit tests including **travel / mixed `zone_offset`** scenario.
- `AppDependencies` exposes `StepRepository` (no runtime collection).

**Out of scope — defer to later stories:**
- `BackgroundCollector`, WorkManager, FGS, sensor subscriptions → **Story 2.4**.
- `getChartDailyAggregates()`, `ChartDayAggregate` model, History aggregation → **Story 3.2**.
- CSV import/export, purge, downsampling → **Epic 4**.
- Today dashboard UI, `TodayCubit`, `GoalRing` → **Story 2.5**.
- Dev data inject → **Story 3.1**.
- `isolate_database_factory.dart` refactor → only if required for tests; full isolate spike remains **Story 2.4**.

Do not over-implement. This story establishes the **SQLite write/read boundary and time semantics** — not background collection or UI.

### Pipeline position (Epic 2)

```text
PhonePedometerSource ──┐
                       ├──> StepNormalizer ──> NormalizedStepBucket
AdpBleSource (empty) ──┘                              │
                                                       v
                              StepRepository.upsertIngestionBucket()  ← THIS STORY
                                       │
                                       v
                              timeseries_samples (SQLite)
                                       │
                              getTodaySteps()  ← THIS STORY (LocalDayCalculator)
                                       │
                              (2.5 TodayCubit / GoalRing reads total)
```

Story 2.2 delivers `NormalizedStepBucket`. Story 2.3 persists it and exposes today's total. Story 2.4 connects the live pipeline.

### Architecture contracts (must match exactly)

**Write path (D-03, D-19):**

| Caller (Phase 0) | Method | Notes |
|------------------|--------|-------|
| `BackgroundCollector` only (production) | `upsertIngestionBucket()` | Story 2.4 wires caller |
| Tests | `upsertIngestionBucket()` | Direct calls OK in unit tests |
| UI / Cubits | **read methods only** | No ingestion writes |

**All `timeseries_samples` writes** go through `StepRepository` methods — no direct `db.insert('timeseries_samples', …)` outside the repository.

**Bucket upsert SQL pattern** ([Source: `architecture.md` — Pattern Examples]):

```sql
INSERT INTO timeseries_samples (id, start_time, end_time, type, value, unit, resolution, provider, device_id, zone_offset)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(provider, device_id, type, start_time, end_time, resolution)
DO UPDATE SET value = excluded.value;
```

Critical: on conflict, **update `value` only** — keep the original UUID `id` for import idempotency (D-16).

**LocalDayCalculator** ([Source: `architecture.md` — Structure Patterns]):

```dart
// lib/core/time/local_day_calculator.dart
class LocalDayCalculator {
  static DateTime localDay({
    required DateTime utc,
    required String zoneOffset, // '+02:00' / '-05:00'
  }) { ... }
}
```

- Input `utc` must be `.toUtc()`.
- Apply stored offset to derive local calendar date (date-only semantics for grouping).
- Used by `getTodaySteps()` per row AND for reference "today" from `TimeProvider`.
- **Forbidden:** SQL `date(start_time, zone_offset)` — invalid for ISO offset strings in SQLite.

**getTodaySteps algorithm:**

1. `referenceToday = LocalDayCalculator.localDay(utc: timeProvider.nowUtc(), zoneOffset: formatOffset(timeProvider.currentZoneOffset()))`.
2. Load candidate rows (`type = 'steps'`).
3. For each row: `rowLocalDay = LocalDayCalculator.localDay(utc: parse(row.start_time), zoneOffset: row.zone_offset)`.
4. `sum(row.value)` where `rowLocalDay == referenceToday`.

**TimeProvider (D-25)** — already implemented in Story 2.2:

```dart
abstract class TimeProvider {
  DateTime nowUtc();
  Duration currentZoneOffset();
}
```

- Repository injects `TimeProvider` — **no** `DateTime.now()` inside `StepRepository` or `LocalDayCalculator`.
- `StepNormalizer` already uses injected clock — do not regress.

**Timestamp storage (NFR9):**

| Field | Rule |
|-------|------|
| `start_time`, `end_time` | ISO 8601 UTC with `Z` — e.g. `2026-06-02T08:00:00Z` |
| `zone_offset` | Immutable at ingestion — `+02:00` format (no `Z`) |
| Source on upsert | Copy from `NormalizedStepBucket` — repository does not recompute offset from device clock |

### Current code state

| Path | Current state | What 2.3 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/core/database/migrations.dart` | v2 `timeseries_samples` + unique `idx_bucket_identity` | Read-only reference | Do not bump `kDbVersion` unless constraint bug found |
| `lib/data/models/normalized_step_bucket.dart` | DTO without `id` | Consumed by repository upsert | Do not add UUID here |
| `lib/data/datasources/step_normalizer.dart` | Emits buckets with metadata | Unchanged | Reset/delta logic stays here only |
| `lib/core/di/app_dependencies.dart` | DB, prefs, sources, normalizer | Add `StepRepository` | Existing factories + test hooks |
| `lib/data/repositories/user_preferences_repository.dart` | Sole writer to `user_preferences` | No changes | Separate repository ownership |
| `lib/core/time/time_provider.dart` | Interface + `SystemTimeProvider` | Unchanged API | Normalizer depends on it |
| `test/core/time/fake_time_provider.dart` | Fixed clock for tests | Reuse in today/travel tests | Keep in `test/` only |

`StepRepository`, `LocalDayCalculator`, `TimeseriesSampleModel` **do not exist yet** — create per architecture directory map.

### Recommended file layout

```text
lib/core/time/local_day_calculator.dart              # NEW
lib/core/time/timestamp_codec.dart                   # NEW (optional; or methods on model)
lib/data/models/timeseries_sample_model.dart         # NEW
lib/data/repositories/step_repository.dart           # NEW
lib/core/di/app_dependencies.dart                    # UPDATE

test/core/time/local_day_calculator_test.dart        # NEW — travel scenario mandatory
test/data/repositories/step_repository_upsert_test.dart   # NEW
test/data/repositories/step_repository_today_test.dart    # NEW — travel scenario mandatory
test/core/di/app_dependencies_test.dart              # UPDATE if needed
```

### TimeseriesSampleModel shape (suggested)

Align with Story 2.1 valid row + architecture naming:

```dart
class TimeseriesSampleModel {
  final String id;
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;
  final String type;
  final num value;
  final String unit;
  final String resolution;
  final String provider;
  final String deviceId;
  final String zoneOffset;

  Map<String, Object?> toMap();       // snake_case keys for sqflite
  factory TimeseriesSampleModel.fromMap(Map<String, Object?> map);
  factory TimeseriesSampleModel.fromNormalizedBucket({
    required NormalizedStepBucket bucket,
    required String id,
  });
}
```

Use `int` for step values in Dart when `type == 'steps'`.

### Travel test scenario (minimum — adapt to FakeTimeProvider)

Reference today: `2026-06-02` with device offset `+02:00` (Paris).

| Row | start_time (UTC) | zone_offset | Local day (via calculator) | Count toward today? |
|-----|------------------|-------------|----------------------------|---------------------|
| A | `2026-06-01T22:30:00Z` | `+02:00` | `2026-06-02` | **Yes** (100 steps) |
| B | `2026-06-01T22:30:00Z` | `-05:00` | `2026-06-01` | **No** (50 steps) |
| C | `2026-06-02T10:00:00Z` | `+02:00` | `2026-06-02` | **Yes** (200 steps) |

Expected `getTodaySteps()` = **300** (A + C), not 350.

If `FakeTimeProvider` shifts reference to `2026-06-01` with `-05:00`, row B counts, A does not — proves historical rows use **stored** offset, not device offset retroactively.

### AppDependencies wiring pattern

```dart
// create()
final db = await openAstraDatabase();
final timeProvider = const SystemTimeProvider();
final stepRepository = StepRepository(db: db, clock: timeProvider);
return AppDependencies(
  // ...existing fields...
  stepRepository: stepRepository,
);
```

Share the **same** `Database` instance as `UserPreferencesRepository` — single connection in UI isolate for Phase 0.

### Architecture compliance

| Decision / invariant | Requirement for 2.3 |
|----------------------|---------------------|
| D-03 | `upsertIngestionBucket()` is the ingestion write API; no other ingestion inserts |
| D-16 | Preserve UUID on bucket conflict update |
| D-19 | Upsert respects `idx_bucket_identity` UNIQUE columns |
| D-21 | **Partial** — only `getTodaySteps()` here; `ChartDayAggregate` deferred to 3.2 |
| D-24 | Single-row upsert OK without transaction; batch ingest later uses `db.transaction()` |
| D-25 | Injected `TimeProvider` in repository; no `DateTime.now()` |
| NFR9 | UTC storage + per-row offset grouping via `LocalDayCalculator` |

### Anti-patterns

- Do not add `BackgroundCollector`, WorkManager, or pedometer subscriptions.
- Do not implement `getChartDailyAggregates()` — Story 3.2.
- Do not put delta/reset logic in repository — stays in `StepNormalizer`.
- Do not use SQL `date(start_time, zone_offset)` or device timezone for historical row grouping.
- Do not use `ConflictAlgorithm.replace` for upsert if it replaces `id` on conflict.
- Do not add a `local_day` column to SQLite — compute in Dart only.
- Do not call `upsertIngestionBucket()` from Cubits, widgets, or onboarding.
- Do not use `DateTime.now()` in `StepRepository` or `LocalDayCalculator`.
- Do not add Riverpod, reactive repositories, or global streams.
- Do not bump schema version without Baptiste review and migration tests.

### Previous Story Intelligence (Story 2.2 — review)

- Review-before-commit is **mandatory** per `docs/project-context.md`.
- `NormalizedStepBucket` intentionally has **no `id`** — UUID assigned at persist time in **this story**.
- `StepNormalizer` uses `TimeProvider` for bucket boundaries and `zone_offset` capture at normalization time — repository must **persist** that offset verbatim on upsert.
- Reset test proven: `1000 → 1050 → 200` yields non-negative totals — repository tests are separate (persistence + time semantics).
- `FakeTimeProvider` lives at `test/core/time/fake_time_provider.dart` — reuse for travel tests.
- `AppDependencies.test()` accepts injectable `TimeProvider` — mirror for `StepRepository` tests.
- Story 2.2 explicitly deferred `LocalDayCalculator`, `StepRepository`, SQLite writes — **implement now, do not re-open normalizer** unless persist exposes a bug.
- Full test suite was green after 2.2 review fixes — keep `flutter test` green.

### Git Intelligence Summary

| Commit | Relevance |
|--------|-----------|
| `17197e1` | Latest ingestion fix — respect normalizer review patterns; repository must not duplicate reset logic |
| `24208bb` | DI wiring pattern — extend `AppDependencies` consistently |
| `862a5a5` | Reset handling in normalizer — upsert stores resulting bucket values as-is |
| `f8c28a5` | Phone + ADP sources — upsert preserves `provider`/`device_id` from bucket |
| Story 2.1 commits | Migration tests + CHECK constraints — repository must respect integer steps + non-negative |

### Latest Tech Information

- **sqflite 2.4.2+1** (pub.dev): use `db.rawInsert` / `rawUpdate` for multi-column `ON CONFLICT` upsert if high-level `insert()` cannot express `DO UPDATE SET value = excluded.value` while preserving `id`. Android may require `rawQuery` for PRAGMA — already handled in `app_database.dart`.
- **uuid 4.4.0** (pubspec): `Uuid().v4()` for new row ids on insert.
- **SQLite**: `date()` modifier does not accept ISO `±HH:MM` offset strings — confirms Dart-side `LocalDayCalculator` requirement (architecture NFR9).
- No new pub dependencies expected.

### Project Structure Notes

- Matches architecture `lib/data/repositories/step_repository.dart` and `lib/core/time/local_day_calculator.dart`.
- Tests mirror `lib/` under `test/`.
- Story file location: `_bmad-output/implementation-artifacts/stories/2-3-step-repository-and-time-semantics.md`.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 2.3, NFR9]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — §1.3 Time Semantics]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-03, D-19, D-21, D-25, LocalDayCalculator, write path table, upsert SQL example]
- [Source: `_bmad-output/implementation-artifacts/stories/2-2-data-ingestion-abstraction-and-step-normalizer.md` — deferrals, NormalizedStepBucket shape]
- [Source: `_bmad-output/implementation-artifacts/stories/2-1-sqlite-schema-for-timeseries-samples.md` — DDL, CHECK constraints, bucket identity index]
- [Source: `docs/project-context.md` — review-before-commit workflow]
- [Source: `lib/core/database/migrations.dart` — `timeseries_samples` columns]
- [Source: `lib/data/models/normalized_step_bucket.dart` — upsert input DTO]
- [Source: `lib/data/repositories/user_preferences_repository.dart` — repository pattern reference]

## Dev Agent Record

### Agent Model Used

GPT-5.5

### Debug Log References

- 2026-06-02: `python3 _bmad/scripts/resolve_customization.py --skill .agents/skills/bmad-dev-story --key workflow` failed because `python3` is unavailable in PowerShell; customization was resolved manually per workflow fallback.
- 2026-06-02: RED phase confirmed by failing targeted tests due to missing `LocalDayCalculator`, `TimestampCodec`, `TimeseriesSampleModel`, `StepRepository`, and DI signature.
- 2026-06-02: GREEN phase targeted tests passed after implementation.
- 2026-06-02: Guardrail search found no `DateTime.now()` in `lib/data` and no SQL `date(start_time, zone_offset)` usage.
- 2026-06-02: `flutter analyze` passed with no issues.
- 2026-06-02: `flutter test test/core/time/local_day_calculator_test.dart test/data/repositories/` passed.
- 2026-06-02: Full `flutter test` passed.

### Completion Notes List

- Implemented `LocalDayCalculator` for UTC instant + immutable `zone_offset` local-day grouping, including travel and DST-offset tests.
- Added UTC timestamp codec and `TimeseriesSampleModel` aligned with the `timeseries_samples` schema, keeping storage timestamps in `Z` form.
- Added `StepRepository.upsertIngestionBucket()` with UUID-on-insert and bucket-identity upsert that updates `value` only, preserving the existing `id`.
- Added `StepRepository.getTodaySteps()` that computes the reference day from injected `TimeProvider` and groups each row using that row's stored offset.
- Wired `StepRepository` into `AppDependencies.create()` and `.test()` using the shared database handle and same clock as `StepNormalizer`.
- Travel test in plain language: the same UTC evening bucket can be "today" in Paris (`+02:00`) and "yesterday" in New York (`-05:00`), so `getTodaySteps()` counts only rows whose stored offset maps them to the user's current local day.

### File List

- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/stories/2-3-step-repository-and-time-semantics.md`
- `lib/core/di/app_dependencies.dart`
- `lib/core/time/local_day_calculator.dart`
- `lib/core/time/timestamp_codec.dart`
- `lib/data/models/timeseries_sample_model.dart`
- `lib/data/repositories/step_repository.dart`
- `test/core/di/app_dependencies_test.dart`
- `test/core/time/local_day_calculator_test.dart`
- `test/data/models/timeseries_sample_model_test.dart`
- `test/data/repositories/step_repository_today_test.dart`
- `test/data/repositories/step_repository_upsert_test.dart`
- `test/presentation/onboarding/onboarding_flow_test.dart`
- `test/widget_test.dart`

### Change Log

- 2026-06-02: Implemented Story 2.3 repository/time semantics, tests, DI wiring, and verification.

## Story Completion Status

- Status: **review**
- Ultimate context engine analysis completed - comprehensive developer guide created
