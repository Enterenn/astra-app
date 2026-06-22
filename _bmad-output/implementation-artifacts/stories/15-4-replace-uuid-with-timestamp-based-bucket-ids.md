# Story 15.4: Replace uuid with Timestamp-Based Bucket IDs

Status: done

<!-- Refacto Epic 15 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 15-4 · refactoring-audit-master-v0.6.1.md §4 (uuid row) · REF-06 -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **maintainer**,
I want fewer runtime dependencies,
So that the APK is leaner and ID generation stays local-first.

## Acceptance Criteria

1. **Given** runtime sample `id` generation in production code  
   **When** refactored  
   **Then** IDs use a local scheme based on `microsecondsSinceEpoch.toRadixString(36)` — **not** the `uuid` package (REF-06)  
   **And** generation uses injected `TimeProvider` (architecture D-25) — **not** raw `DateTime.now()` in `lib/`  
   **And** `uuid` is removed from `pubspec.yaml`

2. **Given** `StepRepository.upsertIngestionBucket`  
   **When** inserting a new row  
   **Then** assigns a non-empty `TEXT` id via the shared generator  
   **And** duplicate bucket identity still merges `value` without replacing the existing `id` (unchanged upsert semantics)

3. **Given** `SampleCompactionRunner` (FR11 downsampling)  
   **When** creating merged hourly/daily rows  
   **Then** uses the same shared ID scheme — no `Uuid` import or constructor param  
   **And** multiple merges in one transaction cannot collide (sequence suffix or deterministic bucket-start id — see Dev Notes)

4. **Given** `TimeseriesCsvCodec` import validation  
   **When** a user imports an ASTRA CSV  
   **Then** **legacy UUID v4** ids still validate and import (FR-30 backward compatibility)  
   **And** **new base36 timestamp ids** also validate  
   **And** export → purge → import round-trip still passes for rows created after this change

5. **Given** `test/dev/data_inject_service.dart`  
   **When** generating 25,920 synthetic buckets  
   **Then** ids are unique without `uuid` (deterministic from `startTimeUtc` recommended)  
   **And** `package:uuid` is not imported anywhere under `lib/` or `test/`

6. **Given** existing ingestion, import/export, and downsampling tests  
   **When** run  
   **Then** all pass — no duplicate-ID collisions in normal ingest paths  
   **And** add/adjust tests proving new id format + legacy UUID import acceptance

7. **Given** `flutter pub get` after change  
   **When** dependency tree is inspected (`flutter pub deps` or `pubspec.lock`)  
   **Then** `uuid` is not a direct or transitive dependency

8. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 15 closes with patch+1 (`0.6.2+13` → `0.6.3+14`) when all Epic 15 stories are done

**Covers:** REF-06 · Audit §4 uuid row (P1) · ~35 KB APK savings (estimated)

## Tasks / Subtasks

