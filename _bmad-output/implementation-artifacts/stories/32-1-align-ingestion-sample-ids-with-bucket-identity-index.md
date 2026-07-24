# Story 32.1: Align Ingestion Sample IDs with Bucket Identity Index

Status: review

<!-- audits_2 Epic 32 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 32-1 · diagnostic-couche-donnees.md #2, #4 · AUD2-FR5 · AUD2-FR13 -->
<!-- Prerequisite: Epic 29–31 delivered · Story 15-4 established SampleIdGenerator patterns -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want ingestion sample IDs to include type and resolution,
So that future multi-type samples cannot collide on the same primary key.

## Acceptance Criteria

1. **Given** `SampleIdGenerator.deterministicFromIngestionBucket`
   **When** generating an ID
   **Then** `type` and `resolution` participate in the hash, aligned with `idx_bucket_identity` — AUD2-FR5
   **And** provider/device identity strings are lowercased before regex normalization — AUD2-FR13

2. **Given** two buckets sharing `startTimeUtc`, `provider`, and `deviceId` but differing in `type` or `resolution`
   **When** IDs are generated
   **Then** the IDs are distinct (no PK collision)

3. **Given** Phase 0 step ingestion (`type = steps`, `resolution = 5min`, lowercase provider/device constants)
   **When** this ships
   **Then** generated IDs match the legacy formula (no DB migration required)
   **And** existing rows keep their stored `id`; upserts on the same bucket identity still merge via `ON CONFLICT` without changing stored `id`

4. **Given** `StepIngestionRepository.upsertIngestionBucket`
   **When** building the model
   **Then** it passes `bucket.type` and `bucket.resolution` into `deterministicFromIngestionBucket`

5. **Given** unit tests
   **When** this story ships
   **Then** `sample_id_generator_test.dart` covers: multi-type/resolution distinctness, case-insensitive provider/device, legacy steps/5min stability
   **And** `step_repository_upsert_test.dart` still passes (additive merge + id preservation)
   **And** `flutter test --tags critical` passes

6. **Given** diagnostic items #2 and #4 in `diagnostic-couche-donnees.md`
   **When** story ships
   **Then** both marked `done` with story ref
   **And** `audits_2/README.md` P0-02 row synced to `fixed` (32-1)

**Covers:** AUD2-FR5 · AUD2-FR13 · diagnostic-couche-donnees.md #2, #4 · Quick fixes Q4, Q5

**Depends on:** Epic 29 (persist integrity) · Story 15-4 (`SampleIdGenerator` + deterministic ids)

**Out of scope:**
- `insertDevSamplesBatch` release guard (32-2)
- SQLCipher / privacy disclaimer (32-3)
- Goal source / `isDatabaseOpen` (32-4)
- `testHookAfterDeleteSamples` contract cleanup (32-5)
- DB migration to rewrite existing PKs (not needed — see backward-compat strategy)
- `pubspec.yaml` version bump (Epic 32 close = patch+1)

## Tasks / Subtasks

