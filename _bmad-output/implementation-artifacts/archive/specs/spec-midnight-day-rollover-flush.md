---
title: 'Midnight day rollover — flush live steps then reset'
type: 'bugfix'
created: '2026-06-07'
status: 'in-review'
baseline_commit: '7583d3829137eca79d11854a897b1fb4f703742f'
context:
  - '_bmad-output/implementation-artifacts/spec-realtime-step-display.md'
  - '_bmad-output/implementation-artifacts/stories/2-3-step-repository-and-time-semantics.md'
  - '_bmad-output/implementation-artifacts/stories/2-9-today-display-truth-model-and-live-overlay.md'
  - 'docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** When the app stays in memory across local midnight (background, pocket walking), live overlay and Today UI remain stuck on the previous day. `reconcileFromDatabase()` applies the same-day monotonic floor across the boundary, inflating `pendingDelta` with yesterday's total. Live ticks stop; resume at 00:09 shows yesterday's count until cold start. Daily trend accuracy suffers because overlay steps credited to the closing day may never reach SQLite before the new day starts.

**Approach:** At each local midnight boundary, **persist first, reset second**: drain the live monitor buffer to SQLite (bucket assignment stays timestamp-driven via `StepNormalizer`), then reset overlay state for the new local day and refresh Today/History. Schedule the boundary in the UI isolate; add resume and FGS-adjacent fallbacks when the timer is delayed (Doze, late unlock). Never apply the monotonic display floor across a local-day change.

## Boundaries & Constraints

**Always:**

- Only `BackgroundCollector` writes step buckets to SQLite.
- Persist-before-reset order is mandatory: closing-day overlay must reach SQLite before monitor/cubit reset.
- Bucket day attribution uses each reading's `observedAtUtc` (Story 2.3 semantics) — no manual "force yesterday" SQL.
- Local-day boundary = **device civil calendar** via `TimeProvider` / `SystemTimeProvider` (`nowUtc` + `timeZoneOffset`). Stored buckets keep immutable per-row `zone_offset`; no fixed UTC/GMT day boundary.
- Monotonic display within the same local day; legitimate decrease allowed only on local-day rollover.
- Reconcile mutex protocol unchanged for normal persist cycles.
- Boundary persist uses `enableGoalNotification: false` (same as resume — no spurious goal notification for the closing day).
- On rollover: clear `TodayState.foregroundCatchUp` / `catchUpTargetSteps` so live applies are not blocked.
- On rollover: dismiss in-flight goal celebration (`showCelebration: false`); UX §3.12 ring reset for new local day.

**Ask First:**

- Exact AlarmManager / wake-at-midnight native scheduling (prefer Dart timer + fallbacks first).
- Changing FGS collection cadence solely for midnight.

**Never:**

- Mask rollover bugs by growing `pendingDelta` across days.
- Write buckets from `LiveStepMonitor` or `TodayCubit`.
- Split steps at midnight by wall-clock guess — trust normalizer timestamps only.
- NTP / network time checks or dedicated manual clock-change detection — trust the device clock (simplest model; rare user tampering is accepted).
- Resetting ingestion baseline at midnight — cumulative phone counter, not daily; would double-count.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| MIDNIGHT_FOREGROUND_WALK | 23:58 walk, process alive, live pipeline on | At local 00:00: persist drains buffer; steps before midnight land in closing day buckets; overlay resets to new-day SQLite total; live resumes | Log `[ASTRA:LIVE] dayBoundary`; reschedule next midnight |
| MIDNIGHT_BACKGROUND_POCKET | App paused 23:30, walking, FGS active | Best-effort midnight persist in UI isolate OR flush on first post-midnight FGS/resume hook; closing day SQLite complete before new-day overlay | If UI timer delayed, resume fallback runs same sequence |
| RESUME_AFTER_MIDNIGHT | Unlock 00:09, no kill, missed timer | Before normal resume pipeline: detect day change → persist closing day → reset → then `_resumeLivePipeline` | No yesterday total in `pendingDelta` after reset |
| READINGS_SPAN_MIDNIGHT | Buffer has events 23:58 and 00:02 | Single persist attributes each increment to its timestamp bucket (two local days) | Normal rate-limit / noise rules per reading |
| NO_PENDING_OVERLAY | Midnight, overlay already reconciled | Persist no-op or minimal; still reset tracked day and refresh UI | Skip redundant GoalRing catch-up |
| GOAL_MET_YESTERDAY | Goal reached day D; app open or resume day D+1 at 00:05 | Ring shows D+1 total (0 or post-midnight steps); no celebration replay; live ticks | Celebration claim keyed to D+1 only |
| FOREGROUND_CATCH_UP_STALE | Resume D+1 while `foregroundCatchUp` still set from D | Rollover handler clears catch-up before live rebind; live events apply immediately | Log catch-up cleared on dayBoundary |
| CELEBRATION_IN_FLIGHT | GoalCelebration animating at 23:59:59 | Rollover dismisses celebration; ring resets for new day | No celebration overlay on D+1 at 0 steps |
| TZ_TRAVEL | `TimeProvider` offset changes mid-session | Next boundary uses current offset from `clock.snapshot()` | Existing per-row `zone_offset` rules unchanged |
| COLD_START_NEW_DAY | Kill after rollover | Unchanged cold-start path; SQLite authoritative | N/A |

</frozen-after-approval>

## Code Map

