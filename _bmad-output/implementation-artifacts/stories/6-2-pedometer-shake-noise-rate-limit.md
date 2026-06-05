# Story 6.2: Pedometer Shake Noise Rate Limit

Status: review

<!-- Baptiste 2026-06-05: Nord 4 / Snapdragon Step Counter credits phone shakes as steps. -->
<!-- Design review: reject event-drop filter in PhonePedometerSource; rate-limit credited delta in StepIncrementCalculator. -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want step counts to ignore rapid phantom increments from shaking my phone,
So that Today and History reflect real walking activity instead of OEM sensor noise.

## Acceptance Criteria

1. **Given** Android `TYPE_STEP_COUNTER` delivers cumulative readings via `Pedometer.stepCountStream`
   **When** a burst of phantom steps appears (e.g. shaking the phone on OnePlus Nord 4 / Snapdragon OEMs)
   **Then** credited increments are **rate-limited** to a physiologically plausible maximum
   **And** the hardware baseline always advances to the latest cumulative counter (phantom steps are discarded, not deferred)

2. **Given** `StepIncrementCalculator.calculate()` is the shared increment math for live display and bucket normalization
   **When** rate limiting is applied
   **Then** both `LiveStepMonitor._applyReadingToDelta` and `StepNormalizer.normalizeReadings` use the same logic
   **And** no duplicate rate-limit implementation exists in `PhonePedometerSource` or repository layers

3. **Given** consecutive readings with `current > baseline`
   **When** elapsed time between readings is known
   **Then** `creditedDelta = min(rawDelta, max(1, ceil(maxStepsPerSecond × elapsedMs / 1000)))`
   **And** `maxStepsPerSecond` defaults to **5** (sprint margin above ~4 steps/s human max)
   **And** `baseline` is updated to `current` after each processed reading (even when `creditedDelta < rawDelta`)

4. **Given** existing reboot / counter-reset semantics (FR-2)
   **When** `current < baseline` and `current <= baseline ~/ 2`
   **Then** reset handling is unchanged — return `current` as increment, no rate cap on that path
   **And** small negative drops still return `null` (sensor noise)

5. **Given** first reading after baseline initialization
   **When** `baseline == null` or reading establishes baseline only
   **Then** behavior unchanged — no increment credited on baseline seed

6. **Given** normal walking or moderate running within ~5 steps/s average between delivered events
   **When** rate limiter runs
   **Then** full deltas are credited (no undercount in typical use)

7. **Given** `pedometer` package timestamps (`StepCount.timeStamp = DateTime.now()` at Dart receipt)
   **When** elapsed time is computed
   **Then** use `observedAtUtc` delta between consecutive processed readings (inter-arrival time)
   **And** document in code comment that this is delivery latency, not hardware step time — acceptable for burst detection

8. **Given** unit tests in `test/data/datasources/step_increment_calculator_test.dart`
   **When** run
   **Then** cover at minimum:
   - shake burst: +50 steps in 200 ms → credits ≤ 1–2 steps, baseline advances to hardware value
   - normal walk: +5 steps in 1 s → credits 5
   - fast run: +8 steps in 1 s with limit 5 → credits 5
   - long gap then large delta: documents accepted behavior (may credit full delta if gap large enough)
   - reboot reset path unchanged
   - small negative drop still null

9. **Given** integration tests for `StepNormalizer` and `LiveStepMonitor`
   **When** fed synthetic reading sequences with timestamps
   **Then** at least one test per consumer verifies shake burst does not inflate bucket totals or live `_pendingDelta` by the full hardware jump

10. **Given** implementation complete
    **When** `flutter analyze` and `flutter test` run
    **Then** no regressions in `step_normalizer_test.dart`, `live_step_monitor_test.dart`, `background_collector_test.dart`

**Depends on:** Story 6.1 (derived metrics consume bucket totals — phantom steps inflate km/kcal indirectly).  
**Out of scope:** Switching to `TYPE_STEP_DETECTOR`; accelerometer shake gate; forking `pedometer` plugin; per-OEM tuning UI; retroactive SQLite correction of already-ingested phantom buckets.

---

## Design Review — LOCKED (2026-06-05)

### Problem

| Layer | Behavior |
|-------|----------|
| Android sensor | `TYPE_STEP_COUNTER` — cumulative since boot, OEM filtering varies |
| Nord 4 / Snapdragon | Rapid shakes increment counter without real locomotion |
| `pedometer` plugin | Exposes counter only; `timeStamp` = `DateTime.now()` on receipt |

### Rejected approach — drop events in `PhonePedometerSource`

Ignoring stream events **does not remove** phantom steps from the hardware counter. The next accepted event credits the full accumulated delta. This only delays UI spikes, not final totals.

### Locked approach — rate-limit **credited** delta

```
rawDelta     = current - baseline          (when current >= baseline)
maxDelta     = max(1, ceil(maxStepsPerSecond × elapsedMs / 1000))
creditedDelta = min(rawDelta, maxDelta)
baseline     = current                      // always sync to hardware
```

