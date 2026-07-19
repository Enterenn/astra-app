# Story 25.5: Add Core Data Class Doc Comments for Public Services

Status: review

<!-- Post-audit Epic 25 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 25-5 · diagnostic-convention-structure.md §2.1 · AUD-48 -->
<!-- Prerequisite: Stories 25-1 through 25-4 done -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want public core/data classes documented,
So that new contributors understand contracts without reading every call site.

## Acceptance Criteria

1. **Given** the 18 public `core/`/`data/` classes listed in `diagnostic-convention-structure.md` §2.1 without class-level `///`
   **When** this story ships
   **Then** each listed class has a concise `///` doc comment immediately above the class declaration (AUD-48)
   **And** comments describe **responsibility and key contracts**, not line-by-line implementation narration

2. **Given** the authoritative inventory below (AUD-48 scope — do not expand or shrink without PM approval)
   **When** verification runs
   **Then** every row is satisfied:

   | # | Class | File |
   |---|-------|------|
   | 1 | `AppDependencies` | `lib/core/di/app_dependencies.dart` |
   | 2 | `BackgroundCollector` | `lib/core/services/background_collector.dart` |
   | 3 | `LifecycleRunResult` | `lib/core/services/data_lifecycle_service.dart` |
   | 4 | `PluginStepCollectionWorkmanagerClient` | `lib/core/services/workmanager_callback.dart` |
   | 5 | `LocalDayCalculator` | `lib/core/time/local_day_calculator.dart` |
   | 6 | `SystemTimeProvider` | `lib/core/time/system_time_provider.dart` |
   | 7 | `TimeSnapshot` | `lib/core/time/time_provider.dart` |
   | 8 | `TimestampCodec` | `lib/core/time/timestamp_codec.dart` |
   | 9 | `PhoneStepEvent` | `lib/data/datasources/phone_pedometer_source.dart` |
   | 10 | `PhonePedometerSource` | `lib/data/datasources/phone_pedometer_source.dart` |
   | 11 | `StepNormalizer` | `lib/data/datasources/step_normalizer.dart` |
   | 12 | `ImportResult` | `lib/data/models/import_result.dart` |
   | 13 | `NormalizedStepBucket` | `lib/data/models/normalized_step_bucket.dart` |
   | 14 | `StepReading` | `lib/data/models/step_reading.dart` |
   | 15 | `TimeseriesSampleModel` | `lib/data/models/timeseries_sample_model.dart` |
   | 16 | `StepAggregationRepository` | `lib/data/repositories/step/step_aggregation_repository.dart` |
   | 17 | `StepIngestionRepository` | `lib/data/repositories/step/step_ingestion_repository.dart` |
   | 18 | `CsvService` | `lib/data/services/csv_service.dart` |

3. **Given** existing doc-comment style in the codebase (`AstraDatabaseSession`, `StepNormalizationResult`, `purge_confirm_action.dart`)
   **When** new comments are added
   **Then** they follow the same tone: 1–3 sentences, optional second paragraph for non-obvious invariants
   **And** they reference FR/requirement IDs only when directly relevant (e.g. FR-19 export, FR12 maintenance)
   **And** they do **not** duplicate method-level docs already present on the same class (e.g. `StepIngestionRepository.upsertIngestionBucket`, `CsvService.exportCsv`)

4. **Given** classes **outside** §2.1 that already have `///` (e.g. `DataLifecycleService`, `StepNormalizationResult`, `AstraDatabaseSession`, lifecycle services from 25-2)
   **When** this story ships
   **Then** those files are untouched unless a listed class shares the file

5. **Given** existing test suites
   **When** `dart analyze` and `flutter test --exclude-tags slow` run
   **Then** all pass — **documentation-only diff**, zero behavioural change

6. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** work is split into reviewable sub-tasks (baseline → core/time+di → core/services → data layer → verify) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 25 closes

**Covers:** AUD-48 · diagnostic-convention-structure.md §2.1 (Basse / Docs)

