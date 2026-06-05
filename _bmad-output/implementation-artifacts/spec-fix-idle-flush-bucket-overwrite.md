---
title: 'Fix idle flush overwriting persisted step buckets'
type: 'bugfix'
created: '2026-06-05'
status: 'ready'
baseline_commit: 'HEAD'
context:
  - '_bmad-output/implementation-artifacts/stories/6-3-activity-idle-persist-flush.md'
  - '_bmad-output/implementation-artifacts/spec-fix-screen-lock-pedometer-freeze.md'
  - '_bmad-output/planning-artifacts/architecture.md'
related_stories:
  - '6-3-activity-idle-persist-flush'
not_related:
  - '6-4-screen-lock-pedometer-freeze'
---

## Intent

**Problem:** Field test (2026-06-05, post–6.4 validation): after 15 s idle flush, the UI still shows the correct step total (`total`), but SQLite regresses. Hot restart reloads from SQLite and the user loses most of the day's steps.

**Root cause (confirmed):** `StepRepository.upsertIngestionBucket` uses `ON CONFLICT … DO UPDATE SET value = excluded.value` — it **replaces** the bucket value instead of merging. On idle flush, `MonitorDrainSource` drains readings that were **already applied live** to `pendingDelta`. `StepNormalizer` recomputes 5-minute bucket values for those readings and upserts them, **overwriting** existing buckets for the same `(provider, device_id, start_time, end_time, resolution)` with partial recomputed totals.

**Approach:** Ensure each persist cycle only **adds net-new increments** to SQLite buckets, never replaces an existing bucket's cumulative value with a subset recomputation. Preserve the Today Display Truth Model: after a successful persist, `pendingDelta` should trend toward 0, not grow to mask SQLite loss.

## Field Evidence (2026-06-05)

Sequence from device logs (`flutter run`, screen unlock → walk → 15 s idle):

| Phase | `total` | `persisted` (SQLite) | `pendingDelta` |
|-------|---------|----------------------|----------------|
| Live walk ends | 137 | 81 | 56 |
| After idle flush reconcile | 137 | **47** | **90** |
| Hot restart (R) | **47** | 47 | 0 |

Key log line:

```
monitor: reconcile floor=137 persisted=47 pendingDelta=90 total=137
```

Interpretation:

- Idle flush **did run** (reconcile after `collectOnce`).
- SQLite **decreased** 81 → 47 (−34), not increased.
- Display truth preserved `total=137` by inflating `pendingDelta` 56 → 90 (+34).
- Hot restart proves SQLite is authoritative at cold start → user sees 47.

This is **not** a 6.4 screen-lock issue. Resume drain in the same session worked (67 → 81 on unlock).

## Boundaries & Constraints

**Always:**

- Only `BackgroundCollector` writes step buckets to SQLite.
- `LiveStepMonitor` never writes buckets; reconcile floor must not lower display.
- Rate-limit calculator shared between live overlay and normalizer (Story 6.2).
- Idle flush wiring in `app.dart` (`onActivityIdle` → `_runPersistIfNotInFlight`) stays; fix the **persist semantics**, not the timer.

**Ask First:**

- Changing bucket schema or conflict key.
- Switching from bucket upsert to append-only event log.

**Never:**

- Masking SQLite loss by growing `pendingDelta` indefinitely without fixing upsert.
- Disabling idle flush as a workaround.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| IDLE_FLUSH_AFTER_WALK | Live steps 119→137, `persisted=81`, wait 15 s idle | `persisted` ≥ pre-flush + drained increments; `pendingDelta` → 0 or lower | Log upsert counts; no bucket value decrease |
| IDLE_FLUSH_NO_NEW_STEPS | No readings since last persist, timer fires | No-op or reconcile only; SQLite unchanged | Skip collect if buffer empty |
| REPEAT_FLUSH | Two idle flushes same session | Monotonic SQLite total; no second overwrite | Mutex `_persistInFlight` respected |
| HOT_RESTART | After idle flush | Steps match last displayed `total` (within rate-limit cap) | N/A |
| STALENESS_FLUSH | 5 min fallback persist | Same merge semantics as idle | Same as idle |
| PAUSE_FLUSH | Background `_persistOnPause` | Same merge semantics | Unchanged FGS handoff |

## Code Map