Excess steps are permanently discarded — compatible with cumulative counter semantics.

### Placement

| Location | Verdict |
|----------|---------|
| `StepIncrementCalculator` | ✅ **Implement here** — shared by live + normalize paths |
| `PhonePedometerSource` | ❌ Do not filter/drop events |
| `StepRepository` / `TodayCubit` | ❌ Too late — no inter-reading context |
| SQLite post-processing | ❌ Cannot recover temporal burst context |

### Pipeline coverage

```
Pedometer.stepCountStream
  → PhonePedometerSource (unchanged passthrough)
  → LiveStepMonitor._applyReadingToDelta  ─┐
  → StepNormalizer.normalizeReadings       ─┤ StepIncrementCalculator (rate limit)
  → BackgroundCollector → SQLite           ┘
  → MonitorDrainSource (drains LiveStepMonitor buffer — inherits fix)
```

### Known limitation (document, do not block ship)

If a **single** hardware event arrives after a **long** silence (minutes+), a large phantom delta may be fully credited because elapsed time exceeds the cap. Field observation suggests shakes produce **bursts** with short inter-arrival — primary target. Revisit with accelerometer gate only if field test fails.

### Constants — LOCKED

| Constant | Value | Rationale |
|----------|------:|-----------|
| `kMaxStepsPerSecond` | **5** | Human sprint ~4/s + margin; tunable single constant |

---

## Tasks / Subtasks