- [x] **Sub-task A — Add shared `SampleIdGenerator`** (AC: #1)
  - [x] Read `TimeProvider`, `StepRepository`, `SampleCompactionRunner` **before editing**
  - [x] Create `lib/core/ids/sample_id_generator.dart`:
    - `String nextId()` — uses `_clock.snapshot().nowUtc.microsecondsSinceEpoch.toRadixString(36)` plus monotonic `_sequence` suffix when `> 0` calls share the same microsecond (e.g. `'${micros.toRadixString(36)}-${seq.toRadixString(36)}'`)
    - `static String deterministicFromStartUtc(DateTime startTimeUtc)` — `startTimeUtc.microsecondsSinceEpoch.toRadixString(36)` for bulk/dev inserts where each bucket has a unique `startTimeUtc`
    - Constructor: `SampleIdGenerator(TimeProvider clock)`
  - [x] Add unit tests in `test/core/ids/sample_id_generator_test.dart`: uniqueness under rapid `nextId()` burst, deterministic helper stability
  - [x] Run `flutter analyze` + `flutter test test/core/ids/sample_id_generator_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Wire `StepRepository` + `SampleCompactionRunner`** (AC: #2, #3)
  - [x] Replace `Uuid? uuid` constructor param with `SampleIdGenerator? idGenerator` on `StepRepository`; default `SampleIdGenerator(clock)`
  - [x] `upsertIngestionBucket`: deterministic ingestion id via shared generator (see collision fix commit)
  - [x] Remove `package:uuid/uuid.dart` import from `step_repository.dart`
  - [x] Refactor `SampleCompactionRunner`:
    - Remove `Uuid` dependency entirely
    - Merged-row ids via `deterministicFromMergedBucket` (resolution suffix)
    - `SampleCompactionRunner()` — no uuid/generator param
  - [x] Run `flutter test test/data/repositories/step_repository_upsert_test.dart test/data/repositories/step_repository_downsample_test.dart test/dev/lifecycle_compaction_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — CSV import backward compatibility** (AC: #4)
  - [x] Read `timeseries_csv_codec.dart` `_validateDataMap` — rename `_uuidPattern` → `_legacyUuidPattern`
  - [x] Add `_timestampIdPattern` (e.g. `^[0-9a-z]+(-[0-9a-z]+)?$`, case-insensitive) for new ids
  - [x] Accept id when **either** pattern matches; update error message to `'id must be a valid sample id'` (not "UUID")
  - [x] Add tests in `timeseries_csv_codec_test.dart`:
    - Legacy UUID row still parses
    - New base36 id row parses (e.g. `l7x3k2m-1`)
    - Garbage id rejected
  - [x] Run `flutter test test/data/csv/timeseries_csv_codec_test.dart test/data/repositories/step_repository_import_test.dart test/data/repositories/step_repository_export_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Dev inject + remove dependency** (AC: #5, #7)
  - [x] Update `test/dev/data_inject_service.dart`: remove `Uuid` param/field; use `SampleIdGenerator.deterministicFromIngestionBucket` per bucket
  - [x] Remove `uuid: ^4.4.0` from `pubspec.yaml`; run `flutter pub get`
  - [x] Verify: `rg "package:uuid" lib/ test/` → zero matches; direct dep removed (transitive via `share_plus_platform_interface` remains — Story 17)
  - [x] Run full `flutter test` + `flutter analyze`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Remove `uuid` package; replace all runtime id generation | `docs/DEPENDENCIES.md` / `architecture.md` stale UUID docs (optional follow-up) |
| Shared `SampleIdGenerator` in `lib/core/ids/` | Repository interface extraction (Story 16-1) |
| CSV import accepts legacy UUID **and** new ids | Migrating existing DB rows to new id format (not needed — ids are opaque) |
| `test/dev/data_inject_service.dart` uuid removal | Epic 15 version bump (deferred to epic close) |
| Branch `refacto` only | Changing bucket identity UNIQUE index or upsert SQL |

### Epic target files vs actual blast radius

Epic lists only `step_repository.dart` + `pubspec.yaml`. **Codebase reality** (grep 2026-06-18):

| File | `uuid` usage | Action |
|------|--------------|--------|
| `lib/data/repositories/step_repository.dart` | `_uuid.v4()` on ingest; passes `uuid` to compaction | Sub-task B |
| `lib/core/lifecycle/sample_compaction_runner.dart` | `_uuid.v4()` × 3 merge paths | Sub-task B |
| `test/dev/data_inject_service.dart` | `_uuid.v4()` in 25k-row loop | Sub-task D |
| `lib/data/csv/timeseries_csv_codec.dart` | UUID-only import validation | Sub-task C |

**Do not** leave `sample_compaction_runner.dart` on `uuid` — `flutter pub deps` would still pull the package if any `lib/` file imports it.

### Architecture D-25 vs audit shorthand

Audit §4 suggests `DateTime.now().microsecondsSinceEpoch.toRadixString(36)`.

**Override for this project:** use injected `TimeProvider` via `SampleIdGenerator(TimeProvider clock)` — matches architecture D-25 and existing `StepRepository(clock: …)` pattern. Tests inject `FakeTimeProvider` for deterministic ids.

### AC #1 — deterministic helpers vs `nextId()` (post-review decision)

AC #1 mentions runtime generation via injected `TimeProvider` (`nextId()`). **Production call sites intentionally use static deterministic helpers instead:**

| Call site | Id helper | Rationale |
|-----------|-----------|-----------|
| `upsertIngestionBucket` | `deterministicFromIngestionBucket` | Same bucket identity → same id on first insert; upsert merge semantics stay idempotent |
| Compaction merges | `deterministicFromMergedBucket` | Many merges per transaction; resolution suffix avoids PK clash with finer tiers |
| `DataInjectService` | `deterministicFromIngestionBucket` | 25k buckets; unique `startTimeUtc` per row |

`nextId()` remains on `SampleIdGenerator` for future non-bucket ids and is covered by unit tests, but is **not wired in `lib/`** production paths. This is preferred over clock-based `nextId()` because deterministic ids survive export → purge → import round-trips and compaction re-runs without PK collisions.

### Collision safety

| Call site | Risk | Implemented id |
|-----------|------|----------------|
| `upsertIngestionBucket` | Medium (multi-provider same window) | `deterministicFromIngestionBucket` — provider/device suffix |
| Compaction merges (many per transaction) | Medium (tight loop) | `deterministicFromMergedBucket` — resolution suffix |
| `DataInjectService` (288 × 90 buckets) | **High** if `nextId()` without advancing clock | `deterministicFromIngestionBucket` — unique `startTimeUtc` per bucket |

### Critical baseline — read before editing

**Current ingest id assignment (`step_repository.dart` 55–59):**

```55:59:lib/data/repositories/step_repository.dart
  Future<void> upsertIngestionBucket(NormalizedStepBucket bucket) async {
    final model = TimeseriesSampleModel.fromNormalizedBucket(
      bucket: bucket,
      id: _uuid.v4(),
    );
```

**Compaction passes uuid through (`step_repository.dart` 473):**

```473:473:lib/data/repositories/step_repository.dart
    final runner = SampleCompactionRunner(uuid: _uuid);
```

**CSV import rejects non-UUID ids today (`timeseries_csv_codec.dart` 245–249):**

```245:249:lib/data/csv/timeseries_csv_codec.dart
    final id = map['id']! as String;
    if (!_uuidPattern.hasMatch(id)) {
      throw ImportValidationException(
        'Row $rowNumber: id must be a valid UUID',
      );
```

This **must** change — otherwise export-after-refactor → import fails (FR-30 regression).

**Upsert semantics preserved** — `ON CONFLICT(provider, device_id, type, start_time, end_time, resolution)`; id only set on first insert:

```78:79:lib/data/repositories/step_repository.dart
      ON CONFLICT(provider, device_id, type, start_time, end_time, resolution)
      DO UPDATE SET value = timeseries_samples.value + excluded.value
```

Existing test `merges duplicate bucket increments without replacing the id` in `step_repository_upsert_test.dart` must still pass unchanged.

### Suggested `SampleIdGenerator` shape

```dart
// lib/core/ids/sample_id_generator.dart
class SampleIdGenerator {
  SampleIdGenerator(this._clock);

  final TimeProvider _clock;
  int _sequence = 0;

  String nextId() {
    final micros = _clock.snapshot().nowUtc.microsecondsSinceEpoch;
    final seq = _sequence++;
    final base = micros.toRadixString(36);
    return seq == 0 ? base : '$base-${seq.toRadixString(36)}';
  }

  static String deterministicFromStartUtc(DateTime startTimeUtc) =>
      startTimeUtc.toUtc().microsecondsSinceEpoch.toRadixString(36);
}
```

Place under `lib/core/ids/` — follows existing `lib/core/time/`, `lib/core/lifecycle/` layout.

### Compaction id strategy (preferred)

Inside `SampleCompactionRunner`, after computing merged `startTimeUtc` in each merge helper call site, pass:

```dart
newId: SampleIdGenerator.deterministicFromStartUtc(startTimeUtc),
```

Remove `Uuid` constructor param entirely. `lifecycle_compaction_test.dart` already passes explicit `newId: 'merged'` — unaffected.

### Test files to run (minimum)

| File | Why |
|------|-----|
| `test/core/ids/sample_id_generator_test.dart` | New — collision + format |
| `test/data/repositories/step_repository_upsert_test.dart` | Ingest id + merge semantics |
| `test/data/repositories/step_repository_import_test.dart` | FR-30 round-trip |
| `test/data/repositories/step_repository_export_test.dart` | Export preserves ids |
| `test/data/csv/timeseries_csv_codec_test.dart` | Dual-format validation |
| `test/data/repositories/step_repository_downsample_test.dart` | Compaction ids |
| `test/dev/data_inject_service_test.dart` | 25k inject after uuid removal |
| `test/dev/lifecycle_compaction_test.dart` | Merge helpers |

### Dependency verification commands

```bash
rg "package:uuid" lib/ test/
flutter pub get
flutter pub deps | rg uuid   # expect no output
```

### Previous story intelligence (15-3)

- Story 15-3 **deliberately kept** `uuid` in `test/dev/data_inject_service.dart` for this story.
- Dev tooling now lives in `test/dev/` — safe to change inject id scheme without affecting release APK.
- Review-before-commit workflow: one commit per sub-task, review brief, wait for Baptiste OK (`docs/project-context.md`).

### Regression risks

| Risk | Mitigation |
|------|------------|
| CSV import breaks for new id format | Sub-task C dual-pattern validation + round-trip test |
| Compaction id collisions in one txn | Use `deterministicFromStartUtc` not bare `nextId()` |
| Inject 25k ids collide | Use `deterministicFromStartUtc(startTimeUtc)` not clock-based `nextId()` |
| Tests assumed UUID shape | `step_repository_upsert_test.dart` only checks `isA<String>()` — OK |
| Missing hidden `uuid` import | `rg package:uuid` gate in Sub-task D |

### Architecture compliance

- **D-25:** `TimeProvider` for runtime ids — satisfied via `SampleIdGenerator(clock)`.
- **D-16 / FR-30:** Import idempotency on `id` column unchanged — format validation widened, not tightened.
- **Bucket identity UNIQUE** (D-19): untouched — id scheme is orthogonal.
- **Agent rule #17** (dev tooling): inject service in `test/dev/` — uuid removal aligns with REF-06 scope.

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 15-4, REF-06]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §4 uuid row]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-16, D-19, D-25, UUID v4 note (stale post-story)]
- [Source: `lib/data/repositories/step_repository.dart` — upsert + downsample wiring]
- [Source: `lib/core/lifecycle/sample_compaction_runner.dart` — merge id sites]
- [Source: `lib/data/csv/timeseries_csv_codec.dart` — import validation]
- [Source: `test/dev/data_inject_service.dart` — bulk inject ids]
- [Source: `_bmad-output/implementation-artifacts/stories/15-3-relocate-dev-tooling-to-test-dev.md` — uuid deferred to 15-4]
- [Source: `docs/project-context.md` — review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

claude-4.6-sonnet-medium-thinking

### Debug Log References

- Sub-task A: `SampleIdGenerator` created with `nextId()` (TimeProvider + sequence suffix) and deterministic helpers.
- Collision fix: ingestion uses `deterministicFromIngestionBucket` (provider/device suffix); compaction uses `deterministicFromMergedBucket` (resolution suffix). Bare `deterministicFromStartUtc` collided across tiers and multi-provider same-window buckets.

### Completion Notes List

- All sub-tasks A–D complete; 5 commits on `refacto`.
- `flutter test`: 844 passed, 15 skipped.
- Direct `uuid` dep removed from `pubspec.yaml`; zero `package:uuid` in `lib/` or `test/`.
- AC #7 partial: `uuid` remains **transitive** via `share_plus_platform_interface` — out of scope until Story 17-1 replaces `share_plus`.
- No version bump (Epic 15 close).

### File List

**Create:**
- `lib/core/ids/sample_id_generator.dart`
- `test/core/ids/sample_id_generator_test.dart`

**Modify:**
- `lib/data/repositories/step_repository.dart`
- `lib/core/lifecycle/sample_compaction_runner.dart`
- `lib/data/csv/timeseries_csv_codec.dart`
- `test/dev/data_inject_service.dart`
- `test/data/csv/timeseries_csv_codec_test.dart`
- `pubspec.yaml`
- `pubspec.lock`

**Modify:**
- `lib/data/repositories/step_repository.dart`
- `lib/core/lifecycle/sample_compaction_runner.dart`
- `lib/data/csv/timeseries_csv_codec.dart`
- `test/dev/data_inject_service.dart`
- `test/data/csv/timeseries_csv_codec_test.dart`
- `pubspec.yaml`

**Verify unchanged (run tests):**
- `test/data/repositories/step_repository_upsert_test.dart`
- `test/data/repositories/step_repository_import_test.dart`
- `test/data/repositories/step_repository_downsample_test.dart`
- `test/dev/data_inject_service_test.dart`

## Change Log

- 2026-06-18: Story context created (create-story workflow) — ready-for-dev.
- 2026-06-18: Story implemented — all sub-tasks A–D; status → review.
- 2026-06-18: Code review fixes — AC #4 round-trip integration test; AC #1 deterministic-helper decision documented; Epic 15 close (`0.6.3+14`); status → done.
