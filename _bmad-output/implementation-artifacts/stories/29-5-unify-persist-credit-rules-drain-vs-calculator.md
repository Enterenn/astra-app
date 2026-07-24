# Story 29.5: Unify Persist Credit Rules (Drain vs Calculator)

Status: review

<!-- Implementation complete 2026-07-24 — awaiting OK commit gate (A/B/C/D) -->

<!-- audits_2 Epic 29 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 29-5 · diagnostic-live-step-monitor.md #2 · AUD2-FR21, AUD2-NFR8 -->
<!-- Prerequisite: Stories 29-1, 29-2, 29-3, 29-4 done · base 0.12.1+31 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer maintaining step integrity**,
I want a single documented rule for whether a reading is forwarded to persist,
So that drain gate and `StepIncrementCalculator` cannot diverge again.

## Acceptance Criteria

1. **Given** `live_step_monitor.dart` drain gate and `step_increment_calculator.dart`
   **When** this story ships
   **Then** either (a) a shared helper `shouldForwardReadingForPersistence(current, baseline)` is used by both paths, or (b) drain pre-filter is removed and anti-double-credit is documented in one place — AUD2-FR21

2. **Given** hardware reset, noise dip, and normal increment scenarios
   **When** evaluated by the unified rule
   **Then** persist path matches calculator semantics from Story 29-2

3. **Given** UI live path (`_applyReadingToDelta`)
   **When** unchanged by refactor
   **Then** live display behaviour is preserved — AUD2-NFR8

**Covers:** AUD2-FR21 · AUD2-NFR8 · diagnostic-live-step-monitor.md #2 (P1 T3)

**Depends on:** Stories 29-1 → 29-4 done. Epic 29 ships **29-1 → 29-5** in order — this is the **final story** in the atomic E-B bundle.

**Out of scope:** Rate-limit logic (stays in `calculate()` only), normalizer bucket math, compaction (29-4 done), version bump (Epic 29 close → `0.13.0+32` per sprint tracker).

## Tasks / Subtasks

