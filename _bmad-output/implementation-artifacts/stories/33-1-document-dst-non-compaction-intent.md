# Story 33.1: Document DST Non-Compaction Intent

Status: done

<!-- audits_2 Epic 33 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 33-1 · diagnostic-fuseaux-jours-locaux.md #1 · AUD2-FR30 -->
<!-- Prerequisite: Epic 29–32 delivered · base 0.14.1+35 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **maintainer**,
I want explicit comments that DST days skip FR11 compaction by design,
So that no one "fixes" bucket counts and reintroduces double-counting.

## Acceptance Criteria

1. **Given** `lifecycle_compaction.dart` near `kHourlyBucketsPerDay` / `isComplete*` helpers
   **When** this story ships
   **Then** comment states DST transition days intentionally skip compaction — do not relax 12/24/288 without offset-aware math — AUD2-FR30

2. **Given** optional follow-up test
   **When** simulated DST incomplete day runs through completeness guards
   **Then** `isCompleteHourlyDayGroup` / `isCompleteFiveMinuteDayGroup` return false and no merge occurs (optional AC — implement if low cost)

3. **Given** diagnostic item #1 in `diagnostic-fuseaux-jours-locaux.md`
   **When** story ships
   **Then** marked `fixed` with story ref `33-1`
   **And** `audits_2/README.md` row D1 / diagnostic 05 doc item synced

**Covers:** AUD2-FR30 · diagnostic-fuseaux-jours-locaux.md #1 (Doc T1)

**Depends on:** Epic 29 (compaction safety — 29-4 insert-before-delete) and Epic 32 delivered. No code dependency on 33-2.

**Out of scope:**
- Changing bucket counts (12/24/288) or completeness logic
- Chart SQL upper bound (Story 33-2)
- `pubspec.yaml` version bump (**Epic 33 close** after 33-2 — patch+1 + README)
- My Data footprint copy about DST fine rows (optional note in diagnostic only — not required unless Baptiste asks)

## Tasks / Subtasks