| File | Role | Likely change |
|------|------|---------------|
| `lib/core/time/local_day_boundary.dart` | Compute duration until next local midnight; detect day change between two snapshots | **New** — pure, testable |
| `lib/core/services/live_step_monitor.dart` | Overlay + `_trackedLocalDay` + `_handleLocalDayRollover` | Split rollover: no inline reconcile; add `resetForNewLocalDay()` without cross-day monotonic floor; optional `trackedLocalDay` getter |
| `lib/app.dart` | Live pipeline owner, persist cycles, lifecycle | Midnight `Timer`; `_runLocalDayBoundary()` persist (`enableGoalNotification: false`) → reset → refresh; boundary check before resume reconcile |
| `lib/presentation/cubits/today_cubit.dart` | Today display | `refreshAfterDayRollover()`: allow step decrease, clear `foregroundCatchUp`, dismiss celebration, reset `_lastAppliedLocalDay`, rebuild week strip |
| `lib/core/services/health_foreground_service.dart` | FGS ↔ UI | Optional: after FGS collect, notify UI if local day advanced (fallback only) |
| `test/core/time/local_day_boundary_test.dart` | Boundary math | Midnight scheduling, DST-safe offset |
| `test/core/services/live_step_monitor_day_rollover_test.dart` | Monitor reset | Cross-day reconcile does not preserve yesterday floor |
| `test/app_live_pipeline_lifecycle_test.dart` | Integration | Fake clock: background → advance past midnight → resume shows new day + live works |

## Tasks & Acceptance

**Execution:**

- [x] `lib/core/time/local_day_boundary.dart` — add `untilNextLocalMidnight`, `hasLocalDayChanged` using `LocalDayCalculator` / `formatLocalDayIso`
- [x] `lib/core/services/live_step_monitor.dart` — refactor rollover: remove fire-and-forget reconcile from `_handleLocalDayRollover`; add `resetForNewLocalDay()` (zero pending, clear baseline, reload today's persisted total, emit); make `reconcileFromDatabase` skip monotonic floor when `_trackedLocalDay` differs from current local day
- [x] `lib/app.dart` — schedule/reschedule midnight timer; `_runLocalDayBoundary()` with `enableGoalNotification: false`; boundary check before resume reconcile
- [x] `lib/presentation/cubits/today_cubit.dart` — `refreshAfterDayRollover()`: allow decrease, clear catch-up, dismiss celebration, refresh week strip
- [x] `test/core/time/local_day_boundary_test.dart` — unit tests for boundary helpers
- [x] `test/core/services/live_step_monitor_day_rollover_test.dart` — persist-then-reset semantics; no phantom pendingDelta
- [x] `test/app_live_pipeline_lifecycle_test.dart` — resume-after-midnight regression (00:09 unlock); goal-met-yesterday → no celebration on D+1
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` — register `6-6-midnight-day-rollover-flush: ready-for-dev`

**Acceptance Criteria:**

- Given live steps accumulating on day D and local midnight passes with the process alive, when the boundary handler runs, then all overlay increments with timestamps on day D are persisted to SQLite for day D before the monitor resets, and Today shows day D+1 total (≥ 0) with live ticking.
- Given the app was backgrounded on day D and unlocked on day D+1 without kill, when `_onAppForegrounded` runs, then the closing-day persist runs before resume reconcile, UI shows D+1 (not D), and live overlay works without cold start.
- Given goal was met on day D and the user opens or resumes on day D+1, when the rollover handler runs, then no goal celebration replays and Today shows the D+1 step total only.
- Given `foregroundCatchUp` was active when the local day changes, when rollover completes, then live step events apply immediately (not ignored for catch-up).
- Given steps walked in pocket across midnight, when trends/history are queried, then day D and D+1 totals match timestamp-bucketed SQLite sums (no large overlay-only gap on D).
- Given `flutter test` on new rollover tests, when run after the fix, then all pass.

## Design Notes

**Persist-then-reset sequence (orchestrated in `app.dart`):**

```
detect local day change
  → await persist cycle (enableGoalNotification: false)
  → monitor.resetForNewLocalDay()
  → todayCubit.refreshAfterDayRollover()   // allow decrease, clear catch-up, dismiss celebration
  → historyCubit.refresh(silent: true)
  → reschedule midnight timer
```

**Why timer + resume fallback:** Android may defer Dart timers while backgrounded (user unlocked at 00:09, not 00:00). Resume fallback guarantees correctness; timer improves trend precision when the process stays schedulable at midnight.

**Time source (keep simple):** Same as Story 2.3 — device system clock only. DST and travel are handled by stored `zone_offset` per bucket; manual clock edits may produce odd day splits and are out of scope.

## Verification

**Commands:**

```bash
flutter analyze
flutter test test/core/time/local_day_boundary_test.dart
flutter test test/core/services/live_step_monitor_day_rollover_test.dart
flutter test test/app_live_pipeline_lifecycle_test.dart
flutter test
```

**Manual checks:**

1. Walk before 23:55; background app (home button); keep walking through midnight; unlock ~00:10 — Today must show new day, live ticks, History yesterday total includes pre-midnight walk.
2. Stay foreground through midnight while walking — ring resets at 00:00 without cold start; steps after midnight increment on new day.
3. Inspect logs: `dayBoundary persist` then `resetForNewLocalDay`; no reconcile line with `pendingDelta ≈ yesterday total` on new day.
4. Hit goal yesterday; open app today ~00:05 — no celebration, ring at today's count, live works.

## Spec Change Log

| Date | Trigger | Amendment | Avoids |
|------|---------|-----------|--------|
| 2026-06-07 | Review: day-change side effects | Added catch-up clear, celebration dismiss, boundary persist without goal notification, GOAL_MET_YESTERDAY I/O + AC; explicit no baseline reset | Live blocked after rollover; spurious goal notif; celebration replay |