- [x] **A — Extend `StepIncrementCalculator`** (AC: #1–#5, #8)
  - [x] Add `kMaxStepsPerSecond = 5` constant
  - [x] Extend `calculate()` signature with `Duration? elapsedSincePrevious` (or `int? elapsedMs`)
  - [x] Implement rate-limited credit path; preserve reset + noise paths unchanged
  - [x] Header comment: cumulative counter semantics + `pedometer` timestamp caveat
  - [x] Unit tests for all AC #8 scenarios
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **B — Wire `StepNormalizer`** (AC: #2, #9)
  - [x] Track `previousObservedAtUtc` across reading loop in `normalizeReadings`
  - [x] Pass elapsed duration into `incrementCalculator.calculate()`
  - [x] Add/update test: burst sequence does not write full phantom total to buckets
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **C — Wire `LiveStepMonitor`** (AC: #2, #9)
  - [x] Track last processed `observedAtUtc` in monitor state
  - [x] Pass elapsed into `incrementCalculator.calculate()` in `_applyReadingToDelta`
  - [x] Ensure `_flushBufferedReadingsToDelta` processes readings in order with correct elapsed
  - [x] Add/update `live_step_monitor_test.dart` burst case
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **D — Verification** (AC: #10)
  - [x] `flutter analyze` + `flutter test`
  - [x] Manual on Nord 4 (or equivalent): shake phone 10 s → step count should not jump by tens; walk 50 steps → count increases normally
  - [x] **Stop → review brief → Baptiste OK → commit**

---

## Dev Notes

### Architecture compliance

- Rate-limit belongs in increment math, not repository or UI [Source: `_bmad-output/planning-artifacts/architecture.md` — D-20 StepNormalizer, anti-patterns §695]
- `PhonePedometerSource` remains thin passthrough — no delta logic in datasource beyond mapping [Source: FR-2, architecture D-20]
- `LiveStepMonitor` never writes buckets; fix must credit correct `_pendingDelta` for Today truth model [Source: Story 2.9]
- No new packages — pure Dart math only [Source: architecture locked dependencies]

### Files to update

| File | Change |
|------|--------|
| `lib/data/datasources/step_increment_calculator.dart` | Rate-limited `calculate()` |
| `lib/data/datasources/step_normalizer.dart` | Pass elapsed between readings |
| `lib/core/services/live_step_monitor.dart` | Pass elapsed in `_applyReadingToDelta` / flush |
| `test/data/datasources/step_increment_calculator_test.dart` | Burst, walk, run, reset cases |
| `test/data/datasources/step_normalizer_test.dart` | Burst sequence → capped bucket value |
| `test/core/services/live_step_monitor_test.dart` | Burst → capped `_pendingDelta` |

### Files to NOT change

| File | Reason |
|------|--------|
| `lib/data/datasources/phone_pedometer_source.dart` | Event-drop filter rejected — passthrough only |
| `lib/data/repositories/step_repository.dart` | No increment logic per architecture |
| `lib/presentation/cubits/today_cubit.dart` | Consumes totals downstream |
| Native Kotlin / `pedometer` fork | Out of scope |

### Current code state (read before editing)

**`StepIncrementCalculator`** — today only handles positive delta, small-drop null, reboot return `current`:

```9:20:lib/data/datasources/step_increment_calculator.dart
  int? calculate({required int current, required int baseline}) {
    if (current >= baseline) {
      return current - baseline;
    }
    // reset + noise paths...
  }
```

**`StepNormalizer`** — loops readings, calls `calculate(current:, baseline:)` without elapsed:

```64:67:lib/data/datasources/step_normalizer.dart
      final increment = incrementCalculator.calculate(
        current: cumulativeSteps,
        baseline: baseline,
      );
```

**`LiveStepMonitor`** — same call in `_applyReadingToDelta`; buffers all readings for `MonitorDrainSource` / `BackgroundCollector`.

**`pedometer` `StepCount`** — timestamp is receipt time:

```dart
// package:pedometer — StepCount._(e)
_steps = e as int;
_timeStamp = DateTime.now();
```

### API sketch (guidance, not prescriptive)

```dart
int? calculate({
  required int current,
  required int baseline,
  Duration? elapsedSincePrevious,
});
```

- `elapsedSincePrevious == null` on first increment after baseline seed → treat as no cap (or `Duration.zero` → `maxDelta = 1`; **prefer null = no rate cap** for first delta only to avoid undercount on app resume)
- After first credited reading, always pass elapsed

**Resume edge case:** When `LiveStepMonitor` restarts, first post-baseline reading may have large elapsed since last persisted event — full delta credit is intentional (real steps while app was backgrounded).

### Do NOT

- Drop/ignore events in `PhonePedometerSource` (defers phantom steps, does not discard)
- Cap by dropping events without advancing baseline to `current`
- Add accelerometer dependency in this story
- Change `kMaxStepsPerSecond` per OEM manufacturer
- Rewrite already-persisted SQLite buckets (forward-only fix)
- Break reboot reset test in `step_normalizer_test.dart` ("handles counter reset without producing negative totals")

### Previous story intelligence

- **6.1:** Derived km/kcal/duration flow from bucket totals — phantom 5-min buckets inflate walking time and kcal [Source: `derived_activity_metrics.dart` — threshold 40 steps/bucket]
- **2.9:** Today monotonic display — live `_pendingDelta` feeds ring; incorrect burst credit visible immediately
- **2.10:** OEM deferral documented — Nord-class devices are primary field target; no separate OEM code path needed
- **Investigation audit:** UI isolate uses `MonitorDrainSource`; FGS/WM may use `PhonePedometerSource` directly — both paths converge through `StepNormalizer` or `LiveStepMonitor` calculator calls

### Testing standards

- Inject synthetic `StepReading` sequences with explicit `observedAtUtc` — do not call real `Pedometer` in unit tests
- Reuse patterns from `step_normalizer_test.dart` and `live_step_monitor_test.dart` fake stream factories
- `background_collector_test.dart` should remain green without modification unless calculator signature change breaks call sites

### Manual test protocol (Nord 4)

1. Fresh app open, note step count on Today
2. Shake phone vigorously 10 s — expect **0–3** step increase (not 20+)
3. Walk ~50 steps at normal pace — expect **~50** increase (± rate-limit margin)
4. Optional: light jog 30 s — verify no severe undercount vs health app reference

### References

- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-20 StepNormalizer, data flow, anti-patterns]
- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 6, FR-2 counter reset handling]
- [Source: `lib/data/datasources/phone_pedometer_source.dart` — stream entry point]
- [Source: `lib/data/datasources/step_increment_calculator.dart` — shared increment math]
- [Source: `lib/data/datasources/step_normalizer.dart` — bucket normalization]
- [Source: `lib/core/services/live_step_monitor.dart` — live overlay owner]
- [Source: `package:pedometer` — `TYPE_STEP_COUNTER`, `DateTime.now()` timestamp]
- [Source: Story 6.1 — downstream metric impact of bucket noise]

---

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Nord 4 field A/B: rate-limit ON/OFF both +23 steps in 10 s shake — OEM drip ~2.3 steps/s, under 5/s cap; inter-arrival limit insufficient for this pattern.
- Kill/reopen: 2063 live → 2052 SQLite (−11) — unpersisted `pendingDelta`; motivates story 6.3 (idle flush, universal).

### Completion Notes List

- Task A: `StepIncrementCalculator` rate-limit with `kMaxStepsPerSecond = 5`, `elapsedSincePrevious`, unit tests (9 cases).
- Task B: `StepNormalizer` passes inter-arrival elapsed; burst bucket test.
- Task C: `LiveStepMonitor` `_lastProcessedObservedAtUtc`; live burst test.
- Task D: regression fixes in `today_cubit_test.dart`; `STEP_RATE_LIMIT_ENABLED` dart-define for field A/B; AC #10 automated suites green. Manual shake AC partially met (burst capped in unit tests; Nord drip shake +20–23 remains — see 6.3/optional follow-up).

### File List

- `lib/data/datasources/step_increment_calculator.dart`
- `lib/data/datasources/step_normalizer.dart`
- `lib/core/services/live_step_monitor.dart`
- `test/data/datasources/step_increment_calculator_test.dart`
- `test/data/datasources/step_normalizer_test.dart`
- `test/core/services/live_step_monitor_test.dart`
- `test/presentation/cubits/today_cubit_test.dart`

### Change Log

- 2026-06-05: Rate-limit credited step delta in shared increment calculator; wired normalizer + live monitor; tests + Nord field notes.