- [x] **Sub-task A — Extract shared persist-forward helper** (AC: #1, #2)
  - [x] Read fully: `step_increment_calculator.dart`, `live_step_monitor.dart` (`drainReadingsForCollection`, `_shouldForwardDrainedReading`)
  - [x] Add public method on `StepIncrementCalculator`, e.g. `shouldForwardForPersistence({required int current, required int baseline})`
  - [x] Document on class + method: drain pre-filter vs full `calculate()` (rate cap applies only in normalizer/live UI)
  - [x] Replace `_shouldForwardDrainedReading` in `live_step_monitor.dart` with `incrementCalculator.shouldForwardForPersistence(...)`
  - [x] Delete private `_shouldForwardDrainedReading` — no duplicate threshold math in monitor
  - [x] Preserve drain logging (`drain gate pass reset`, `drain gate drop`) unchanged
  - [x] **Do not** change `_applyReadingToDelta` or `calculate()` signature/behaviour unless extracting shared `baseline ~/ 2` constant with zero semantic change
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Unit tests for unified rule** (AC: #2)
  - [x] Add table-driven tests in `test/data/datasources/step_increment_calculator_test.dart` for `shouldForwardForPersistence`:
    - normal forward: `(120, 100)` → true
    - at baseline: `(100, 100)` → false (anti double-credit pre-filter)
    - hardware reset: `(50, 10_000)`, `(150, 10_000)` → true
    - noise band: `(9900, 10_000)`, `(9, 10)` → false
    - edge at reset threshold: `(5000, 10_000)` → true; `(5001, 10_000)` → false
  - [x] Cross-check: for each `(current, baseline)` where helper returns true, either `calculate` returns non-null OR `current > baseline` (forward-new path)
  - [x] Run `flutter test test/data/datasources/step_increment_calculator_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Regression verification** (AC: #2, #3)
  - [x] Run `flutter test test/core/services/live_step_monitor_test.dart` — gated drain tests from 29-2 must pass unchanged
  - [x] Run `flutter test test/core/services/idle_flush_persist_test.dart` — reset persist integration must pass
  - [x] Run `flutter test test/data/datasources/monitor_drain_source_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Diagnostic closure + Epic 29 prep note** (AC: #1)
  - [x] Update `planning-artifacts/audits_2/diagnostic-live-step-monitor.md` #2 → `fixed` with story ref; set global status to `closed` if no open items remain
  - [x] Update `planning-artifacts/audits_2/README.md` P1 row #2 (duplication drain vs calculator)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

Story 29-2 fixed P0 drain reset forwarding by **mirroring** `StepIncrementCalculator` reset threshold in a private `_shouldForwardDrainedReading`. Two components now encode the same business rule independently:

| Component | Rule | File |
|-----------|------|------|
| Drain pre-filter | `current > baseline \|\| current <= baseline ~/ 2` | `live_step_monitor.dart:375-379` |
| Increment math | `current >= baseline` → delta; `current <= baseline ~/ 2` → reset credit; else null | `step_increment_calculator.dart:42-56` |
| UI live | Uses full `calculate()` with rate cap | `live_step_monitor.dart:471-475` |

**Risk:** Future fix to reset/noise semantics in one file only — pattern already seen in permissions audit (diagnostic **02**). AUD2-FR21 requires single source of truth.

[Source: `diagnostic-live-step-monitor.md` #2 · `epics-audits-2.md` AUD2-FR21]

### Recommended approach: Option (a) — shared helper on calculator

Epic AC allows (a) shared helper or (b) remove pre-filter. **Prefer (a)** — the pre-filter prevents already-credited readings from reaching the normalizer (cheap buffer hygiene + explicit logging). Option (b) would work functionally (normalizer returns null for noise) but loses structured drop logs and sends more no-op readings through the pipeline.

**Extract to `StepIncrementCalculator`:**

```dart
/// Whether [current] should leave the monitor drain and enter the persist
/// pipeline (normalizer → collector). Does not apply rate limiting — that
/// remains in [calculate] for live UI and bucket credit.
///
/// Intentional difference vs [calculate]: uses strict `>` at baseline so
/// readings exactly at persisted baseline are dropped before normalizer
/// (anti double-credit); [calculate] returns `0` at equality which the
/// normalizer skips anyway.
bool shouldForwardForPersistence({
  required int current,
  required int baseline,
}) {
  if (current > baseline) return true;
  if (current <= baseline ~/ 2) return true;
  return false;
}
```

**Wire in drain loop** (`live_step_monitor.dart`):

```dart
if (incrementCalculator.shouldForwardForPersistence(
  current: cumulative,
  baseline: sinceCumulative,
)) {
  // existing pass-reset log + forwarded.add
} else {
  // existing drop log
}
```

Delete `_shouldForwardDrainedReading`.

**Optional DRY (zero semantic change):** In `calculate()`, replace inline `baseline ~/ 2` with a private getter or call to the same threshold — only if it reduces duplication without changing branches. Do **not** route `calculate()` through `shouldForwardForPersistence` wholesale — equality handling differs (`>=` vs `>`).

### Semantic truth table (must preserve after refactor)

| Baseline | Reading | `shouldForwardForPersistence` | Drain (29-2) | `calculate` delta | Persist outcome |
|----------|---------|-------------------------------|--------------|-------------------|-----------------|
| 100 | 90 | false | Drop | null | No credit |
| 100 | 100 | false | Drop | 0 | No credit |
| 100 | 120 | true | Forward | 20 | Credit 20 |
| 10_000 | 9_900 | false | Drop | null | No credit |
| 10_000 | 50 | true | Forward | 50 (reset) | Credit 50 |
| 10_000 | 100 | true | Forward | 50 | Credit 50 |
| 10_000 | 150 | true | Forward | 50 | Credit 150 |
| 10_000 | 5_000 | true | Forward (at threshold) | 5_000 (reset) | Credit 5_000 |
| 10_000 | 5_001 | false | Drop | null | No credit |

[Source: `live_step_monitor_test.dart` gated drain tests · `idle_flush_persist_test.dart` reset integration · `step_increment_calculator_test.dart`]

### Preserve existing behaviour (AUD2-NFR8)

| Path | Must remain |
|------|-------------|
| `_applyReadingToDelta` | Unchanged — still calls `incrementCalculator.calculate()` with elapsed + rate cap |
| `StepNormalizer.normalizeReadings` | Unchanged — calculator instance injected, bucket math untouched |
| `MonitorDrainSource` | Still calls `drainReadingsForCollectionGated()` |
| Buffer semantics | Drain empties buffer whether reading forwarded or dropped |
| `livePipelineLog` | Keep `drain gate pass reset` / `drain gate drop` messages |
| Reconcile / day boundary | Untouched |

**Persist chain (structure unchanged):**

```
BackgroundCollector.collectOnce
  → MonitorDrainSource.watchStepReadings()
       → drainReadingsForCollectionGated()
            → shouldForwardForPersistence (via incrementCalculator)  ← unify here
       → StepNormalizer.normalize (calculate + rate cap)
       → upsertIngestionBucket + setBaseline (29-3 txn)
```

**UI chain (untouched):**

```
PhoneStepEvent → _bufferReading → _applyReadingToDelta → calculate() → _pendingDelta → stream
```

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-20: deltas via `StepNormalizer` | Drain only filters; normalizer remains sole bucket writer |
| Live vs persist separation | Helper is persist-classification only; UI keeps full `calculate()` — AUD2-NFR8 |
| Monitor never writes buckets | No repository calls added |
| Single native subscription | No change to `MonitorDrainSource` contract |
| Epic 29 atomic bundle | Final story — after this, Epic 29 ready for retrospective + version bump |

[Source: `architecture.md` data flow · `epics-audits-2.md` guardrails]

### File structure requirements

| File | Action |
|------|--------|
| `lib/data/datasources/step_increment_calculator.dart` | Add `shouldForwardForPersistence`, doc comments |
| `lib/core/services/live_step_monitor.dart` | Use shared helper; remove `_shouldForwardDrainedReading` |
| `test/data/datasources/step_increment_calculator_test.dart` | Table-driven helper tests |
| `planning-artifacts/audits_2/diagnostic-live-step-monitor.md` | Close #2 |
| `planning-artifacts/audits_2/README.md` | Sync P1 #2 row |

**Do not touch:** `step_normalizer.dart`, `background_collector.dart`, `sample_compaction_runner.dart`, `monitor_drain_source.dart` (unless import cleanup needed — unlikely).

### Testing requirements

| Command | When |
|---------|------|
| `flutter test test/data/datasources/step_increment_calculator_test.dart` | After Sub-task B |
| `flutter test test/core/services/live_step_monitor_test.dart` | After Sub-task C |
| `flutter test test/core/services/idle_flush_persist_test.dart` | After Sub-task C |
| `flutter test test/data/datasources/monitor_drain_source_test.dart` | After Sub-task C |

**Do not** run bare `flutter test` unless Baptiste asks.

**Existing tests that must pass without expectation changes:**

- `forwards hardware reset readings through baseline-gated drain`
- `drops noise dip above reset threshold in baseline-gated drain`
- `idle flush persists steps after hardware counter reset below baseline`
- `baseline-gated drain skips readings already credited in baseline` (idle_flush)

### Previous story intelligence

| Learning | Impact on 29-5 |
|----------|----------------|
| 29-2 (`7a5949e`): added `_shouldForwardDrainedReading` as **temporary** mirror — explicit defer to 29-5 for extraction | This story **promotes** that logic to calculator |
| 29-2: do not change `_applyReadingToDelta` | Still applies — UI path untouched |
| 29-2: logging pattern for gate drops | Preserve log strings — tests/docs may reference them |
| 29-3: atomic txn collect | Unrelated — do not refactor collector |
| 29-4: compaction insert guard | Unrelated — separate code path |
| OK commit gate | One commit per sub-task A/B/C/D after Baptiste approval |

[Source: `stories/29-2-forward-hardware-reset-readings-through-live-drain.md` · `stories/29-4-guard-compaction-delete-until-insert-succeeds.md`]

### Cross-story context (Epic 29 close)

| Story | Status | Relationship |
|-------|--------|--------------|
| 29-1 | done | terminalBaseline after noise |
| 29-2 | done | drain forwards hardware resets (temporary duplicate) |
| 29-3 | done | atomic txn buckets + baseline |
| 29-4 | done | compaction insert-before-delete |
| **29-5** | **this story** | unify persist credit rules — **last in epic** |

After 29-5: run epic retrospective (optional), bump `pubspec.yaml` to `0.13.0+32`, update `README.md` status row, mark `epic-29: done` in sprint tracker.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `8f36ad2` / `ee172e6` | Story 29-4 done — compaction guard |
| `752e1cb` | Story 29-3 — per-source txn pattern |
| `7a5949e` / `39a72e1` | Story 29-2 — `_shouldForwardDrainedReading` to extract |
| `c90fb5e` | Story 29-1 — normalizer baseline |

### Latest tech / library notes

- **No package upgrades.** Pure Dart refactor on existing `StepIncrementCalculator` const instance already injected in `LiveStepMonitor`.
- **Naming:** Epic AC says `shouldForwardReadingForPersistence`; codebase convention is shorter method names on the owning class — `shouldForwardForPersistence` on `StepIncrementCalculator` is acceptable if documented as fulfilling AUD2-FR21.
- **Const calculator:** `LiveStepMonitor` defaults `incrementCalculator = const StepIncrementCalculator()` — new method must be callable on const instance (no instance state needed).

### Project context reference

- OK commit gate: sub-tasks A/B/C/D each get separate commit after Baptiste approval
- Tests: localized `flutter test <path>` per token-economy rule
- Version bump: defer to Epic 29 close (`0.13.0+32`)
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 29-5, AUD2-FR21]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-live-step-monitor.md` #2]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` §P1 #2]
- [Source: `lib/core/services/live_step_monitor.dart` — drain + UI paths]
- [Source: `lib/data/datasources/step_increment_calculator.dart`]
- [Source: `stories/29-2-forward-hardware-reset-readings-through-live-drain.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Sub-task A: `shouldForwardForPersistence` on `StepIncrementCalculator`; drain uses shared helper; `_shouldForwardDrainedReading` removed; `_hardwareResetThreshold` DRY in `calculate()`.
- Sub-task B: 8 table-driven cases + cross-check test; 20/20 pass in calculator test file.
- Sub-task C: 54/54 pass across live_step_monitor, idle_flush_persist, monitor_drain_source — no expectation changes.
- Sub-task D: diagnostic #2 → fixed, global `closed`; README audit 09 row #2 synced.

### File List

- `lib/data/datasources/step_increment_calculator.dart`
- `lib/core/services/live_step_monitor.dart`
- `test/data/datasources/step_increment_calculator_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-live-step-monitor.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`
- `_bmad-output/implementation-artifacts/stories/29-5-unify-persist-credit-rules-drain-vs-calculator.md`
