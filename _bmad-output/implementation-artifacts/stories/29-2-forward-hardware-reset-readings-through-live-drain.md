# Story 29.2: Forward Hardware Reset Readings Through Live Drain

Status: done

<!-- audits_2 Epic 29 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 29-2 · diagnostic-live-step-monitor.md #1 · AUD2-FR2, AUD2-FR34, AUD2-NFR6 -->
<!-- Prerequisite: Story 29-1 done · base 0.12.1+31 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want steps after a phone reboot to be saved even when the hardware counter resets below my stored baseline,
So that my daily total is not permanently under-counted.

## Acceptance Criteria

1. **Given** a persisted baseline of 10 000 and post-reboot readings 50, 100, 150
   **When** `drainReadingsForCollectionGated()` runs
   **Then** reset readings pass through to `StepNormalizer` (not silently discarded by `>` filter alone) — AUD2-FR2
   **And** persist path credits steps consistent with `StepIncrementCalculator` reset rule (`current <= baseline/2`)

2. **Given** a small dip above reset threshold (noise, not hardware reset)
   **When** drain runs
   **Then** behaviour matches prior intent — noise still filtered appropriately

3. **Given** readings dropped by the drain gate
   **When** filtering occurs
   **Then** `livePipelineLog` records the drop reason — AUD2-NFR6

4. **Given** baseline 10 000 and readings 50/100/150 post-reboot
   **When** covered by a new test in `idle_flush_persist_test.dart` or `live_step_monitor_test.dart`
   **Then** persist path credits the reset — AUD2-FR34

**Covers:** AUD2-FR2 · AUD2-FR34 · AUD2-NFR1 · AUD2-NFR6 · diagnostic-live-step-monitor.md #1 (Quick fix Q2)

**Depends on:** Story 29-1 done (correct `terminalBaseline` after noise). Epic 29 ships **29-1 → 29-5** in order.

**Out of scope:** Shared helper extraction / drain-calculator unification (29-5), atomic txn collect (29-3), compaction (29-4), version bump (Epic 29 close → minor+1, build+1).

## Tasks / Subtasks

