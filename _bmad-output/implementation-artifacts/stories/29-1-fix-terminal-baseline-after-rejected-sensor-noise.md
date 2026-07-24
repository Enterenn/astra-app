# Story 29.1: Fix terminalBaseline After Rejected Sensor Noise

Status: done

<!-- audits_2 Epic 29 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 29-1 · diagnostic-ingestion-pedometer.md #1 · AUD2-FR1, AUD2-FR34 -->
<!-- First story in Epic 29 — epic-29 transitions backlog → in-progress -->
<!-- Prerequisite: Epics 21–28 delivered · base 0.12.1+31 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want my step baseline to stay correct when the pedometer sends noisy readings,
So that the next background sync does not over-count steps.

## Acceptance Criteria

1. **Given** `StepNormalizer.normalizeReadings` with an accepted increment followed by a rejected noise dip as the **last** reading in the batch
   **When** normalization completes
   **Then** `terminalBaseline` equals the internal accepted `baseline` (not the rejected reading's cumulative) — AUD2-FR1
   **And** `BackgroundCollector` persists that value via `setBaseline`

2. **Given** the regression test `rejects small counter dips as glitches` in `step_normalizer_test.dart`
   **When** extended for this story
   **Then** it asserts `terminalBaseline` when the final reading is rejected noise — AUD2-FR34

3. **Given** existing `@Tags critical` normalizer tests
   **When** this story ships
   **Then** `flutter test --tags critical` passes

**Covers:** AUD2-FR1 · AUD2-FR34 · AUD2-NFR1 · diagnostic-ingestion-pedometer.md #1 (Quick fix Q1)

**Depends on:** Epics 21–28 done. First story in Epic 29 (atomic E-B bundle — do not merge 29-2/29-3 out of sequence).

**Out of scope:** Live drain reset forwarding (29-2), atomic txn collect (29-3), drain/calculator unification (29-5), version bump (Epic 29 close → minor+1, build+1).

## Tasks / Subtasks

- [x] **Sub-task A — Verify production fix** (AC: #1)
  - [x] Read fully: `lib/data/datasources/step_normalizer.dart` (`normalizeReadings`, return `terminalBaseline`)
  - [x] Confirm return uses `baseline ?? initialBaseline` — **not** a per-iteration `lastCumulative`
  - [x] Confirm `baseline` advances only after accepted increment (`increment != null` path, L83)
  - [x] Read `background_collector.dart` L121–127 — `setBaseline(cumulative: result.terminalBaseline)` unchanged
  - [x] If fix missing, apply one-line change per Dev Notes; otherwise skip code change
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Regression tests** (AC: #2, #3)
  - [x] Read `test/data/datasources/step_normalizer_test.dart` — `@Tags(['critical'])` library
  - [x] Dedicated test `terminalBaseline reflects last accepted baseline not rejected reading` (L388) already covers AC #1 last-reading-is-noise scenario — **keep it**
  - [x] Extend `rejects small counter dips as glitches` (L266): capture full `StepNormalizationResult`, assert `terminalBaseline == 1055` (last accepted after middle noise + final valid reading)
  - [x] Optional: add variant where **last** reading is noise-only batch ending on dip — must not duplicate L388 if redundant; prefer extending L266 with explicit comment linking AUD2-FR34
  - [x] Run `flutter test test/data/datasources/step_normalizer_test.dart --tags critical`
  - [x] Run `flutter test --tags critical`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Diagnostic closure** (AC: #1)
  - [x] Update `planning-artifacts/audits_2/diagnostic-ingestion-pedometer.md` #1 status → `fixed` with story ref
  - [x] Update `planning-artifacts/audits_2/README.md` row for diagnostic 07 if present
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### ⚠️ Partial implementation (verify first — do not re-fix blindly)

Commit `febd523` (2026-07-24, midnight split hotfix) **already shipped** the core fix:

- `terminalBaseline: baseline ?? initialBaseline` in `step_normalizer.dart` L118
- New test `terminalBaseline reflects last accepted baseline not rejected reading` L388–415

**Remaining gaps for this story:**

| Gap | Action |
|-----|--------|
| `rejects small counter dips` (L266) asserts buckets only, not `terminalBaseline` | Extend per AC #2 |
| Diagnostic still `open` | Close in Sub-task C |
| `StepIncrementCalculator` class doc L3–5 says baseline "always advances to latest reading" | **Out of scope** (29-5 / doc pass) — do not change calculator semantics here |

### Root cause (read before editing)

**Bug (pre-fix):** `terminalBaseline` was derived from `lastCumulative` updated on **every** reading, including rejected noise (`increment == null` → `continue` without advancing `baseline`). Next collection cycle persisted a stale cumulative → **over-counting** on next valid delta.

**Scenario:**

1. Cycle N: baseline 5000 → 5100 (+100 credited, `baseline`=5100)
2. Last reading 5099 (noise) → rejected, `baseline` stays 5100
3. **Bug:** `terminalBaseline`=5099 persisted
4. Cycle N+1: delta from 5099 when hardware is ~5100 → phantom +1 on next step

[Source: `diagnostic-ingestion-pedometer.md` #1 · `epics-audits-2.md` AUD2-FR1]

### Current implementation (MUST preserve)

**Normalizer loop — baseline advance gate:**

```73:83:lib/data/datasources/step_normalizer.dart
      final increment = incrementCalculator.calculate(
        current: cumulativeSteps,
        baseline: baseline,
        elapsedSincePrevious: elapsedSincePrevious,
      );

      if (increment == null) {
        continue;
      }

      baseline = cumulativeSteps;
```

**Return — fixed terminal baseline:**

```106:119:lib/data/datasources/step_normalizer.dart
    return StepNormalizationResult(
      buckets: [
        for (final entry in bucketValues.entries)
          NormalizedStepBucket(
            // ...
          ),
      ],
      terminalBaseline: baseline ?? initialBaseline,
    );
```

**Collector persist path (unchanged this story):**

```121:127:lib/core/services/background_collector.dart
        final terminalBaseline = result.terminalBaseline;
        if (terminalBaseline != null) {
          await baselineRepository.setBaseline(
            provider: source.providerId,
            deviceId: source.deviceId,
            cumulative: terminalBaseline,
          );
        }
```

**Note:** Baseline upsert is **not yet transactional** with bucket upserts — that is Story 29-3. Do not add txn scope here.

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-20: all cumulative → bucket deltas via `StepNormalizer` | This story fixes persist baseline only — no repository/UI delta logic |
| D-25: `TimeProvider` in normalizer | Already injected via `clock` — do not add `DateTime.now()` |
| Single-writer ingest path | `BackgroundCollector` remains sole bucket writer |
| AUD2-NFR8: preserve strengths | Do not change bucket credit, midnight split, or rate-limit behaviour from `febd523` |

[Source: `architecture.md` §StepNormalizer D-20, §Anti-patterns]

### File structure requirements

| File | Action |
|------|--------|
| `lib/data/datasources/step_normalizer.dart` | Verify only (fix likely done) |
| `test/data/datasources/step_normalizer_test.dart` | Extend L266 test |
| `lib/core/services/background_collector.dart` | Read-only verify |
| `planning-artifacts/audits_2/diagnostic-ingestion-pedometer.md` | Status update |
| `planning-artifacts/audits_2/README.md` | Status sync if row exists |

**Do not touch:** `live_step_monitor.dart` (29-2), `sample_compaction_runner.dart` (29-4), `step_increment_calculator.dart` logic (29-5).

### Testing requirements

| Command | When |
|---------|------|
| `flutter test test/data/datasources/step_normalizer_test.dart --tags critical` | After test changes |
| `flutter test --tags critical` | Story verification (workspace default for normalizer) |

Test file uses `@Tags(['critical']) library;` at L1 — entire file runs with `--tags critical`.

**Test data reference for L266 extension:**

- Readings: 1000 → 1050 → 1049 (noise) → 1055 (valid)
- Expected buckets: single bucket value 55 (unchanged)
- Expected `terminalBaseline`: **1055** (last accepted cumulative, not 1049)

### Cross-story context (Epic 29)

| Story | Relationship |
|-------|--------------|
| 29-2 | Drain reset forwarding — depends on correct baseline from this story |
| 29-3 | Atomic txn for buckets + baseline — builds on persisted baseline correctness |
| 29-5 | Unifies drain gate with calculator — **do not** refactor drain here |

**Epic 29 ships in order 29-1 → 29-5.** No independent PRs for 29-2/29-3 before 29-1 is done.

### Git intelligence

Recent relevant commits:

| Commit | Relevance |
|--------|-----------|
| `febd523` | **Core 29-1 fix** + midnight split + `terminalBaseline` test |
| `453fd04` | audits_2 epics E29–E33 + readiness report |
| `402da81` | Version 0.12.1+31 — current base |

### Project context reference

- OK commit gate: sub-tasks A/B/C each get separate commit after Baptiste approval
- Tests: `flutter test --tags critical` for this story (normalizer is critical-tagged)
- Version bump: defer to Epic 29 close (minor+1 → `0.13.0+32` per epics-audits-2)
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 29-1]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-ingestion-pedometer.md` #1]
- [Source: `_bmad-output/planning-artifacts/implementation-readiness-report-2026-07-24.md`]
- [Source: `_bmad-output/planning-artifacts/architecture.md` §StepNormalizer, D-20]
- [Source: `lib/data/datasources/step_increment_calculator.dart` — noise rejection L51-56]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sub-task A: production fix verified in `febd523` — no code change needed
- Sub-task B: extended `rejects small counter dips as glitches` with `terminalBaseline == 1055`
- Sub-task C: diagnostic 07 marked `fixed` in README + diagnostic-ingestion-pedometer.md

### Completion Notes List

- AC #1: `terminalBaseline: baseline ?? initialBaseline` confirmed L118; collector persist path unchanged
- AC #2: L266 test now asserts full `StepNormalizationResult.terminalBaseline` (AUD2-FR34)
- AC #3: `flutter test --tags critical` — all pass (13 normalizer + full suite)
- No version bump (deferred to Epic 29 close per story scope)

### File List

- `test/data/datasources/step_normalizer_test.dart` (modified)
- `_bmad-output/planning-artifacts/audits_2/diagnostic-ingestion-pedometer.md` (modified)
- `_bmad-output/planning-artifacts/audits_2/README.md` (modified)
- `_bmad-output/implementation-artifacts/stories/29-1-fix-terminal-baseline-after-rejected-sensor-noise.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml` (modified)

### Change Log

- 2026-07-24: Story 29-1 complete — test extension + diagnostic closure (fix pre-shipped in febd523)