| File | Role | Likely change |
|------|------|---------------|
| `lib/data/repositories/step_repository.dart` | `upsertIngestionBucket` conflict policy | Merge: `value = timeseries_samples.value + excluded.value` **or** read-modify-write in transaction |
| `lib/data/datasources/step_normalizer.dart` | Bucket computation from drained readings | Emit **increments only** since last persisted baseline; avoid re-bucketing already-persisted windows |
| `lib/data/datasources/monitor_drain_source.dart` | Drains monitor buffer | Possibly drain only readings not yet persisted (if baseline tracks last drained cumulative) |
| `lib/core/services/live_step_monitor.dart` | Buffer + `pendingDelta` | Verify buffer drain aligns with baseline; may need `drainReadingsSince(lastPersistedCumulative)` |
| `lib/core/services/background_collector.dart` | Orchestrates collect | No policy change expected; verify `terminalBaseline` advances correctly |
| `lib/data/repositories/ingestion_baseline_repository.dart` | Cumulative baseline | Must stay in sync with what SQLite already credited |
| `test/data/repositories/step_repository_test.dart` | Upsert semantics | New: second upsert same bucket **adds**, does not replace |
| `test/core/services/idle_flush_persist_test.dart` (new) | Integration | Idle drain after live walk → SQLite total ≥ pre-flush + new steps |

## Recommended Fix Options (pick one in implementation)

### Option A — Merge on upsert (minimal diff)

Change conflict clause:

```sql
ON CONFLICT(provider, device_id, type, start_time, end_time, resolution)
DO UPDATE SET value = timeseries_samples.value + excluded.value
```

**Pros:** Small change, fixes overwrite regression.  
**Cons:** Requires normalizer to emit **increments for this collect only** (not cumulative bucket totals). If normalizer already emits per-collect increments per window, this is correct. Verify no double-count when the same reading is collected twice.

### Option B — Baseline-gated drain (structural)

Track last persisted cumulative in baseline repo. `MonitorDrainSource` / monitor drain only yields readings **after** that cumulative. Normalizer starts from DB baseline; each collect produces only net-new buckets.

**Pros:** Aligns live overlay and persist paths; prevents reprocessing history.  
**Cons:** More moving parts; must handle day rollover and peek catch-up.

### Option C — Hybrid (recommended)

1. **Option B** for drain scope (don't re-drain already-persisted readings from buffer).
2. **Option A** as safety net on upsert (additive merge) so a logic bug cannot silently erase buckets.

## Tasks & Acceptance

**Execution:**

- [ ] Reproduce in test: seed SQLite with bucket value 51; upsert same window with value 16 → total must not drop (currently fails).
- [ ] Fix upsert merge semantics (`step_repository.dart`).
- [ ] Ensure idle flush only persists net-new readings (normalizer + drain + baseline alignment).
- [ ] Add regression test: live walk → idle flush → `getTodaySteps()` ≥ steps before flush + new live delta.
- [ ] Manual: walk to ~100+ steps → wait 15 s → note total → hot restart → same total (± rate-limit cap).
- [ ] Register story in `sprint-status.yaml` (e.g. `6-5-idle-flush-bucket-merge` or hotfix epic) when work starts.

**Acceptance Criteria:**

- Given live steps incrementing with `persisted < total`, when idle flush fires after 15 s inactivity, then SQLite total increases (or stays equal if nothing to persist) and never decreases.
- Given idle flush completed, when the user hot restarts, then Today steps match the pre-restart displayed total (Display Truth Model durable).
- Given `flutter test` on new + existing persist tests, when run after the fix, then all pass.

## Verification

**Commands:**

```bash
flutter analyze
flutter test test/data/repositories/step_repository_test.dart
flutter test test/app_persist_policy_test.dart
flutter test test/core/services/live_step_monitor_test.dart
# add: flutter test test/core/services/idle_flush_persist_test.dart
```

**Manual checks:**

1. Walk with screen on until steps increase materially.
2. Stop moving; wait ≥15 s (idle flush).
3. Check log: `persisted` should approach `total`, `pendingDelta` should shrink — not invert (SQLite down, pending up).
4. Hot restart (R): step count must not collapse.

## Suggested Review Order

1. `step_repository.dart` — upsert conflict policy (smoking gun).
2. `monitor_drain_source.dart` + `live_step_monitor.dart` — what gets drained on each collect.
3. `step_normalizer.dart` — increment vs replace semantics per bucket window.
4. Integration test reproducing 81 → 47 regression.

## Notes

- Story 6.3 manual validation ("kill after idle flush preserves step count") may have passed when pendingDelta happened to be small or buffer state differed; this bug appears when live overlay has large `pendingDelta` and buffer holds readings spanning already-persisted bucket windows.
- Story 6.3 field note (2102→2082 drop) is likely the same root cause.
- Debug snackbar removed 2026-06-05; do not re-add for this fix — use `[ASTRA:LIVE] monitor: reconcile` logs (`persisted`, `pendingDelta`, `total`).