- [x] **Sub-task A — Extend `deterministicFromIngestionBucket` signature + algorithm** (AC: #1, #2, #3)
  - [x] Read fully: `lib/core/ids/sample_id_generator.dart`, `lib/core/ids/sample_id_generator.dart` companion `deterministicFromMergedBucket` (resolution suffix pattern)
  - [x] Add required params: `type`, `resolution`
  - [x] Normalize: `provider.toLowerCase()`, `deviceId.toLowerCase()` before `RegExp(r'[^a-z0-9]')`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Wire repository call site** (AC: #4)
  - [x] Update `lib/data/repositories/step/step_ingestion_repository.dart` L41-45 to pass `type: bucket.type`, `resolution: bucket.resolution`
  - [x] Update direct call sites in tests/dev that invoke the static helper:
    - `test/dev/data_inject_service.dart` L66-70
    - `test/data/repositories/step_repository_downsample_test.dart` L207-211
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests** (AC: #2, #3, #5)
  - [x] Extend `test/core/ids/sample_id_generator_test.dart`:
    - Same start/provider/device, different `type` → distinct ids
    - Same start/provider/device, different `resolution` → distinct ids
    - `ProviderA` + `DeviceX` vs `providera` + `devicex` → same id
    - Legacy golden: steps + 5min + `internal_phone` + `smartphone` → exact legacy string (capture current output before change)
  - [x] Run: `flutter test test/core/ids/sample_id_generator_test.dart`
  - [x] Run: `flutter test test/data/repositories/step_repository_upsert_test.dart`
  - [x] Run: `flutter test --tags critical`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Diagnostic close** (AC: #6)
  - [x] Update `diagnostic-couche-donnees.md` #2, #4 → `done` (32-1)
  - [x] Sync `audits_2/README.md` P0-02 row → `fixed` (32-1)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Gap 1 — PK hash narrower than bucket identity:** `idx_bucket_identity` is UNIQUE on 6 columns; ingestion PK hash uses only 3 inputs.

```30:37:lib/core/ids/sample_id_generator.dart
  static String deterministicFromIngestionBucket({
    required DateTime startTimeUtc,
    required String provider,
    required String deviceId,
  }) {
    final identity = '$provider$deviceId'.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${deterministicFromStartUtc(startTimeUtc)}-$identity';
  }
```

```85:93:lib/core/database/migrations.dart
    CREATE UNIQUE INDEX IF NOT EXISTS idx_bucket_identity
      ON timeseries_samples (
        provider,
        device_id,
        type,
        start_time,
        end_time,
        resolution
      )
```

**Collision scenario:** Two samples at the same `(provider, device_id, start_time, end_time)` with different `type` (e.g. `steps` vs future `heart_rate`) would share the same PK `id` but differ on the unique index → SQLite rejects the second insert instead of allowing coexistence.

**Mitigation today:** Only `steps` / `5min` ingested — latent until multi-type arrives.

**Gap 2 — Case-sensitive identity strip:** `RegExp(r'[^a-z0-9]')` strips uppercase rather than normalizing — `ProviderA` vs `providera` produce different ids.

**Internal inconsistency:** `deterministicFromMergedBucket` already appends `resolution`; ingestion helper does not include `type`/`resolution`.

| Reference | Detail | Gap |
|-----------|--------|-----|
| `sample_id_generator.dart:30-37` | 3-field hash | Missing type/resolution |
| `migrations.dart:85-93` | 6-column unique index | Hash misaligned |
| `step_ingestion_repository.dart:41-45` | Call without type/resolution | Wiring gap |
| `deterministicFromMergedBucket` | Resolution suffix | Pattern to mirror |
| `diagnostic-couche-donnees.md` #2, #4 | Documented | This story closes |

[Source: `diagnostic-couche-donnees.md` #2, #4 · `epics-audits-2.md` AUD2-FR5, AUD2-FR13]

### Recommended implementation

**1. Algorithm (legacy-stable for Phase 0 defaults):**

| Input | Rule |
|-------|------|
| `provider`, `deviceId` | `.toLowerCase()` then strip non `[a-z0-9]` |
| `type`, `resolution` | Required params; `.toLowerCase()` in suffix segment |
| Phase 0 default (`steps` + `5min`) | Return legacy `{start36}-{identity}` — **no migration** |
| Non-default type/resolution | Append `-{type}-{resolution}` after identity |

**Why legacy branch:** All production rows today are `steps`/`5min`. Changing their PK formula would orphan ids on upsert (conflict updates `value` only — stored `id` unchanged) and break export round-trip expectations from Story 15-4. The branch preserves byte-identical ids for the only ingested tier today while fixing the multi-type bomb.

**2. Repository wiring:**

```dart
id: SampleIdGenerator.deterministicFromIngestionBucket(
  startTimeUtc: bucket.startTimeUtc,
  provider: bucket.provider,
  deviceId: bucket.deviceId,
  type: bucket.type,
  resolution: bucket.resolution,
),
```

**3. What NOT to change:**

| Behaviour | Reason |
|-----------|--------|
| `ON CONFLICT ... DO UPDATE SET value = value + excluded.value` | Additive upsert semantics frozen |
| `deterministicFromMergedBucket` | Compaction ids already correct |
| CSV import `INSERT OR IGNORE` on `id` | D-16 import path — orthogonal |
| `idx_bucket_identity` schema | No migration bump |
| `insertDevSamplesBatch` guard | Story 32-2 |

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-19 bucket identity UNIQUE | PK hash must cover all identity columns for non-default types |
| D-16 dual idempotency | Import on `id`; ingestion upsert on bucket identity — unchanged |
| D-25 TimeProvider | Static deterministic helpers — no clock change |
| Layering | Change confined to `core/ids` + ingestion repository + tests |
| Token economy | Minimal diff; no new classes |

[Source: `architecture.md` § Bucket identity · Story 15-4 dev notes]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/ids/sample_id_generator.dart` | **UPDATE** — add params, lowercasing, conditional suffix |
| `lib/data/repositories/step/step_ingestion_repository.dart` | **UPDATE** — pass type/resolution |
| `test/core/ids/sample_id_generator_test.dart` | **UPDATE** — collision + legacy + case tests |
| `test/dev/data_inject_service.dart` | **UPDATE** — pass type/resolution at call site |
| `test/data/repositories/step_repository_downsample_test.dart` | **UPDATE** — pass type/resolution at call site |
| `planning-artifacts/audits_2/diagnostic-couche-donnees.md` | Close #2, #4 |
| `planning-artifacts/audits_2/README.md` | P0-02 → fixed |

**Do not touch:** `migrations.dart`, `sample_compaction_runner.dart`, CSV codec, `BackgroundCollector`, compaction tests (unless compile errors from signature change).

### Testing requirements

| Verify | Command |
|--------|---------|
| ID generator unit tests | `flutter test test/core/ids/sample_id_generator_test.dart` |
| Upsert merge + id preservation | `flutter test test/data/repositories/step_repository_upsert_test.dart` |
| Critical gate | `flutter test --tags critical` |

**Note:** `sample_id_generator_test.dart` and `step_repository_upsert_test.dart` are `@Tags(['slow'])` — run files explicitly.

Do **not** run bare `flutter test`.

**Regression focus:** `step_repository_upsert_test.dart` test `merges duplicate bucket increments without replacing the id` — must still pass after legacy branch.

### Previous story intelligence

| Learning | Impact on 32-1 |
|----------|----------------|
| 15-4: ingestion uses `deterministicFromIngestionBucket`; compaction uses `deterministicFromMergedBucket` | Mirror resolution-suffix pattern; do not conflate helpers |
| 15-4: deterministic ids for export/import round-trip | Legacy branch mandatory for steps/5min |
| 29-3: additive upsert + txn baseline | Upsert SQL untouched |
| 31-6: OK commit gate, sub-task stops | Follow A→D with separate commits |
| Epic 31 closed at 0.14.0+34 | Epic 32 starts from that base |

[Source: `stories/15-4-replace-uuid-with-timestamp-based-bucket-ids.md` · `stories/31-6-harden-profile-notification-toggle-concurrency.md`]

### Cross-story context (Epic 32)

| Story | Status | Relationship |
|-------|--------|--------------|
| **32-1** | **this story** | ID alignment — first Epic 32 story |
| 32-2 | backlog | Dev batch release guard — independent file region |
| 32-3 | backlog | Privacy disclaimer or SQLCipher — product decision |
| 32-4 | backlog | Goal single source + safe DB open check |
| 32-5 | backlog | Test hook + migration v3 clock |

**Epic 32 close after 32-5:** bump `pubspec.yaml` patch+1 + `README.md` per sprint tracker.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `5f4be10` | Latest on main — notification init guard (Epic 31 tail) |
| Story 15-4 commits (era) | Introduced `SampleIdGenerator` + provider/device suffix |
| Story 29-3 (era) | Atomic upsert/baseline — do not touch collector txn |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.14.0+34`.

### Latest tech / library notes

- **No package upgrade** — pure Dart string hashing change.
- **sqflite ^2.4.2:** PK (`id`) and UNIQUE (`idx_bucket_identity`) are independent; upsert conflict target is the 6-column unique index, not PK.
- **Future multi-type ingestion:** When adding a non-`steps` type, the new suffix branch activates automatically — no further ID work required.

### Project context reference

- OK commit gate: sub-tasks A→D, separate commits after Baptiste approval
- Tests: targeted file runs + `flutter test --tags critical`
- Version bump: Epic 32 close (patch+1) — not per story

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 32-1, AUD2-FR5, AUD2-FR13]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-couche-donnees.md` #2, #4]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` P0-02]
- [Source: `_bmad-output/planning-artifacts/architecture.md` § Bucket identity]
- [Source: `_bmad-output/implementation-artifacts/stories/15-4-replace-uuid-with-timestamp-based-bucket-ids.md`]
- [Source: `lib/core/ids/sample_id_generator.dart`]
- [Source: `lib/core/database/migrations.dart` L85-93]
- [Source: `lib/data/repositories/step/step_ingestion_repository.dart` L35-55]
- [Source: `lib/data/models/normalized_step_bucket.dart`]
- [Source: `test/core/ids/sample_id_generator_test.dart`]
- [Source: `test/data/repositories/step_repository_upsert_test.dart`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Legacy branch uses string literals `'steps'`/`'5min'` (avoids core→data import from `sample_id_generator.dart`).

### Completion Notes List

- Extended `deterministicFromIngestionBucket` with `type`/`resolution`, lowercased provider/device, legacy-stable branch for Phase 0 defaults.
- Wired `StepIngestionRepository` + test/dev call sites with new params.
- Added collision, case-insensitivity, and legacy golden tests; upsert id-preservation regression green.
- Closed diagnostic #2/#4 and synced README P0-02 to fixed (32-1).
- Verify: `sample_id_generator_test.dart`, `step_repository_upsert_test.dart`, `flutter test --tags critical` — all pass.

### File List

- `lib/core/ids/sample_id_generator.dart`
- `lib/data/repositories/step/step_ingestion_repository.dart`
- `test/core/ids/sample_id_generator_test.dart`
- `test/dev/data_inject_service.dart`
- `test/data/repositories/step_repository_downsample_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-couche-donnees.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`

## Change Log

- 2026-07-25: Story 32-1 — align ingestion sample IDs with bucket identity index; legacy steps/5min preserved.
