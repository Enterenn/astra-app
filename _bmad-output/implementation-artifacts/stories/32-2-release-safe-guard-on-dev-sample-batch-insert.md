# Story 32.2: Release-Safe Guard on Dev Sample Batch Insert

Status: done

<!-- audits_2 Epic 32 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 32-2 · diagnostic-couche-donnees.md #3 · AUD2-FR6 -->
<!-- Prerequisite: Story 32-1 done · Epic 29–31 delivered -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **product owner**,
I want dev-only sample injection blocked in release builds,
So that production builds cannot accidentally bypass ingestion safeguards.

## Acceptance Criteria

1. **Given** a release build (`!kDebugMode`)
   **When** `insertDevSamplesBatch` is called
   **Then** a runtime `StateError` is thrown before any DB work — not a stripped `assert` — AUD2-FR6
   **And** the error message remains `'insertDevSamplesBatch is only available in debug builds'`

2. **Given** debug/test builds (`kDebugMode == true`, including `flutter test`)
   **When** dev batch insert is used
   **Then** existing test/dev behaviour is preserved (txn insert, optional `replaceExistingSteps` delete)

3. **Given** all existing repository tests that call `insertDevSamplesBatch`
   **When** this ships
   **Then** they still pass unchanged (no caller migration)

4. **Given** diagnostic item #3 in `diagnostic-couche-donnees.md`
   **When** story ships
   **Then** #3 marked `fixed` with story ref
   **And** `audits_2/README.md` P0-03 row synced to `fixed` (32-2)

**Covers:** AUD2-FR6 · diagnostic-couche-donnees.md #3 · Quick fix Q3

**Depends on:** Story 32-1 (same file, different region — no conflict)

**Out of scope:**
- Relocating `insertDevSamplesBatch` off the production repository (future hardening — diagnostic mentions debug-only impl)
- Changing `DataInjectService` guard in `test/dev/data_inject_service.dart` (defensive depth only; stays as-is)
- Privacy disclaimer / SQLCipher (32-3)
- Goal source / `isDatabaseOpen` (32-4)
- `testHookAfterDeleteSamples` contract cleanup (32-5)
- `pubspec.yaml` version bump (Epic 32 close = patch+1)

## Tasks / Subtasks

