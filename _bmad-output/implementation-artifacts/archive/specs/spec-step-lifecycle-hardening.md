---
title: 'Step counter lifecycle hardening + Epic 5 overflow animation story'
type: 'bugfix'
created: '2026-06-02'
status: 'done'
baseline_commit: '3953cb4d2ab9dee7258b056160b544972b6b9fe7'
context:
  - '_bmad-output/implementation-artifacts/spec-realtime-step-display.md'
  - '_bmad-output/implementation-artifacts/stories/2-6-goal-celebration-animation.md'
  - '_bmad-output/planning-artifacts/epics.md'
  - 'docs/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Field test (2026-06-02) reports three issues: (1) beyond-goal ring animation is unsatisfactory — defer UI polish to Epic 5 but capture it as a backlog story; (2) step count freezes after switching apps and returning while process stays alive; (3) cold start sometimes shows a lower step count than before restart.

**Approach:** Add Epic 5 Story 5.4 for overflow animation polish (planning only). Fix lifecycle bugs by serializing cold-start refresh before live attach, making TodayCubit step updates monotonic, restarting the pedometer stream on resume, and syncing steps to the cubit after resume reconcile.

## Boundaries & Constraints

**Always:**
- Only `BackgroundCollector` writes step buckets to SQLite.
- `LiveStepMonitor` remains sole `Pedometer.stepCountStream` owner while process alive.
- Reconcile protocol unchanged: pause delta → collectOnce → reconcileFromDatabase → resume delta.
- Monotonic display: UI step count never decreases except on local-day rollover.
- Epic 5 story is backlog/doc only — no widget changes for overflow animation in this spec.

**Ask First:**
- Changing periodic persist interval from 60s.
- Adding Android foreground service for process keep-alive.

**Never:**
- Implementing the beyond-goal animation (Epic 5 scope).
- Second concurrent pedometer stream subscription.
- Writing buckets from monitor or cubit.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| COLD_START_ORDER | App launch, permission granted | `foregroundBackfill` completes → cubit `refresh()` from DB → then `attachLiveMonitor` | Live emits during loading must not be dropped |
| COLD_START_RACE | Live monitor emits 1050, DB refresh returns 1000 | UI shows 1050 (monotonic max) | N/A |
| RESUME_FOREGROUND | App backgrounded, user walks, returns (process alive) | Stream restarted; collect + reconcile; cubit steps ≥ pre-resume | Log collector errors; still sync steps |
| RESUME_FROZEN_STREAM | Pedometer silent after background | `stop()` + `start()` + reconcile on resume unblocks live updates | N/A |
| PERIODIC_DURING_RESUME | 60s persist overlaps resume collect | Resume awaits in-flight collect or runs after it; reconcile still runs once | No double-count |
| DAY_ROLLOVER | Local midnight | Monotonic guard does not block legitimate day reset | Existing rollover handler |
| EPIC5_STORY | epics.md updated | Story 5.4 in backlog with Given/When/Then ACs | N/A |

</frozen-after-approval>

## Code Map

- `_bmad-output/planning-artifacts/epics.md` -- add Story 5.4 (overflow animation polish)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- register `5-4-goal-overflow-animation-polish: backlog`
- `lib/presentation/screens/app_scaffold.dart` -- remove parallel `_initialRefresh().refresh()`; delegate startup sync to app lifecycle owner
- `lib/app.dart` -- serialize refresh → attach; resume: restart monitor + sync steps to cubit
- `lib/presentation/cubits/today_cubit.dart` -- monotonic `_applyTodaySnapshot`; apply live steps while loading
- `lib/core/services/live_step_monitor.dart` -- add `restart()` (stop + start + reconcile) for resume recovery
- `lib/core/services/background_collector.dart` -- optional: await in-flight collect instead of returning 0
- `test/presentation/cubits/today_cubit_test.dart` -- monotonic + live-during-loading tests
- `test/app_live_pipeline_lifecycle_test.dart` -- NEW: resume with live pipeline
- `test/core/services/live_step_monitor_test.dart` -- restart + post-silence reconcile

## Tasks & Acceptance