- [x] **Sub-task A — DST non-compaction documentation** (AC: #1)
  - [x] Read fully: `lib/core/lifecycle/lifecycle_compaction.dart` (entire file — 481 lines)
  - [x] Read fully: `lib/core/lifecycle/sample_compaction_runner.dart` — confirm `isComplete*` guards at L173, L234, L298 (`continue` on incomplete — no merge)
  - [x] Add block comment above constants L6–8 (`kFiveMinuteBucketsPerHour`, `kHourlyBucketsPerDay`, `kFiveMinuteBucketsPerDay`) explaining:
    - Exact counts are FR11 completeness guards, not calendar-length assumptions
    - Spring-forward / fall-back local days rarely produce exactly 12/24/288 contiguous buckets
    - Offset transitions split groups via `_sameSampleIdentity` + `zoneOffset` in group keys
    - **Intentional fail-closed:** incomplete groups skip compaction; fine buckets retained
    - **Do not relax** counts without offset-aware bucket math — risk of cross-offset merge or double-count
  - [x] Add concise doc comment on each `isComplete*` function (L245, L272, L298) referencing the constant block — one line each, no duplicate essay
  - [x] **Do not** change any logic, constants, or function signatures
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Optional DST completeness test** (AC: #2)
  - [x] Read: `test/dev/lifecycle_compaction_test.dart`, `test/core/time/local_day_calculator_test.dart` (DST boundary L22–36)
  - [x] If low cost: add test group `DST incomplete day groups skip compaction` in `lifecycle_compaction_test.dart`:
    - Build 23 hourly buckets (spring-forward day) with same identity + consecutive UTC hours → `isCompleteHourlyDayGroup` → `false`
    - Optionally 287 five-minute buckets → `isCompleteFiveMinuteDayGroup` → `false`
    - Assert `mergeHourlyBucketsToDaily` / `mergeFiveMinuteBucketsToDaily` throw if called directly (existing guard)
  - [x] Skip sub-task B if comments-only is sufficient — note skip reason in Dev Agent Record
  - [x] Run: `flutter test test/dev/lifecycle_compaction_test.dart` (if B implemented)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Diagnostic closure** (AC: #3)
  - [x] Update `diagnostic-fuseaux-jours-locaux.md` #1 → `fixed` (33-1); refresh synthèse row + statut global if all items closed
  - [x] Sync `audits_2/README.md`: D1 row → `fixed`; diagnostic 05 doc count → 0 open; E33 progress note
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Silent fail-closed behavior:** DST transition days almost never satisfy exact bucket counts (12 per local hour, 24 per local day, 288 per local day). Compaction skips these days **by design** — safe, but undocumented. A maintainer seeing "only 23 hourly buckets" may "fix" the count and reintroduce incorrect merges or double-counting.

**Mechanisms already in place (do not break):**

| Mechanism | Location | DST effect |
|-----------|----------|------------|
| Exact count required | `lifecycle_compaction.dart:6-8` | Spring-forward ≠ 24 local hours → `length != 24` |
| Identity includes offset | `lifecycle_compaction.dart:132-136` | `_sameSampleIdentity` requires matching `zoneOffset` |
| Group keys include offset | `lifecycle_compaction.dart:455-479` | `provider\|deviceId\|zoneOffset\|localBucket` |
| Fixed UTC contiguity | `lifecycle_compaction.dart:138-149` | +5 min / +1 h breaks on gaps or duplicate local slots |
| Runner skips incomplete | `sample_compaction_runner.dart:173,234,298` | `if (!isComplete*) continue;` — no delete |
| Merge throws if incomplete | `lifecycle_compaction.dart:329-335,372-377,416-421` | `ArgumentError` last-resort guard |

**Spring-forward scenario:** Fewer than 24 local hourly buckets → `isCompleteHourlyDayGroup` false → compaction runner `continue` → fine rows preserved.

**Offset transition scenario:** Samples before/after DST carry different stored `zone_offset` (captured at ingestion — `step_normalizer.dart:52,105`) → separate group keys → no cross-offset merge.

**Existing test anchor:** `local_day_calculator_test.dart:22-36` — two offsets on DST boundary yield distinct local days. Does **not** cover compaction completeness — optional sub-task B fills gap.

**Product impact:** More 5min/hourly rows retained on DST days — marginal DB growth; charts remain correct via `finestResolutionTotal` read path (diagnostic 08).

[Source: `diagnostic-fuseaux-jours-locaux.md` #1 · `epics-audits-2.md` AUD2-FR30]

### Recommended comment placement

**Primary block (required)** — insert above L6:

```dart
/// FR11 completeness uses fixed bucket counts (12 / 24 / 288), not live calendar
/// length. DST transition days intentionally skip compaction:
/// - Spring-forward: fewer local hourly/five-minute slots → group never "complete"
/// - Offset change: `_sameSampleIdentity` + group keys split rows by stored `zoneOffset`
/// Incomplete groups are skipped by [SampleCompactionRunner] (fail closed); fine buckets
/// stay until a complete group exists. Do NOT relax these counts without offset-aware
/// bucket math — risks cross-offset merge or double-counting in aggregates.
```

**Per-function (required, brief):** e.g. on `isCompleteHourlyDayGroup`:

```dart
/// True only for exactly [kHourlyBucketsPerDay] consecutive hourly buckets in one local
/// day (same identity). DST days typically fail — see constants comment above.
```

Mirror pattern for `isCompleteFiveMinuteHourGroup` and `isCompleteFiveMinuteDayGroup`.

**Do NOT:**
- Change `kFiveMinuteBucketsPerHour`, `kHourlyBucketsPerDay`, or `kFiveMinuteBucketsPerDay`
- Add offset-aware dynamic counts (future epic scope — not this story)
- Modify `sample_compaction_runner.dart` logic (comments there only if a one-line cross-ref helps — prefer keeping docs in `lifecycle_compaction.dart`)
- Touch chart queries (`_step_chart_queries.dart` — Story 33-2)

### Architecture compliance

| Rule | Application |
|------|-------------|
| NFR-8 / AUD2-NFR8 | Preserve FR11 completeness guards and additive upsert semantics from Epic 29 |
| Architecture §Time semantics | Per-row immutable `zone_offset`; local day from stored offset — comments must align |
| Architecture §Lifecycle | Tiered downsampling table (5min → hourly → daily) — counts match doc |
| D-25 | No new `DateTime.now()` — doc-only story |
| OK commit gate | Sub-tasks A→C with separate commits after Baptiste approval |
| Agent tests | If logic unchanged: `flutter test --tags critical`; if test added: `flutter test test/dev/lifecycle_compaction_test.dart` |

[Source: `architecture.md` §Time semantics, §Lifecycle · Story 29-4 compaction safety]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/lifecycle/lifecycle_compaction.dart` | **UPDATE** — block + function doc comments only |
| `test/dev/lifecycle_compaction_test.dart` | **UPDATE (optional)** — DST incomplete group test |
| `planning-artifacts/audits_2/diagnostic-fuseaux-jours-locaux.md` | Close #1 → `fixed` |
| `planning-artifacts/audits_2/README.md` | Sync D1, diagnostic 05 status |

**Verify only (no edits unless cross-ref needed):**
- `lib/core/lifecycle/sample_compaction_runner.dart` — understand `continue` on incomplete
- `test/core/time/local_day_calculator_test.dart` — existing DST local-day test

**Do not touch:** `sample_compaction_runner.dart` logic, chart queries, downsampling tests, `pubspec.yaml`.

### Testing requirements

| Verify | Command |
|--------|---------|
| Critical gate (no logic change) | `flutter test --tags critical` |
| Optional DST completeness test | `flutter test test/dev/lifecycle_compaction_test.dart` |

Do **not** run bare `flutter test`.

**Regression focus:** All existing compaction/downsample tests must pass unchanged — this story adds comments only (+ optional assert on already-false completeness).

### Previous story intelligence

| Learning | Impact on 33-1 |
|----------|----------------|
| 32-5: OK commit gate A→D; diagnostic + README sync on close | Mirror A→C pattern in sub-task C |
| 32-5: tracker = `sprint-status-audits-2.yaml` | Update same file; Epic 33 opens here |
| 29-4: `isComplete*` + insert-before-delete — do not weaken guards | Comments must reinforce, not relax |
| 29-4: `step_repository_downsample_test.dart` regression suite | Must stay green — no runner changes |
| Epic 32 closed at `0.14.1+35` | Base version for Epic 33 |

[Source: `stories/32-5-test-hook-and-deterministic-migration-v3.md` · `stories/29-4-guard-compaction-delete-until-insert-succeeds.md`]

### Cross-story context (Epic 33)

| Story | Status | Relationship |
|-------|--------|--------------|
| **33-1** | **this story** | Doc DST compaction intent — no chart changes |
| 33-2 | backlog | Chart UTC rollover comments + optional SQL upper bound |

**Epic 33 close after 33-2:** bump `pubspec.yaml` patch+1 (`0.14.1+35` → `0.14.2+36` per tracker) + `README.md` project status row.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `cdb316f` | Epic 32 close — `0.14.1+35`; Epic 33 starts next |
| `2bff52a` | Diagnostic close pattern (32-5-D) — replicate for fuseaux #1 |
| `29-4` commits | Compaction runner `isComplete*` skip semantics — document, don't change |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.14.1+35`.

### Latest tech / library notes

- **No new packages or APIs** — documentation-only story.
- **Dart doc comments (`///`)** preferred on public constants/functions; block comment for multi-line design intent above const group.
- **Optional test:** Use existing `_sample()` helper in `lifecycle_compaction_test.dart` — tag `@Tags(['slow'])` already on file; no new test tags required.
- **Future offset-aware compaction:** If ever needed, requires design epic — explicit out of scope; comments must say "do not relax without offset-aware math".

### Project context reference

- OK commit gate: sub-tasks with separate commits after Baptiste approval
- Tests: `flutter test --tags critical` default; localized file if test added
- Version bump: Epic 33 close — after 33-2 dev + review
- Chat French; story/doc English per BMAD config

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 33-1, AUD2-FR30]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-fuseaux-jours-locaux.md` #1]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` D1, diagnostic 05]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-downsampling-compaction-fr11.md` — related FR11 guards]
- [Source: `lib/core/lifecycle/lifecycle_compaction.dart`]
- [Source: `lib/core/lifecycle/sample_compaction_runner.dart`]
- [Source: `test/dev/lifecycle_compaction_test.dart`]
- [Source: `test/core/time/local_day_calculator_test.dart`]
- [Source: `_bmad-output/implementation-artifacts/stories/29-4-guard-compaction-delete-until-insert-succeeds.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/32-5-test-hook-and-deterministic-migration-v3.md`]

## Dev Agent Record

### Agent Model Used

Composer (create-story) · Composer (dev-story)

### Debug Log References

- Sub-task B implemented (not skipped): DST incomplete group tests added alongside existing 287-bucket guard test.

### Completion Notes List

- Added FR11/DST block comment above `k*BucketsPer*` constants and brief doc comments on all three `isComplete*` functions — no logic changes.
- Added test group `DST incomplete day groups skip compaction` with 23-hourly and 287-five-minute spring-forward scenarios.
- Closed diagnostic 05 item #1 → `fixed` (33-1); synced `audits_2/README.md` D1 + E33 progress.
- Verify: `flutter test test/dev/lifecycle_compaction_test.dart` + `flutter test --tags critical` — all green.

### File List

- `lib/core/lifecycle/lifecycle_compaction.dart`
- `test/dev/lifecycle_compaction_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-fuseaux-jours-locaux.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`
- `_bmad-output/implementation-artifacts/stories/33-1-document-dst-non-compaction-intent.md`

## Change Log

- 2026-07-25: Story 33-1 created — document DST non-compaction intent in lifecycle_compaction.dart
- 2026-07-25: Story 33-1 implemented — DST comments, optional tests, diagnostic 05 closed
- 2026-07-25: Story 33-1 review passed — marked done