**Depends on:** Stories 25-1 through 25-4 **done**. Independent of Epic 26.

**Out of scope:** Field/member-level docs for every public API; `public_member_api_docs` lint enablement; AUD-49 file/class naming; documenting `TimeProvider` abstract (not in §2.1); presentation-layer classes; version bump; behaviour or signature changes.

## Tasks / Subtasks

- [x] **Sub-task A — Baseline inventory** (AC: #1, #2)
  - [x] Re-read `diagnostic-convention-structure.md` §2.1 and confirm all 18 classes still lack class-level `///` (grep each file)
  - [x] Note adjacent documented types to avoid duplicating (`StepNormalizationResult` L7 in `step_normalizer.dart`, `DataLifecycleService` L112)
  - [x] Read style references: `lib/core/database/astra_database_session.dart`, `lib/core/constants/purge_confirm_action.dart`, `lib/data/datasources/step_normalizer.dart` L7
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (plan-only commit optional)

- [x] **Sub-task B — Core time + DI docs** (AC: #1–#3) — 5 files, 5 classes
  - [x] `time_provider.dart` — `TimeSnapshot`: immutable UTC instant + zone offset from `TimeProvider.snapshot()`
  - [x] `system_time_provider.dart` — production clock implementation
  - [x] `timestamp_codec.dart` — SQLite UTC `Z` timestamps + `±HH:MM` zone offset codec (static utility)
  - [x] `local_day_calculator.dart` — local calendar day from UTC + stored zone offset
  - [x] `app_dependencies.dart` — app composition root; list role (repos, collectors, lifecycle) not every field
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Core services docs** (AC: #1–#3) — 3 files, 4 classes
  - [x] `background_collector.dart` — multi-source ingest orchestration; lock, normalize, upsert, optional goal notification
  - [x] `data_lifecycle_service.dart` — `LifecycleRunResult` only (class above `runMaintenanceOnConnection`; do not rewrite `DataLifecycleService` doc)
  - [x] `workmanager_callback.dart` — `PluginStepCollectionWorkmanagerClient`: Workmanager plugin adapter for periodic collection
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Data layer docs** (AC: #1–#3) — 9 files, 10 classes
  - [x] Models: `StepReading`, `NormalizedStepBucket`, `TimeseriesSampleModel`, `ImportResult`
  - [x] Datasources: `PhoneStepEvent`, `PhonePedometerSource`, `StepNormalizer`
  - [x] Repositories: `StepIngestionRepository` (write/additive upsert), `StepAggregationRepository` (read/charts/downsample)
  - [x] `csv_service.dart` — FR-19/20 CSV export/import facade
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Regression verification** (AC: #2, #5, #6)
  - [x] Run verification grep (Dev Notes)
  - [x] Run `dart analyze`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Class-level `///` on 18 §2.1 types | Member-level docs on every public method/field |
| Match existing project doc tone | Enable `public_member_api_docs` in `analysis_options.yaml` |
| Documentation-only edits | Refactors, renames, file splits (AUD-49) |
| OK-commit sub-task gate | Version bump (Epic 25 close) |

### Root cause (read before editing)

**Convention gap:** Static audit (`diagnostic-convention-structure.md`, 181 `lib/**/*.dart` files) found 18 public `core/`/`data/` service/model/repository classes without class-level `///`. New contributors must trace call sites to learn contracts [Source: diagnostic §2.1, Synthèse L189].

**Why now:** Epic 25 structural refactors (25-1…25-4) stabilized Today/lifecycle/DI/My Data layers; doc pass is safe housekeeping before Epic 26 test authoring touches the same orchestration code.

**What already works (do not rewrite):**
- Method-level docs on hot paths (`upsertIngestionBucket`, `exportCsv`, `getTodayActiveBuckets`) — keep; add **class-level** summary only.
- `StepNormalizationResult` already documented L7 — **do not re-doc**.
- `DataLifecycleService` already documented L110 — **do not touch**.
- Constants (`kFiveMinuteResolution`, etc.) — no new docs required.

### Current state — files to read fully before editing

**`lib/core/di/app_dependencies.dart`** (~379 LOC):
- **Today:** L33 `AppDependencies` — no class doc; holds all app singletons; `create()` factory wires SQLite session, repos, collectors, lifecycle coordinator.
- **Change:** 2–3 sentence class doc above L33.
- **Preserve:** All wiring logic unchanged.

**`lib/core/services/background_collector.dart`** (~231 LOC):
- **Today:** L18 — orchestrates `collectOnce`, ingestion lock, normalizer, `StepIngestionRepository`, goal notification gating via `isUserFacingAppActive`.
- **Change:** Class doc summarizing ingest pipeline role.
- **Preserve:** L46–55 existing field/method comments.

**`lib/core/services/data_lifecycle_service.dart`**:
- **Today:** L19 `LifecycleRunResult` — no class doc; `skipped` + optional `CompactionResult`; returned by `runMaintenanceOnConnection`.
- **Change:** Brief result-type doc (skipped vs ran compaction).
- **Preserve:** L16–18 const doc, L34–38 function doc, L112 `DataLifecycleService` doc.

**`lib/core/services/workmanager_callback.dart`**:
- **Today:** L35 `PluginStepCollectionWorkmanagerClient` — thin Workmanager wrapper; used for periodic step collection + callback dispatcher bootstrap.
- **Change:** Adapter doc (test seam via `StepCollectionWorkmanagerClient` interface).
- **Preserve:** Callback dispatcher and isolate bootstrap logic.

**`lib/core/time/*.dart`** (4 files):
- **TimeSnapshot** — pair of `nowUtc` + `zoneOffset`; used everywhere for local-day semantics.
- **SystemTimeProvider** — default production `TimeProvider`.
- **TimestampCodec** — static format/parse for SQLite text timestamps (second-aligned UTC, minute-aligned offsets).
- **LocalDayCalculator** — static `localDay(utc, zoneOffset)` → date-only UTC midnight.
- **Preserve:** All algorithms; private constructors stay as-is.

**`lib/data/datasources/phone_pedometer_source.dart`**:
- **PhoneStepEvent** — wrapper for pedometer cumulative counter + timestamp.
- **PhonePedometerSource** — `DataIngestionSource` mapping stream → `StepReading`.
- **Preserve:** L50+ `LiveStepMonitor` exposure comment.

**`lib/data/datasources/step_normalizer.dart`**:
- **StepNormalizer** — cumulative readings → 5-min `NormalizedStepBucket` list + terminal baseline.
- **Preserve:** Existing `StepNormalizationResult` doc L7.

**`lib/data/models/*.dart`** (4 model files):
- **StepReading** — raw cumulative observation.
- **NormalizedStepBucket** — pre-SQLite bucket with resolution/provider metadata; validates non-negative value.
- **TimeseriesSampleModel** — SQLite row entity; `fromMap`/`toMap`/`fromNormalizedBucket`.
- **ImportResult** — CSV import counters.

**`lib/data/repositories/step/step_ingestion_repository.dart`**:
- **Write path** — `upsertIngestionBucket` additive on conflict; used by `BackgroundCollector`.
- **Preserve:** L28–33 method doc.

**`lib/data/repositories/step/step_aggregation_repository.dart`**:
- **Read path** — today steps, chart aggregates, active buckets, downsampling/compaction, footprint.
- **Preserve:** Method docs L69+, finest-resolution anti-double-count logic.

**`lib/data/services/csv_service.dart`**:
- **CsvService** — export/import via `TimeseriesCsvCodec`; FR-19 aligned.
- **Preserve:** L28–32 `exportCsv` doc.

### Recommended doc content (starting points — adapt to file tone)

Use as **draft intent**, not copy-paste blocks. Dev agent should read each class and write concise prose.

| Class | Doc must convey |
|-------|-----------------|
| `AppDependencies` | Composition root for app startup; exposes repos, collectors, lifecycle, DB session |
| `BackgroundCollector` | Runs one ingest cycle: sources → normalize → SQLite upsert → optional notification |
| `LifecycleRunResult` | Maintenance outcome: skipped vs ran compaction + optimize |
| `PluginStepCollectionWorkmanagerClient` | Production `StepCollectionWorkmanagerClient` using Workmanager plugin |
| `LocalDayCalculator` | Derives local calendar day from UTC sample + stored offset |
| `SystemTimeProvider` | System-clock `TimeProvider` for production |
| `TimeSnapshot` | Frozen UTC now + zone offset snapshot |
| `TimestampCodec` | SQLite-safe UTC/offset string codec |
| `PhoneStepEvent` | Normalized pedometer counter event |
| `PhonePedometerSource` | Phone `DataIngestionSource` (cumulative counter stream) |
| `StepNormalizer` | Buckets cumulative readings into 5-min increments |
| `ImportResult` | CSV import summary counts |
| `NormalizedStepBucket` | Ingestion bucket before persistence |
| `StepReading` | Single cumulative counter reading |
| `TimeseriesSampleModel` | `timeseries_samples` table entity |
| `StepIngestionRepository` | Write-side step sample persistence |
| `StepAggregationRepository` | Read-side queries, charts, downsampling |
| `CsvService` | User CSV export/import (FR-19/20) |

### Doc style examples (follow, do not duplicate content blindly)

```dart
/// UI-isolate SQLite handle that survives [database_closed] from other isolates.
///
/// WorkManager and file-picker flows can open/close their own connections on the
/// same path; sqflite on Android may invalidate the app connection. [withRetry]
/// reopens once and retries the action.
class AstraDatabaseSession { ... }
```

```dart
/// Result of the purge confirmation flow (FR-21).
enum PurgeConfirmAction { ... }
```

```dart
/// Output of [StepNormalizer.normalize] / [StepNormalizer.normalizeReadings].
class StepNormalizationResult { ... }
```

**Rules:**
- Prefer `[ClassName]` cross-refs for related types.
- One blank line between summary and detail paragraph when using `///` continuation.
- No `@param` blocks unless a factory has surprising behaviour (generally avoid).
- Do not add superfluous inline comments inside methods.

### Architecture compliance

| Rule | Source | This story |
|------|--------|------------|
| Docs on public core/data contracts | diagnostic §2.1, AUD-48 | 18 classes |
| No behaviour change | Epic 25 scope | Comments only |
| Pragmatic 3-layer | architecture.md | core + data only |
| OK-commit gate | docs/project-context.md | Mandatory sub-task commits |
| Tracker | sprint-status-post-audit.yaml | Update story → ready-for-dev |

### File structure requirements

| Path | Action |
|------|--------|
| 15 files listed in AC #2 inventory | **UPDATE** — add class-level `///` only |
| All other `lib/**` files | **NO CHANGE** |

### Testing requirements

| Command | When |
|---------|------|
| Verification grep (below) | Sub-task E |
| `dart analyze` | Every sub-task |
| `flutter test --exclude-tags slow` | Sub-task E |

**Verification grep (PowerShell-friendly):**

```bash
# Each listed class should have /// within 3 lines above "class ClassName"
rg -n "^class (AppDependencies|BackgroundCollector|LifecycleRunResult|PluginStepCollectionWorkmanagerClient|LocalDayCalculator|SystemTimeProvider|TimeSnapshot|TimestampCodec|PhoneStepEvent|PhonePedometerSource|StepNormalizer|ImportResult|NormalizedStepBucket|StepReading|TimeseriesSampleModel|StepAggregationRepository|StepIngestionRepository|CsvService)" lib/

# Manual: confirm /// doc block immediately precedes each match (not a method comment farther up)
```

Optional script: extend `tools/convention_diagnostic.py` if it exists in repo — **not required** for story completion.

No new tests required — zero runtime change.

### Previous story intelligence (25-4, 25-3, 25-2, 25-1)

- **Mechanical-first:** Same pattern as 25-3/25-4 — narrow scope, no drive-by refactors.
- **25-2 precedent:** Lifecycle sub-services received concise `///` during extract (`LifecyclePersistService`, `lifecycle_policy.dart`) — **mirror that tone** for remaining undocumented core/data classes.
- **25-4 closed 2026-07-19:** My Data decoupling complete; `csv_platform_file_picker.dart` is new but out of §2.1 scope (not listed — skip unless audit refreshed).
- **Regression bar:** 947/947 tests green after 25-4; maintain same bar.
- **Code review pattern:** Inventory table + sub-task OK commits; ≤5 sub-tasks.

### Git intelligence (recent work)

Recent commits (25-4): `refactor(my-data): decouple cubit from dialog types and file picker` — touched `data/csv/` and `core/constants/` but **not** the 18 §2.1 targets. Safe to edit in parallel with no merge conflict expected on main.

25-3 moved theme enum to core with minimal doc (`AstraThemePreference`) — single-line style acceptable for simple types.

### Latest tech information

- **Dart 3.x doc comments:** Standard `///` (not `/** */`) — matches existing codebase.
- **`public_member_api_docs`:** **Not enabled** in `analysis_options.yaml` (only `discarded_futures` beyond `flutter_lints`). Story does not require enabling it.
- **No package upgrades** — documentation-only.
- **dart doc / IDE:** `dart analyze` will not flag missing class docs; rely on inventory grep + human review.

### Project context reference

- OK-commit gate: `docs/project-context.md`
- Test default: `flutter test --exclude-tags slow`
- Version bump: Epic 25 close only (`patch+1`, `build+1`) — update `pubspec.yaml` + `README.md` then, not in this story
- Tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (post-audit track — **not** `sprint-status.yaml`)

### References

- [Source: _bmad-output/planning-artifacts/epics-post-audit.md#Story 25-5]
- [Source: _bmad-output/planning-artifacts/audits/diagnostic-convention-structure.md §2.1 L88–111, Synthèse L189]
- [Source: lib/core/database/astra_database_session.dart — multi-line doc pattern]
- [Source: lib/core/constants/purge_confirm_action.dart — single-line doc pattern]
- [Source: lib/data/datasources/step_normalizer.dart L7 — result type doc pattern]
- [Source: _bmad-output/implementation-artifacts/stories/25-4-decouple-my-data-cubit-from-ui-dialog-types.md — epic workflow precedent]
- [Source: docs/project-context.md — OK-commit gate, test commands]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Baseline grep: 18/18 classes lacked `///` before edits
- Verification grep post-edit: all 18 have `///` within 3 lines above class declaration
- `DataLifecycleService`, `StepNormalizationResult` left untouched

### Completion Notes List

- Added class-level `///` doc comments to all 18 §2.1 inventory classes (AUD-48)
- Tone matches `AstraDatabaseSession` / `StepNormalizationResult` patterns; no method-level duplication
- `dart analyze`: 0 errors (pre-existing warnings only)
- `flutter test --exclude-tags slow`: all pass

### File List

- `lib/core/di/app_dependencies.dart`
- `lib/core/services/background_collector.dart`
- `lib/core/services/data_lifecycle_service.dart`
- `lib/core/services/workmanager_callback.dart`
- `lib/core/time/time_provider.dart`
- `lib/core/time/system_time_provider.dart`
- `lib/core/time/timestamp_codec.dart`
- `lib/core/time/local_day_calculator.dart`
- `lib/data/datasources/phone_pedometer_source.dart`
- `lib/data/datasources/step_normalizer.dart`
- `lib/data/models/step_reading.dart`
- `lib/data/models/normalized_step_bucket.dart`
- `lib/data/models/timeseries_sample_model.dart`
- `lib/data/models/import_result.dart`
- `lib/data/repositories/step/step_ingestion_repository.dart`
- `lib/data/repositories/step/step_aggregation_repository.dart`
- `lib/data/services/csv_service.dart`

### Change Log

- 2026-07-19: Added class-level doc comments for 18 core/data public services (Story 25-5, AUD-48)