- [x] **Sub-task A — Replace assert wrapper with runtime guard** (AC: #1, #2)
  - [x] Read fully: `lib/data/repositories/step/step_ingestion_repository.dart` L96-132
  - [x] Remove the `assert(() { ... return true; }())` block
  - [x] Add at method entry (before `_session.run`):
  - [x] Keep doc comment, txn scope, and `replaceExistingSteps` logic unchanged
  - [x] **Stop → review brief → wait for Baptiste OK → commit** — `ae04f84`

- [x] **Sub-task B — Regression tests** (AC: #1, #2, #3)
  - [x] Create `test/data/repositories/step_ingestion_repository_dev_guard_test.dart`:
  - [x] Run: `flutter test test/data/repositories/step_ingestion_repository_dev_guard_test.dart`
  - [x] Run: `flutter test --tags critical`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Diagnostic close** (AC: #4)
  - [x] Update `diagnostic-couche-donnees.md` #3 → `fixed` (32-2)
  - [x] Sync `audits_2/README.md` P0-03 row → `fixed` (32-2)
  - [x] Update README inventory table row #3 statut → `fixed` (32-2)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Current guard is release-inert:** Flutter strips `assert` in release/profile builds. The guard at L107-114 never runs in production APK/IPA.

```107:114:lib/data/repositories/step/step_ingestion_repository.dart
    assert(() {
      if (!kDebugMode) {
        throw StateError(
          'insertDevSamplesBatch is only available in debug builds',
        );
      }
      return true;
    }());
```

**Why this matters:** `insertDevSamplesBatch` bypasses production ingestion safeguards:

| Production path | Dev batch path |
|-----------------|----------------|
| `upsertIngestionBucket` → `ON CONFLICT ... DO UPDATE SET value = value + excluded.value` | Direct `txn.insert` — no additive merge |
| Bucket identity enforced via unique index | Pre-built rows inserted as-is |
| Only `BackgroundCollector` intended caller | `DataInjectService` + unit tests |

**Accidental release call impact:** Silent raw inserts; with `replaceExistingSteps: true`, deletes all `type='steps'` rows then inserts — data loss + inconsistent totals.

**Call graph today (verified):**

| Location | Role |
|----------|------|
| `lib/data/repositories/step/step_ingestion_repository.dart` | **Only** `lib/` definition |
| `test/dev/data_inject_service.dart` | Dev inject (already has own `kDebugMode` guard on `runDevInject`) |
| `test/data/repositories/*_test.dart` (8 files) | Test fixtures |
| `test/presentation/cubits/my_data_cubit_import_test.dart` | Cubit import tests |

No production widget/cubit/service imports `insertDevSamplesBatch`. Guard is defence-in-depth for repository API surface left on `StepIngestionRepository` (Story 18-3 split).

[Source: `diagnostic-couche-donnees.md` #3 · `audits_2/README.md` P0-03 · AUD2-FR6]

### Recommended implementation

**Single-line behavioural change:** Move guard outside `assert`. Exact replacement from diagnostic:

```dart
if (!kDebugMode) {
  throw StateError('insertDevSamplesBatch is only available in debug builds');
}
```

**Preserve:**
- `import 'package:flutter/foundation.dart';` (already present for `kDebugMode`, `@visibleForTesting`)
- Transaction boundary inside `_session.run` (architecture D-24)
- Method signature and `replaceExistingSteps` semantics
- Doc comment L96-102 ("Dev/test only — DataInjectService and unit tests")

**Do NOT:**
- Add `@visibleForTesting` debug override (scope creep)
- Move method to `test/` (32-5 / future refactor territory)
- Change `StepIngestionRepositoryContract` (method not on contract — only `purge` there)
- Touch `upsertIngestionBucket` or Story 32-1 ID wiring

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-24 Transaction boundaries | Guard throws **before** `_session.run` — no partial txn |
| Agent rule #17 (dev tools) | Repository guard complements `test/dev/` relocation (Story 15-3); both layers intentional |
| Layering | One method, one file — `lib/data/repositories/step/` |
| Token economy | Minimal diff (~6 lines net) |

[Source: `architecture.md` § Transaction boundaries · Story 15-3 dev relocation notes]

### File structure requirements

| File | Action |
|------|--------|
| `lib/data/repositories/step/step_ingestion_repository.dart` | **UPDATE** — assert → runtime guard |
| `test/data/repositories/step_ingestion_repository_dev_guard_test.dart` | **NEW** — smoke + structural regression |
| `planning-artifacts/audits_2/diagnostic-couche-donnees.md` | Close #3 |
| `planning-artifacts/audits_2/README.md` | P0-03 + inventory #3 → fixed |

**Do not touch:** `sample_id_generator.dart`, migrations, `DataInjectService` logic, existing test call sites, contract interface.

### Testing requirements

| Verify | Command |
|--------|---------|
| New guard tests | `flutter test test/data/repositories/step_ingestion_repository_dev_guard_test.dart` |
| Critical gate | `flutter test --tags critical` |

Do **not** run bare `flutter test`.

**Release-path note:** `kDebugMode` is a compile-time constant (`!bool.fromEnvironment('dart.vm.product')`). Unit tests always run with `kDebugMode == true`. Structural test (no `assert(() {` wrapper) is the project-standard regression for this guard class. Optional manual check: `flutter build apk --release` — method unreachable from UI today.

**Regression focus:** All 8 existing test files calling `insertDevSamplesBatch` must stay green without modification.

### Previous story intelligence

| Learning | Impact on 32-2 |
|----------|----------------|
| 32-1: same file `step_ingestion_repository.dart` | Edit only `insertDevSamplesBatch` block (L103+); do not touch `upsertIngestionBucket` |
| 32-1: OK commit gate A→D | Follow A→C with separate commits |
| 32-1: diagnostic close pattern | Mirror #3 + README P0-03 sync in sub-task C |
| 15-3: dev tools in `test/dev/` | Repository method remains on production class — runtime guard required |
| 18-3: `insertDevSamplesBatch` debug-only on ingestion repo | Story 18-3 said "keep assert guard" — **superseded by AUD2-FR6** |

[Source: `stories/32-1-align-ingestion-sample-ids-with-bucket-identity-index.md` · `stories/15-3-relocate-dev-tooling-to-test-dev.md`]

### Cross-story context (Epic 32)

| Story | Status | Relationship |
|-------|--------|--------------|
| 32-1 | done | ID alignment — same repo file, orthogonal region |
| **32-2** | **this story** | Release guard — quick fix |
| 32-3 | backlog | Privacy disclaimer or SQLCipher |
| 32-4 | backlog | Goal single source + safe DB open check |
| 32-5 | backlog | Test hook + migration v3 clock |

**Epic 32 close after 32-5:** bump `pubspec.yaml` patch+1 + `README.md` per sprint tracker.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `384ce70` | Story 32-1 closed — latest Epic 32 work on same file |
| `3989762`, `aadd78f` | 32-1 ingestion ID wiring — do not revert |
| Story 15-3 (era) | Dev inject relocated to `test/dev/` — repository API still exposed |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.14.0+34`.

### Latest tech / library notes

- **No package upgrade** — `kDebugMode` from `package:flutter/foundation.dart` (already imported).
- **Flutter assert semantics (2026):** `assert` expressions are removed in release/profile builds; only runtime `if` guards execute. This is why AUD2-FR6 explicitly forbids assert-based protection for security-relevant dev gates.
- **`kDebugMode` in tests:** Always `true` under `flutter test` — structural regression test is correct approach; do not attempt dynamic toggling.

### Project context reference

- OK commit gate: sub-tasks A→C, separate commits after Baptiste approval
- Tests: targeted file run + `flutter test --tags critical`
- Version bump: Epic 32 close (patch+1) — not per story

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 32-2, AUD2-FR6]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-couche-donnees.md` #3]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` P0-03]
- [Source: `_bmad-output/planning-artifacts/architecture.md` § Transaction boundaries]
- [Source: `_bmad-output/implementation-artifacts/stories/32-1-align-ingestion-sample-ids-with-bucket-identity-index.md`]
- [Source: `lib/data/repositories/step/step_ingestion_repository.dart` L96-132]
- [Source: `test/dev/data_inject_service.dart`]
- [Source: `test/helpers/step_test_fixtures.dart`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Sub-task A: replaced `assert` wrapper with runtime `if (!kDebugMode) throw StateError` before `_session.run` — committed `ae04f84`
- Sub-task B: smoke insert + structural source guard test; critical suite green
- Sub-task C: diagnostic #3, README P0-03, inventory #3, Q3 marked fixed (32-2)

### File List

- `lib/data/repositories/step/step_ingestion_repository.dart` (modified — A)
- `test/data/repositories/step_ingestion_repository_dev_guard_test.dart` (new — B)
- `_bmad-output/planning-artifacts/audits_2/diagnostic-couche-donnees.md` (modified — C)
- `_bmad-output/planning-artifacts/audits_2/README.md` (modified — C)
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml` (modified — tracking)
- `_bmad-output/implementation-artifacts/stories/32-2-release-safe-guard-on-dev-sample-batch-insert.md` (modified — story)

## Change Log

- 2026-07-25: Story 32-2 — release-safe runtime guard on `insertDevSamplesBatch`; regression tests; audit P0-03 closed