**Execution:**
- [x] `_bmad-output/planning-artifacts/epics.md` -- add Story 5.4 Goal Overflow Animation Polish with ACs for beyond-goal ring behavior (distinct from Story 2.6 once-per-day celebration) -- captures field feedback for Epic 5 UI pass
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- add `5-4-goal-overflow-animation-polish: backlog` under epic-5 -- tracking
- [x] `lib/presentation/cubits/today_cubit.dart` -- monotonic step merge in `_applyTodaySnapshot`; remove loading guard in `_applyLiveSteps` (or buffer until first refresh) -- prevents backward jumps
- [x] `lib/presentation/screens/app_scaffold.dart` -- remove `_initialRefresh()` DB refresh; keep backfill await only -- eliminates race with live attach
- [x] `lib/app.dart` -- after backfill: `await todayCubit.refresh()` then `attachLiveMonitor`; on resume: `monitor.restart()` + `syncStepsFromMonitor()` or `refresh(silent:true)` with monotonic guard -- fixes freeze and startup order
- [x] `lib/core/services/live_step_monitor.dart` -- add `restart()` wrapping stop/start/reconcile -- resume stream recovery
- [x] `test/presentation/cubits/today_cubit_test.dart` -- monotonic refresh after live; live during loading -- regression guard
- [x] `test/app_live_pipeline_lifecycle_test.dart` -- resume increases steps with live pipeline enabled -- field scenario
- [x] `test/core/services/live_step_monitor_test.dart` -- restart preserves monotonic display -- unit coverage

**Acceptance Criteria:**
- Given epics.md and sprint-status updated, when reviewed, then Story 5.4 exists with Given/When/Then ACs for beyond-goal animation polish (no code implementation).
- Given permission granted and user walks with app open, when switching away 30s+ and returning, then step count updates within 5s without force-stop.
- Given app cold start after walking with pending live delta, when Today loads, then displayed steps never decrease vs last visible value before kill (monotonic).
- Given live monitor attached before cubit leaves loading, when sensor emits, then steps update (not silently dropped).
- Given `flutter analyze` and `flutter test`, when run, then all pass.

## Design Notes

**Cold-start sequence (single owner in `AstraApp._maybeStartLivePipeline`):**
1. await `foregroundBackfill`
2. `await todayCubit.refresh()` — DB baseline into cubit
3. `monitor.start()` → `reconcileFromDatabase()` → `attachLiveMonitor`

**Resume sequence (`_collectAndRefreshToday`):**
1. `await monitor.restart()` OR `stop()`/`start()` if not running
2. `await _runPersistCycle(enableGoalNotification: false)`
3. `await todayCubit.syncSteps(monitor.currentTodaySteps)` or silent refresh with monotonic merge

**Monotonic rule:** `_applyTodaySnapshot` uses `steps: max(incoming, state.steps)` unless local day changed (compare `formatLocalDayIso`).

**Story 5.4 scope (Epic 5 only):** Calm animation when `TodayStatus.overflow` — e.g. subtle continued pulse/shimmer on full ring, optional secondary micro-copy, reduce-motion variant. Distinct from Story 2.6 one-shot celebration at goal crossing.

## Verification

**Commands:**
- `flutter analyze` -- expected: no issues
- `flutter test test/presentation/cubits/today_cubit_test.dart test/core/services/live_step_monitor_test.dart test/app_live_pipeline_lifecycle_test.dart` -- expected: all pass

**Manual checks:**
- Walk, switch to another app 1 min, return: count advances.
- Force-stop and reopen after walking: count does not drop.
- Epic 5 story visible in epics.md and sprint-status.

## Spec Change Log

| Date | Trigger | Amendment | Avoids |
|------|---------|-----------|--------|
| 2026-06-02 | Implementation complete | All tasks done; 260 tests pass | — |

## Suggested Review Order

**Lifecycle orchestration**

- Cold-start order: backfill → DB refresh → live attach (single owner in `AstraApp`)
  [`app.dart:118`](../../lib/app.dart#L118)

- Resume: restart pedometer stream, persist, sync steps to cubit
  [`app.dart:97`](../../lib/app.dart#L97)

**Display safety net**

- Monotonic step merge + `syncSteps()` for resume path
  [`today_cubit.dart:76`](../../lib/presentation/cubits/today_cubit.dart#L76)

- Live updates no longer dropped while cubit is loading
  [`today_cubit.dart:183`](../../lib/presentation/cubits/today_cubit.dart#L183)

**Stream recovery**

- `restart()` re-subscribes after background stall
  [`live_step_monitor.dart:89`](../../lib/core/services/live_step_monitor.dart#L89)

**Epic 5 backlog (doc only)**

- Story 5.4 overflow animation polish
  [`epics.md:925`](../../_bmad-output/planning-artifacts/epics.md#L925)

**Tests**

- Live pipeline resume + cold-start monotonic widget tests
  [`app_live_pipeline_lifecycle_test.dart:106`](../../test/app_live_pipeline_lifecycle_test.dart#L106)

- Cubit monotonic + loading-path unit tests
  [`today_cubit_test.dart:461`](../../test/presentation/cubits/today_cubit_test.dart#L461)