- [x] **Sub-task A — Fix drain gate filter** (AC: #1, #2, #3)
  - [x] Read fully: `lib/core/services/live_step_monitor.dart` (`drainReadingsForCollection`, `drainReadingsForCollectionGated`)
  - [x] Replace naive `cumulativeSteps > sinceCumulative` filter with reset-aware pass-through (see Dev Notes)
  - [x] Log each dropped reading via `livePipelineLog('monitor', 'drain gate drop', …)` with `cumulative`, `sinceCumulative`, `reason`
  - [x] Preserve buffer drain semantics: readings are removed from buffer whether forwarded or dropped
  - [x] **Do not** change `_applyReadingToDelta` (UI live path)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Unit test: gated drain forwarding** (AC: #1, #2, #4 partial)
  - [x] Add test in `test/core/services/live_step_monitor_test.dart`:
    - baseline 10 000 → readings 50/100/150 all forwarded by `drainReadingsForCollectionGated()`
    - baseline 10 000 → reading 9 900 dropped (noise above reset threshold)
  - [x] Keep existing `idle_flush_persist_test.dart:146-168` passing (baseline 100, only 120 forwarded)
  - [x] Run `flutter test test/core/services/live_step_monitor_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Integration test: persist credits reset** (AC: #4)
  - [x] Add test in `test/core/services/idle_flush_persist_test.dart`:
    - Seed baseline 10 000, buffer post-reboot readings 50/100/150 via monitor events
    - Run `_idleFlushPersist(monitor, collector)` (existing helper)
    - Assert SQLite today steps increase by **150** and persisted baseline becomes **150**
  - [x] Run `flutter test test/core/services/idle_flush_persist_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Diagnostic closure** (AC: #1)
  - [x] Update `planning-artifacts/audits_2/diagnostic-live-step-monitor.md` #1 status → `fixed` with story ref
  - [x] Update `planning-artifacts/audits_2/README.md` rows for diagnostic 09 / P0-11 / Q2
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Root cause (read before editing)

**Bug:** `drainReadingsForCollection` forwards only readings where `cumulativeSteps > sinceCumulative`. After a hardware reboot, cumulative drops far below persisted baseline (e.g. 50 vs 10 000). Those readings are **removed from the buffer and discarded** — they never reach `StepNormalizer` / `BackgroundCollector`.

**UI is unaffected:** `_applyReadingToDelta` already uses `StepIncrementCalculator` with reset rule. Only the **persist drain path** under-counts.

**Scenario:**

1. Baseline SQLite = 10 000
2. Reboot → hardware readings 50, 100, 150
3. **Bug:** `50 > 10000` false → reading dropped silently
4. Steps never persisted until hardware counter exceeds 10 000 again

[Source: `diagnostic-live-step-monitor.md` #1 · `epics-audits-2.md` AUD2-FR2]

### Current broken implementation (MUST replace filter logic only)

```333:346:lib/core/services/live_step_monitor.dart
  List<StepReading> drainReadingsForCollection({int? sinceCumulative}) {
    if (_readingsBuffer.isEmpty) {
      return const [];
    }
    final drained = List<StepReading>.generate(
      _readingsBuffer.length,
      (_) => _readingsBuffer.removeFirst(),
    );
    if (sinceCumulative == null) {
      return drained;
    }
    return drained
        .where((reading) => reading.cumulativeSteps > sinceCumulative)
        .toList(growable: false);
  }
```

### Required filter semantics (align with calculator — do NOT extract shared helper yet)

Mirror `StepIncrementCalculator` reset threshold for the drain **pre-filter only**. Story 29-5 will unify into a shared helper or remove pre-filter.

**Forward reading when `sinceCumulative` is set:**

| Condition | Action |
|-----------|--------|
| `cumulative > sinceCumulative` | Forward (new steps since last persist) |
| `cumulative <= sinceCumulative ~/ 2` | Forward (hardware reset — let normalizer/calculator credit) |
| Otherwise | Drop + log (`reason`: `already_credited_or_noise`) |

**Calculator reference (do not change this file in 29-2):**

```51:56:lib/data/datasources/step_increment_calculator.dart
    final resetThreshold = baseline ~/ 2;
    if (current <= resetThreshold) {
      return current;
    }

    return null;
```

**Suggested private helper (local to `live_step_monitor.dart` only — 29-5 may promote):**

```dart
bool _shouldForwardDrainedReading(int cumulative, int sinceCumulative) {
  if (cumulative > sinceCumulative) return true;
  if (cumulative <= sinceCumulative ~/ 2) return true;
  return false;
}
```

Iterate `drained` readings: partition into forwarded vs dropped; log each drop; return forwarded list.

**Optional observability:** log `drain gate pass reset` when second branch matches (helps field diagnosis; not required by AC but consistent with NFR6).

### Expected persist math (integration test reference)

Baseline 10 000, readings 50 → 100 → 150 through normalizer:

| Reading | Calculator delta | New baseline |
|---------|------------------|--------------|
| 50 | 50 (reset) | 50 |
| 100 | 50 | 100 |
| 150 | 50 | 150 |

**Total credited:** 150 · **Final baseline:** 150

[Source: `step_increment_calculator_test.dart` reboot cases · `StepNormalizer` loop]

### Preserve existing behaviour

| Case | Baseline | Reading | Expected drain |
|------|----------|---------|----------------|
| Already credited skip | 100 | 90, 100 | Drop (90 noise, 100 not > 100) |
| New steps | 100 | 120 | Forward |
| Noise dip | 10 000 | 9 900 | Drop |
| Hardware reset | 10 000 | 50, 100, 150 | Forward all |

Existing test `baseline-gated drain skips readings already credited in baseline` (`idle_flush_persist_test.dart:146-168`) **must still pass**.

### Architecture compliance

| Rule | Application |
|------|-------------|
| Live vs persist separation | Fix drain only; `_applyReadingToDelta` unchanged — AUD2-NFR8 |
| D-20: deltas via `StepNormalizer` | Drain forwards readings; normalizer remains sole bucket writer |
| Monitor never writes buckets | No repository calls in `LiveStepMonitor` |
| Single native subscription | `MonitorDrainSource` still drains gated buffer when monitor running |

**Persist chain (unchanged except drain filter):**

```
BackgroundCollector._collectOnce
  → MonitorDrainSource.watchStepReadings()
       → drainReadingsForCollectionGated()   ← FIX HERE
       → StepNormalizer.normalize
       → upsertIngestionBucket + setBaseline (txn = 29-3)
```

[Source: `architecture.md` §LiveStepMonitor overlay · `diagnostic-live-step-monitor.md` chain]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/services/live_step_monitor.dart` | Fix drain filter + drop logging |
| `test/core/services/live_step_monitor_test.dart` | Unit tests: reset forward + noise drop |
| `test/core/services/idle_flush_persist_test.dart` | Integration: persist credits 150 |
| `planning-artifacts/audits_2/diagnostic-live-step-monitor.md` | Close #1 |
| `planning-artifacts/audits_2/README.md` | Sync diagnostic 09 / P0-11 / Q2 |

**Do not touch:** `step_increment_calculator.dart` logic (29-5), `step_normalizer.dart` (29-1 done), `background_collector.dart` txn (29-3), `sample_compaction_runner.dart` (29-4).

### Testing requirements

| Command | When |
|---------|------|
| `flutter test test/core/services/live_step_monitor_test.dart` | After Sub-task B |
| `flutter test test/core/services/idle_flush_persist_test.dart` | After Sub-task C (file is `@Tags(['slow'])` — run targeted, not full slow suite) |
| `flutter test --exclude-tags slow` | Story verification if no slow-file changes beyond idle_flush |

**Logging in tests:** Use `@visibleForTesting` hooks on `live_pipeline_log.dart` (`livePipelineLogForceEnabled`) if asserting drop logs; otherwise assert behaviour only (forwarded count / SQLite totals).

**Test naming suggestion:**

- `forwards hardware reset readings through baseline-gated drain`
- `drops noise dip above reset threshold in baseline-gated drain`
- `idle flush persists steps after hardware counter reset below baseline` (integration)

### Previous story intelligence (29-1)

| Learning | Impact on 29-2 |
|----------|----------------|
| `terminalBaseline` fix shipped in `febd523` / story 29-1 | Reset readings that reach normalizer will persist correct baseline |
| Do not re-fix normalizer here | Drain must **forward** readings first — normalizer alone cannot help if drain drops them |
| Epic 29 atomic bundle | Ship 29-2 before 29-3; no drain/calculator unification in this PR |
| OK commit gate | One commit per sub-task A/B/C/D after Baptiste approval |

[Source: `stories/29-1-fix-terminal-baseline-after-rejected-sensor-noise.md`]

### Cross-story context (Epic 29)

| Story | Relationship |
|-------|--------------|
| 29-1 | Done — baseline after noise correct |
| **29-2** | **This story** — drain forwards hardware resets |
| 29-3 | Atomic txn for buckets + baseline — builds on correct drain + normalizer |
| 29-5 | Extract `shouldForwardReadingForPersistence` or remove pre-filter — **do not** do full unification here |

**Duplication note (diagnostic #2):** Intentionally duplicating `baseline ~/ 2` in drain filter for 29-2. Story 29-5 resolves P1 duplication; document in commit message if helpful.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `c90fb5e` | Story 29-1 done — normalizer tests + diagnostic 07 closed |
| `54a2bc1` | terminalBaseline regression test |
| `febd523` | Core normalizer fix (midnight split bundle) |
| `453fd04` | audits_2 epics E29–E33 |

### Latest tech / library notes

- **Flutter/Dart:** Use integer division `~/` for reset threshold (matches calculator).
- **No new dependencies.**
- **`livePipelineLog`:** Already used throughout monitor; follow existing `phase: 'monitor'` pattern with `minInterval` if high-volume drops are possible.

### Project context reference

- OK commit gate: sub-tasks A/B/C/D each get separate commit after Baptiste approval
- Tests: targeted files above; avoid bare `flutter test` unless Baptiste asks
- Version bump: defer to Epic 29 close (`0.13.0+32` per epics-audits-2)
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 29-2]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-live-step-monitor.md` #1]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` §09, P0-11, Q2]
- [Source: `_bmad-output/planning-artifacts/architecture.md` §LiveStepMonitor overlay]
- [Source: `lib/data/datasources/monitor_drain_source.dart`]
- [Source: `stories/29-1-fix-terminal-baseline-after-rejected-sensor-noise.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Replaced naive `>` filter in `drainReadingsForCollection` with `_shouldForwardDrainedReading` (mirrors `StepIncrementCalculator` reset threshold).
- Added `drain gate drop` / `drain gate pass reset` logging for observability (AUD2-NFR6).

### Completion Notes List

- Sub-task A: Reset-aware drain gate — forward when `cumulative > sinceCumulative` OR `cumulative <= sinceCumulative ~/ 2`; drop + log otherwise.
- Sub-task B: Unit tests — hardware reset forward (50/100/150 @ baseline 10k) + noise drop (9900 @ baseline 10k).
- Sub-task C: Integration test — idle flush credits 150 steps and baseline 150 after reboot scenario.
- Sub-task D: Diagnostic 09 P0 #1 marked fixed; README P0-11 / Q2 updated.
- Tests: `flutter test test/core/services/live_step_monitor_test.dart test/core/services/idle_flush_persist_test.dart` — 31/31 pass.

### File List

- `lib/core/services/live_step_monitor.dart`
- `test/core/services/live_step_monitor_test.dart`
- `test/core/services/idle_flush_persist_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-live-step-monitor.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`
- `_bmad-output/implementation-artifacts/stories/29-2-forward-hardware-reset-readings-through-live-drain.md`

### Change Log

- 2026-07-24: Story 29-2 — reset-aware drain gate filter + unit/integration tests + diagnostic closure (AUD2-FR2, AUD2-FR34, AUD2-NFR6).
