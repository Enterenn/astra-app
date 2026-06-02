# Story 2.2: Data Ingestion Abstraction and Step Normalizer

Status: in-progress

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **builder**,
I want a pluggable ingestion pipeline with step normalization,
So that phone (and future ADP) sources can feed buckets without duplicating delta logic.

## Acceptance Criteria

1. **Given** `DataIngestionSource` interface exists
   **When** `PhonePedometerSource` and no-op `AdpBleSource` stub are registered in `AppDependencies`
   **Then** both implement the interface and stub returns no data (FR1, FR3)

2. **Given** cumulative pedometer readings including a simulated counter reset
   **When** `StepNormalizer` processes the stream
   **Then** correct non-negative bucket increments are produced without corrupted totals (FR2)
   **And** unit test covers at least one reset/reboot scenario

3. **Given** normalized bucket output
   **When** persisted later by BackgroundCollector
   **Then** samples include `type=steps`, `unit=count`, `provider=internal_phone`, `device_id=smartphone`

## Tasks / Subtasks

- [x] **Sub-task A — Core models and ingestion contract** (AC: #1)
  - [x] Add `lib/data/models/step_reading.dart` — raw platform reading (`cumulativeSteps`, `observedAtUtc`).
  - [x] Add `lib/data/models/normalized_step_bucket.dart` — storage-ready bucket **without** `id` (UUID assigned at persist time in Story 2.3/2.4).
  - [x] Add `lib/data/datasources/data_ingestion_source.dart` — architecture contract with `providerId`, `deviceId`, `watchStepReadings()`.
  - [x] Add provider/device constants (e.g. `kInternalPhoneProvider`, `kSmartphoneDeviceId`, `kAstraWearableProvider` for ADP stub).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — TimeProvider (normalizer clock only)** (AC: #2, supports D-25)
  - [x] Add `lib/core/time/time_provider.dart` — `nowUtc()`, `currentZoneOffset()` per architecture.
  - [x] Add `lib/core/time/system_time_provider.dart` — production implementation.
  - [x] Add `test/core/time/fake_time_provider.dart` — fixed clock for deterministic normalizer tests.
  - [x] **Do not** add `LocalDayCalculator` or repository time semantics — Story 2.3.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Data sources** (AC: #1, #3 metadata)
  - [x] Add `lib/data/datasources/phone_pedometer_source.dart` — maps `Pedometer.stepCountStream` `StepCount` → `StepReading`; `providerId=internal_phone`, `deviceId=smartphone`.
  - [x] Inject a testable pedometer stream factory (constructor param or typedef) so unit tests never touch real sensors.
  - [x] Add `lib/data/datasources/adp_ble_source.dart` — implements interface; `watchStepReadings()` returns empty stream; document Phase 1 ADP activation in class dartdoc.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task D — StepNormalizer + unit tests** (AC: #2, #3 field shapes)
  - [x] Add `lib/data/datasources/step_normalizer.dart` — **only** place that converts cumulative readings → 5-minute bucket increments.
  - [x] Inject `TimeProvider`; **no** `DateTime.now()` in normalizer.
  - [x] Handle: first reading baseline, positive deltas, counter reset/reboot (`cumulative < lastBaseline` → re-baseline, non-negative increment), negative delta rejection, integer-only step values.
  - [x] Emit `NormalizedStepBucket` with: `type=steps`, `unit=count`, `resolution=5min`, ISO 8601 UTC `start_time`/`end_time`, immutable `zone_offset` from `TimeProvider`, `provider`/`device_id` from source.
  - [x] Align 5-minute windows to UTC boundaries derived from `TimeProvider.nowUtc()` (document alignment rule in code comment if non-obvious).
  - [x] Add `test/data/datasources/step_normalizer_test.dart` — **mandatory** reset/reboot scenario plus at least one happy-path multi-reading sequence.
  - [x] Add `test/data/datasources/adp_ble_source_test.dart` — stub emits no events.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task E — AppDependencies wiring** (AC: #1)
  - [ ] Extend `lib/core/di/app_dependencies.dart` — expose `TimeProvider`, `List<DataIngestionSource> ingestionSources` (phone + ADP stub), `StepNormalizer`.
  - [ ] Wire in `create()` and `test()`; pass `FakeTimeProvider` in `test()` when needed.
  - [ ] **Do not** start `watchStepReadings()` subscriptions, `BackgroundCollector`, or WorkManager at app launch.
  - [ ] Update existing tests only if constructor signatures require `deps` fields (keep changes minimal).
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task F — Verification** (AC: #1–#3)
  - [ ] Run `flutter analyze`.
  - [ ] Run `flutter test test/data/datasources/` (and any touched core/time tests).
  - [ ] Run full `flutter test`.
  - [ ] Review brief must explain reset test scenario in plain language.
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 2.2:**
- `DataIngestionSource` interface and `StepReading` model.
- `PhonePedometerSource` (pedometer stream adapter) and `AdpBleSource` no-op stub.
- `StepNormalizer` — cumulative sensor → 5-minute bucket deltas (FR1–2).
- `TimeProvider` + `SystemTimeProvider` + `FakeTimeProvider` for normalizer/tests (D-25 partial — repository usage in 2.3).
- `NormalizedStepBucket` model shaped for later `timeseries_samples` insert.
- `AppDependencies` registration of sources + normalizer (no runtime collection).
- Unit tests including **at least one counter reset/reboot** scenario.

**Out of scope — defer to later stories:**
- `StepRepository`, `upsertIngestionBucket()`, SQLite writes → **Story 2.3**.
- `LocalDayCalculator`, `getTodaySteps()`, travel/timezone read semantics → **Story 2.3**.
- `TimeseriesSampleModel` (full DB map) if not required for bucket DTO — prefer minimal `NormalizedStepBucket` now; repository model in 2.3.
- `BackgroundCollector`, WorkManager callback, FGS manifest, 24h background acceptance → **Story 2.4**.
- Android `ACTIVITY_RECOGNITION` manifest wiring and permission-gated stream start → **Story 2.4** (onboarding already requests permission in 1.5; do not auto-start sensor here).
- Today dashboard, Cubits, UI → **Story 2.5+**.
- Dev data inject → **Epic 3**.

Do not over-implement. This story establishes the ingestion **abstraction and normalization math** only — no persistence.

### Pipeline position (Epic 2)

```text
PhonePedometerSource ──┐
                       ├──> StepNormalizer ──> NormalizedStepBucket[] ──> (2.4 BackgroundCollector)
AdpBleSource (empty) ──┘                              │
                                                       └──> (2.3 StepRepository.upsertIngestionBucket)
```

Story 2.2 completes the box through `NormalizedStepBucket`. Nothing writes to SQLite yet.

### Architecture contracts (must match exactly)

**DataIngestionSource** ([Source: `architecture.md` — Implementation Patterns]):

```dart
abstract class DataIngestionSource {
  String get providerId;
  String get deviceId;
  Stream<StepReading> watchStepReadings();
}
```

- Sources emit **raw cumulative** readings only — never `TimeseriesSampleModel` or DB rows.
- `providerId` / `deviceId` are source metadata; normalizer copies them onto each bucket.

**Phone metadata (FR2 / AC #3):**

| Field | Value |
|-------|--------|
| `provider` | `internal_phone` |
| `device_id` | `smartphone` |
| `type` | `steps` |
| `unit` | `count` |
| `resolution` | `5min` |

**ADP stub (FR3):**

| Field | Suggested value |
|-------|-----------------|
| `providerId` | `astra_wearable_v1` (per PRD addendum) |
| `deviceId` | e.g. `astra_wearable_v1` or documented placeholder |
| Stream | Always empty Phase 0 |

**TimeProvider (D-25)** — required for `StepNormalizer` bucket boundaries:

```dart
abstract class TimeProvider {
  DateTime nowUtc();
  Duration currentZoneOffset();
}
```

- Format `zone_offset` as immutable `'+02:00'` / `'-05:00'` string (no `Z` in offset field).
- Format stored timestamps as ISO 8601 UTC with `Z` suffix when converting `DateTime` → string in bucket model helpers.

**StepNormalizer responsibilities (D-20):**

| Scenario | Expected behavior |
|----------|-------------------|
| First reading | Establish baseline; no bucket or zero increment until second reading proves movement |
| Normal delta | `increment = max(0, current - baseline)`; accumulate into active 5-min window |
| Counter reset / reboot | If `current < baseline`, set `baseline = current`, `increment = current` (non-negative; no corrupted negative totals) |
| Negative delta without reset semantics | Reject (treat as 0 increment) |
| Window rollover | Close prior 5-min bucket(s), start new bucket at next boundary |
| Output values | Non-negative integers for `type=steps` |

**Reset test scenario (minimum — adapt timestamps to `FakeTimeProvider`):**

```text
T0: cumulative=1000  → baseline 1000, no increment yet
T1: cumulative=1050  → +50 into current 5-min bucket
T2: cumulative=200   → reset detected → +200 into bucket (not -850)
```

Assert bucket `value` sums are non-negative and reflect 50 + 200 (within same window) or split across windows per alignment rule.

### Current code state

| Path | Current state | What 2.2 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/core/di/app_dependencies.dart` | DB + `UserPreferencesRepository` + theme/onboarding bootstrap | Add `TimeProvider`, ingestion sources list, `StepNormalizer` | Existing `create()` / `test()` async prefs loading |
| `lib/core/database/migrations.dart` | v2 `timeseries_samples` schema done (Story 2.1) | Read-only reference for bucket field names | Do not change schema version |
| `lib/data/repositories/user_preferences_repository.dart` | Preferences only | No changes unless test breakage | Single writer to `user_preferences` |
| `lib/main.dart` / `lib/app.dart` | Pass `deps` to app shell | Avoid starting collectors | Onboarding gate unchanged |
| `pubspec.yaml` | `pedometer: ^4.2.0` already declared | No new packages expected | Locked dependency set |

`lib/data/datasources/` and `lib/core/time/` **do not exist yet** — create per architecture directory map.

### Recommended file layout

```text
lib/core/time/time_provider.dart
lib/core/time/system_time_provider.dart
lib/data/models/step_reading.dart
lib/data/models/normalized_step_bucket.dart
lib/data/datasources/data_ingestion_source.dart
lib/data/datasources/phone_pedometer_source.dart
lib/data/datasources/adp_ble_source.dart
lib/data/datasources/step_normalizer.dart
lib/core/di/app_dependencies.dart                    # UPDATE

test/core/time/fake_time_provider.dart
test/data/datasources/step_normalizer_test.dart
test/data/datasources/adp_ble_source_test.dart
test/data/datasources/phone_pedometer_source_test.dart  # optional if stream factory tested
```

### NormalizedStepBucket shape (suggested)

Fields aligned with `timeseries_samples` ([Source: Story 2.1 DDL]) minus `id`:

```dart
class NormalizedStepBucket {
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;
  final String type;       // 'steps'
  final int value;         // bucket increment (whole count)
  final String unit;       // 'count'
  final String resolution; // '5min'
  final String provider;
  final String deviceId;
  final String zoneOffset;
}
```

Add `toInsertMap()` or similar **only if** it helps 2.3 — keep free of UUID generation here (BackgroundCollector/repository owns `id`).

### PhonePedometerSource implementation notes

- Package: `pedometer ^4.2.0` — `Pedometer.stepCountStream` yields `StepCount` with `steps` (cumulative since boot) and `timeStamp`.
- Map `StepCount.steps` → `StepReading.cumulativeSteps`, `StepCount.timeStamp` → `observedAtUtc` (normalize to UTC).
- Handle stream errors per plugin docs (`onError`); do not crash app — surface via stream error or logged debug (no analytics SDK).
- **Testability:** accept `Stream<StepCount> Function()` or inject mock stream; widget tests must not require physical sensor.

### AppDependencies wiring pattern

```dart
// create()
final clock = SystemTimeProvider();
final ingestionSources = <DataIngestionSource>[
  PhonePedometerSource(...),
  AdpBleSource(),
];
final stepNormalizer = StepNormalizer(clock: clock);
```

Expose getters on `AppDependencies` for later `BackgroundCollector` (Story 2.4). Do **not** instantiate `BackgroundCollector` in this story.

### Architecture compliance

| Decision / invariant | Requirement for 2.2 |
|----------------------|---------------------|
| D-03 | No SQLite ingestion writes; no `StepRepository` |
| D-05 | `PhonePedometerSource` uses `pedometer` package only |
| D-20 | All delta/reset logic lives in `StepNormalizer` only |
| D-25 | `TimeProvider` in normalizer; no raw `DateTime.now()` there |
| FR1 | Interface + phone + ADP stub |
| FR2 | Reset handling + unit test |
| FR3 | ADP stub wired in DI, empty stream |
| NFR (testing) | Deterministic normalizer tests via `FakeTimeProvider` |

### Anti-patterns

- Do not write to `timeseries_samples` or open ingestion upsert paths.
- Do not put delta/reset logic in `PhonePedometerSource`, repository, Cubit, or UI.
- Do not emit `TimeseriesSampleModel` from sources.
- Do not start `BackgroundCollector`, WorkManager, or FGS.
- Do not auto-subscribe to pedometer stream in `main()` — wiring only.
- Do not use `DateTime.now()` inside `StepNormalizer`.
- Do not compute `local_day` or use SQL date functions.
- Do not add Riverpod, global streams for app state, or reactive repositories.
- Do not add new pub dependencies without updating `docs/DEPENDENCIES.md`.
- Do not store raw `StepCount` events in SQLite.

### Previous Story Intelligence (Story 2.1 — done)

- Review-before-commit is **mandatory** per `docs/project-context.md`: one sub-task → review brief → Baptiste OK → commit.
- Migration v2 schema is live: `timeseries_samples` with `CHECK` for non-negative and integer `steps`, unique `idx_bucket_identity`.
- Test suite was **57 tests** green after 2.1; keep full suite green.
- `openAstraDatabase()` behavior unchanged — WAL + foreign keys in `onConfigure`.
- Story 2.1 explicitly deferred ingestion pipeline to **this story** — do not re-open schema unless a normalizer test proves a constraint bug.

### Git Intelligence Summary

| Commit | Relevance |
|--------|-----------|
| `56766d6` | Latest DB hardening (non-null `id`, numeric `value`, DESC index) — bucket model must respect integer steps |
| `5c52e32` | Migration v2 landed — align `NormalizedStepBucket` fields with DDL |
| `69c44a6` / `55c86d9` | Migration test patterns — mirror focused unit test style in `test/data/datasources/` |
| `d478120` / onboarding commits | Preserve onboarding gate; avoid unrelated UI edits |

### Latest Tech Information

- **pedometer 4.2.0** (pub.dev): `stepCountStream` reports steps **cumulative since last system boot**; resets on reboot; Android steps before install not counted. This is why `StepNormalizer` reset handling is mandatory, not optional.
- **sqflite 2.4.2+1**: unchanged; not used in this story.
- No new packages required if `pedometer` and `uuid` (for later id generation) already suffice.

### Project Structure Notes

- Matches architecture `lib/data/datasources/` and `lib/core/time/` layout.
- Tests mirror `lib/` under `test/`.
- `FakeTimeProvider` may live under `test/core/time/` (test-only) per Story 1.4 test helper patterns.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 2.2, FR1–FR3, FR8]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — §4.1 Ingestion, §4.3.1 Canonical Sample Shape]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-20, D-25, DataIngestionSource contract, StepNormalizer boundary table]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md` — provider/device examples]
- [Source: `_bmad-output/implementation-artifacts/stories/2-1-sqlite-schema-for-timeseries-samples.md` — schema deferrals and DDL]
- [Source: `docs/project-context.md` — review-before-commit workflow]
- [Source: `lib/core/di/app_dependencies.dart` — current DI shape]
- [Source: `lib/core/database/migrations.dart` — `timeseries_samples` columns]
- [Source: pub.dev/pedometer — cumulative since boot semantics](https://pub.dev/packages/pedometer)

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References
- 2026-06-02 — Sub-task A red phase: `flutter test test/data/datasources/data_ingestion_source_test.dart` failed on missing ingestion contract/model files.
- 2026-06-02 — Sub-task A green/refactor validation: `dart format ...`, `flutter analyze`, `flutter test test/data/datasources/data_ingestion_source_test.dart`, and full `flutter test` all passed.
- 2026-06-02 — Sub-task B red phase: `flutter test test/core/time/time_provider_test.dart` failed on missing time provider files.
- 2026-06-02 — Sub-task B validation: `dart format ...`, `flutter analyze`, `flutter test test/core/time/time_provider_test.dart`, and full `flutter test` all passed.
- 2026-06-02 — Sub-task C red phase: `flutter test test/data/datasources/adp_ble_source_test.dart test/data/datasources/phone_pedometer_source_test.dart` failed on missing data source files.
- 2026-06-02 — Sub-task C validation: `dart format ...`, `flutter analyze`, `flutter test test/data/datasources/`, and full `flutter test` all passed.
- 2026-06-02 — Sub-task D red phase: `flutter test test/data/datasources/step_normalizer_test.dart` failed on missing `StepNormalizer`.
- 2026-06-02 — Sub-task D validation: `dart format ...`, `flutter analyze`, `flutter test test/data/datasources/`, `flutter test test/core/time/`, and full `flutter test` all passed.

### Completion Notes List
- Sub-task A implementation is ready for review: added raw step readings, normalized bucket DTO without persistence `id`, ingestion source interface, and provider/device/sample constants.
- Added focused contract tests for UTC reading normalization, storage-ready bucket shape, and `DataIngestionSource` stream metadata.
- Sub-task A review/commit gate completed with commit `f428b8a`.
- Sub-task B implementation is ready for review: added `TimeProvider`, `SystemTimeProvider`, and deterministic `FakeTimeProvider` for upcoming normalizer tests.
- Confirmed no `LocalDayCalculator`, repository time semantics, persistence, or background collection were introduced.
- Sub-task B review/commit gate completed after Baptiste approval.
- Sub-task C implementation is ready for review: added `PhonePedometerSource` with injectable phone event stream factory and `AdpBleSource` Phase 0 no-op stub.
- Phone source maps pedometer step events to raw cumulative `StepReading` values with phone metadata; ADP source emits no events.
- Sub-task C review/commit gate completed after Baptiste approval.
- Sub-task D implementation is ready for review: added `StepNormalizer` to convert cumulative readings into non-negative 5-minute `NormalizedStepBucket` increments.
- Reset/reboot scenario covered: `1000 → 1050 → 200` yields `250` total in the bucket, never a negative delta.
- Sub-task D review/commit gate completed after Baptiste approval.

### File List
- `lib/core/time/system_time_provider.dart`
- `lib/core/time/time_provider.dart`
- `lib/data/datasources/adp_ble_source.dart`
- `lib/data/datasources/data_ingestion_source.dart`
- `lib/data/datasources/phone_pedometer_source.dart`
- `lib/data/datasources/step_normalizer.dart`
- `lib/data/models/normalized_step_bucket.dart`
- `lib/data/models/step_reading.dart`
- `test/core/time/fake_time_provider.dart`
- `test/core/time/time_provider_test.dart`
- `test/data/datasources/adp_ble_source_test.dart`
- `test/data/datasources/data_ingestion_source_test.dart`
- `test/data/datasources/phone_pedometer_source_test.dart`
- `test/data/datasources/step_normalizer_test.dart`

### Change Log
- 2026-06-02 — Added Sub-task A core ingestion contract artifacts and tests; story moved to in-progress.
- 2026-06-02 — Added Sub-task B time provider abstraction, system clock, fake clock, and tests.
- 2026-06-02 — Added Sub-task C phone pedometer source, ADP no-op source, and datasource tests.
- 2026-06-02 — Added Sub-task D step normalizer with reset/reboot handling and metadata tests.

## Story Completion Status

- Status: **in-progress**
- Ultimate context engine analysis completed - comprehensive developer guide created
- Sprint status marks `2-2-data-ingestion-abstraction-and-step-normalizer` as `in-progress`.
- Critical guardrail: normalization and interfaces only — no SQLite persistence or background collection.
