# Story 32.5: Test Hook and Deterministic Migration v3

Status: done

<!-- audits_2 Epic 32 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 32-5 · diagnostic-couche-donnees.md #6, #7 · AUD2-FR22 · AUD2-FR23 · AUD2-NFR7 -->
<!-- Prerequisite: Story 32-4 done · Epic 29–31 delivered -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want test-only hooks off public contracts and migrations injectable clocks,
So that repository alternatives and migration tests stay clean and deterministic.

## Acceptance Criteria

1. **Given** `StepIngestionRepositoryContract`
   **When** reviewed after this story
   **Then** `testHookAfterDeleteSamples` is not on the public interface — AUD2-FR22
   **And** test access uses `@visibleForTesting` on concrete impl or test subclass only

2. **Given** migration v3 seed of `effective_from_local_day`
   **When** `runMigrations` executes v3 upgrade
   **Then** date uses injectable `TimeProvider` — AUD2-FR23, AUD2-NFR7
   **And** production default (`SystemTimeProvider`) preserves device-local calendar semantics

3. **Given** `migrations_test.dart` v3 fresh install and v2→v3 upgrade groups
   **When** tests run
   **Then** `effective_from_local_day` is asserted against `FakeTimeProvider` pinned date (not `DateTime.now()`)

4. **Given** `step_repository_purge_test.dart` rollback test
   **When** this story ships
   **Then** fault injection still works via concrete `StepIngestionRepository.purge(testHookAfterDeleteSamples: …)` — no contract param

5. **Given** diagnostic items #6 and #7 in `diagnostic-couche-donnees.md`
   **When** story ships
   **Then** both marked `fixed` with story ref
   **And** `audits_2/README.md` rows #6, #7, M2 synced

**Covers:** AUD2-FR22 · AUD2-FR23 · AUD2-NFR7 · diagnostic-couche-donnees.md #6, #7

**Depends on:** Story 32-4 (orthogonal — no file conflict on goal/open predicate)

**Out of scope:**
- Changing purge transaction semantics or preserved pref keys (D-24)
- Rewriting v3 seed goal value logic (prefs parse unchanged)
- `pubspec.yaml` version bump (**Epic 32 close** after this story — patch+1 + README)
- Epic 33 stories

## Tasks / Subtasks

- [x] **Sub-task A — Remove test hook from public contract** (AC: #1, #4)
  - [x] Read fully: `lib/data/contracts/step_ingestion_repository_contract.dart`, `lib/data/repositories/step/step_ingestion_repository.dart`, `lib/presentation/cubits/my_data_cubit.dart` L370
  - [x] Contract: `Future<void> purge();` only — remove `testHookAfterDeleteSamples` param and `@visibleForTesting` import if unused
  - [x] Concrete impl: keep optional `@visibleForTesting Future<void> Function(Transaction txn)? testHookAfterDeleteSamples` on `StepIngestionRepository.purge` — **not** `@override` of contract param; method signature differs from contract (Dart allows fewer named params on override — verify analyzer: override must match contract; use `@override Future<void> purge()` and add optional named param only on concrete class without implementing contract param — **pattern:** contract has no param; concrete adds optional named param — valid in Dart)
  - [x] Grep `lib/` — confirm `MyDataCubit` calls `stepIngestion.purge()` with no args (already true)
  - [x] Update test subclasses `_TrackingStepIngestionRepository` / `_FailingPurgeRepository` in `my_data_cubit_purge_test.dart` — override `purge()` matching concrete signature
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Inject `TimeProvider` into migrations v3** (AC: #2)
  - [x] Read fully: `lib/core/database/migrations.dart`, `lib/core/database/app_database.dart`, `lib/core/time/system_time_provider.dart`
  - [x] Add optional `TimeProvider? clock` to `runMigrations` — default `const SystemTimeProvider()` when null
  - [x] Pass `clock` into `onCreateV3(db, clock: clock)` (add param)
  - [x] Replace `DateTime.now()` block (L119-123) with:
    ```dart
    final snapshot = clock.snapshot();
    final todayIso = formatLocalDayIso(snapshot);
    ```
  - [x] Update comment: one-time upgrade uses injected clock; production uses system clock
  - [x] Wire `openAstraDatabase({String? databasePath, TimeProvider? clock})` — pass clock into `runMigrations` from `onCreate` / `onUpgrade` (default null → `SystemTimeProvider` inside `runMigrations`)
  - [x] **Do not** thread clock through `AstraDatabaseSession` / prod DI — only migration path needs it
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Deterministic migration tests** (AC: #3)
  - [x] Read fully: `test/core/database/migrations_test.dart` — groups `migration v3 fresh install`, `migration v2 to v3 upgrade`
  - [x] Pin `FakeTimeProvider(fixedNowUtc: DateTime.utc(2026, 6, 15, 10), zoneOffset: const Duration(hours: 2))` → expect `effective_from_local_day == '2026-06-15'`
  - [x] For direct `openDatabase(..., onCreate: runMigrations)` upgrade fixtures: pass same `clock` into `runMigrations(db, version, clock: clock)` and upgrade callbacks
  - [x] Optional: add explicit test calling `runMigrations(db, 3, clock: fakeClock)` on v2 schema without `openAstraDatabase` — documents inject path
  - [x] Run: `flutter test test/core/database/migrations_test.dart`
  - [x] Run: `flutter test test/data/repositories/step_repository_purge_test.dart`
  - [x] Run: `flutter test --tags critical`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Close diagnostic + Epic 32 tracker note** (AC: #5)
  - [x] Update `diagnostic-couche-donnees.md` #6, #7 → `fixed` (32-5); refresh synthèse + statut global if all P2 closed
  - [x] Sync `audits_2/README.md`: diagnostic 01 rows #6, #7 → `fixed`; M2 → done (32-5)
  - [x] Note in story Dev Agent Record: **Epic 32 close** = bump `pubspec.yaml` patch+1 + `README.md` (separate commit after 32-5 review — not in this story's sub-tasks unless Baptiste requests)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Contract leak — test hook on public API:**

```4:7:lib/data/contracts/step_ingestion_repository_contract.dart
abstract class StepIngestionRepositoryContract {
  Future<void> purge({
    @visibleForTesting Future<void> Function(Transaction txn)? testHookAfterDeleteSamples,
  });
}
```

Every alternate implementation (mocks, fakes, future split repos) must expose a test-only callback in the production contract. Production caller (`MyDataCubit`) never passes it:

```370:370:lib/presentation/cubits/my_data_cubit.dart
      await stepIngestion.purge();
```

**Fault-injection test today** (`step_repository_purge_test.dart` L137-154) calls concrete repo with hook to assert txn rollback — must keep working on `StepIngestionRepository`, not contract.

[Source: `diagnostic-couche-donnees.md` #6 · AUD2-FR22]

---

**Migration v3 non-deterministic seed:**

```119:123:lib/core/database/migrations.dart
  // One-time upgrade path: device-local calendar day (no injected clock).
  final now = DateTime.now();
  final todayIso = formatLocalDayIso(
    TimeSnapshot(nowUtc: now.toUtc(), zoneOffset: now.timeZoneOffset),
  );
```

Tests compare against `DateTime.now().toLocal()` manual formatting (`migrations_test.dart` L387-392, L496-501) — flaky across TZ/DST boundaries and violates D-25 spirit for testable migration paths.

[Source: `diagnostic-couche-donnees.md` #7 · AUD2-FR23 · architecture D-25]

### Recommended implementation

**A — Contract vs concrete purge:**

| Layer | Signature |
|-------|-----------|
| `StepIngestionRepositoryContract` | `Future<void> purge();` |
| `StepIngestionRepository` | `Future<void> purge({@visibleForTesting Future<void> Function(Transaction txn)? testHookAfterDeleteSamples})` |

Dart: `@override purge()` on concrete class can add optional named parameters not declared on abstract method. Test subclasses extend concrete class, not contract.

**Do NOT:**
- Add hook to any contract or cubit API
- Remove hook from concrete impl (rollback test depends on it)
- Change purge txn order: delete samples → hook → clear baselines → scrub derived prefs

**B — Migration clock threading:**

```dart
Future<void> runMigrations(
  Database db,
  int targetVersion, {
  int fromVersion = 0,
  TimeProvider? clock,
}) async {
  final time = clock ?? const SystemTimeProvider();
  // ...
  case 3:
    await onCreateV3(db, clock: time);
}

Future<void> onCreateV3(Database db, {required TimeProvider clock}) async {
  // ... prefs parse unchanged ...
  final todayIso = formatLocalDayIso(clock.snapshot());
  // insert daily_goal_effective ...
}
```

`openAstraDatabase` optional `clock` param — pass through to `runMigrations` only. Default `null` → `SystemTimeProvider` inside `runMigrations` (production behavior equivalent to current `DateTime.now()` for local day).

**C — Test pin:** `FakeTimeProvider` + `formatLocalDayIso` → `'2026-06-15'` when UTC 10:00 + offset +2h (same pattern as 32-4 / 8-2 tests).

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-15 | Numbered migrations — optional clock param does not bump `kDbVersion` |
| D-25 | No raw `DateTime.now()` in migration v3 seed; `SystemTimeProvider` for prod default |
| D-24 | Purge txn boundaries unchanged |
| Story 16-1 | Contracts stay minimal — test hooks off interface |
| Story 8-1 | v3 seed semantics preserved — only clock source changes |
| Agent tests | Targeted files + `flutter test --tags critical` |
| OK commit gate | Sub-tasks A→D with separate commits |

[Source: `architecture.md` D-15, D-25, D-24 · Story 16-1]

### File structure requirements

| File | Action |
|------|--------|
| `lib/data/contracts/step_ingestion_repository_contract.dart` | **UPDATE** — `purge()` no params |
| `lib/data/repositories/step/step_ingestion_repository.dart` | **UPDATE** — hook stays on concrete only |
| `lib/core/database/migrations.dart` | **UPDATE** — `TimeProvider` in `runMigrations` / `onCreateV3` |
| `lib/core/database/app_database.dart` | **UPDATE** — optional `clock` → `runMigrations` |
| `lib/presentation/cubits/my_data_cubit.dart` | **VERIFY** — `purge()` call unchanged |
| `test/core/database/migrations_test.dart` | **UPDATE** — pinned `FakeTimeProvider` assertions |
| `test/data/repositories/step_repository_purge_test.dart` | **VERIFY** — hook on concrete repo still works |
| `test/presentation/cubits/my_data_cubit_purge_test.dart` | **UPDATE** — override signatures if needed |
| `planning-artifacts/audits_2/diagnostic-couche-donnees.md` | Close #6, #7 |
| `planning-artifacts/audits_2/README.md` | Sync rows #6, #7, M2 |

**Do not touch:** purge pref allowlist keys, v3 table DDL, `getGoalForLocalDay` consumers (32-4), sample ID logic (32-1).

### Testing requirements

| Verify | Command |
|--------|---------|
| Migration v3 deterministic | `flutter test test/core/database/migrations_test.dart` |
| Purge rollback hook | `flutter test test/data/repositories/step_repository_purge_test.dart` |
| My Data purge cubit | `flutter test test/presentation/cubits/my_data_cubit_purge_test.dart` |
| Critical gate | `flutter test --tags critical` |

Do **not** run bare `flutter test`.

**Regression focus:**
- v2→v3 upgrade still seeds goal from prefs (`12000` test unchanged except date assertion)
- v3→v4 upgrade test unaffected (v3 table already exists)
- Contract implementors compile: only `StepIngestionRepository` implements contract in `lib/`

### Previous story intelligence

| Learning | Impact on 32-5 |
|----------|----------------|
| 32-4: OK commit gate A→F; diagnostic + README sync on close | Mirror A→D pattern in sub-task D |
| 32-4: `FakeTimeProvider` + `formatLocalDayIso` standard | Reuse for migration v3 tests |
| 32-4: tracker = `sprint-status-audits-2.yaml` | Update same file to `ready-for-dev` |
| 32-4: explicitly deferred migrations + test hook to 32-5 | This story owns both |
| 30-4: inject clock optional param, prod default unchanged | Same pattern for `runMigrations` |
| 16-1: contracts minimal surface | Reinforces hook removal from contract |

[Source: `stories/32-4-single-goal-source-and-safe-database-open-check.md` · `stories/30-4-inject-timeprovider-into-collection-timeout-source.md`]

### Cross-story context (Epic 32)

| Story | Status | Relationship |
|-------|--------|--------------|
| 32-1 | done | ID alignment — orthogonal |
| 32-2 | done | Dev guard — orthogonal |
| 32-3 | done | Privacy disclaimer — orthogonal |
| 32-4 | done | Goal single source — deferred migrations/hook to 32-5 |
| **32-5** | **this story** | Last Epic 32 story — closes P2 data-layer debt |

**Epic 32 close after 32-5:** bump `pubspec.yaml` patch+1 (`0.14.0+34` → `0.14.1+35` per tracker base) + `README.md` project status row.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `c04c692` | Story 32-4 done — latest Epic 32 |
| `8ffffdb` | 32-4 docs / diagnostic close pattern |
| `384ce70` | 32-1 — diagnostic README sync pattern |
| `c45260e` | 32-2 — targeted test + critical gate |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.14.0+34`.

### Latest tech / library notes

- **Dart override with extra optional named params:** Valid on concrete `@override` when abstract method has no such params — analyzer accepts optional additions on implementing method.
- **`SystemTimeProvider`:** Already used in WM/collection paths — reuse for migration default (Story 30-4 precedent).
- **`formatLocalDayIso(TimeSnapshot)`:** Existing helper — same as v3 seed intent; no new date logic.
- **No new packages** for this story.
- **sqflite migrations:** `onCreateV3` runs on fresh install **and** v2→v3 upgrade via same function — single clock injection covers both paths.

### Project context reference

- OK commit gate: sub-tasks with separate commits after Baptiste approval
- Tests: targeted file + `flutter test --tags critical`
- Version bump: Epic 32 close — after 32-5 dev + review
- Chat French; story/doc English per BMAD config

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 32-5, AUD2-FR22, AUD2-FR23]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-couche-donnees.md` #6, #7]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` M2, diagnostic 01 rows #6, #7]
- [Source: `_bmad-output/planning-artifacts/architecture.md` D-15, D-25]
- [Source: `lib/data/contracts/step_ingestion_repository_contract.dart`]
- [Source: `lib/data/repositories/step/step_ingestion_repository.dart`]
- [Source: `lib/core/database/migrations.dart`]
- [Source: `lib/core/database/app_database.dart`]
- [Source: `test/core/database/migrations_test.dart`]
- [Source: `test/data/repositories/step_repository_purge_test.dart`]
- [Source: `_bmad-output/implementation-artifacts/stories/32-4-single-goal-source-and-safe-database-open-check.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/30-4-inject-timeprovider-into-collection-timeout-source.md`]

## Dev Agent Record

### Agent Model Used

Composer (create-story) · Composer (dev-story)

### Debug Log References

- Dart override with extra optional named param on concrete `purge()` — analyzer OK
- `FakeTimeProvider` pinned UTC 2026-06-15 10:00 +02:00 → `'2026-06-15'`

### Completion Notes List

- **A:** Contract `purge()` sans param ; hook `@visibleForTesting` conservé sur `StepIngestionRepository` uniquement
- **B:** `TimeProvider? clock` dans `runMigrations` / `onCreateV3` ; default `SystemTimeProvider` ; `openAstraDatabase` forward clock
- **C:** Tests migration v3 pin `FakeTimeProvider` ; test direct `runMigrations(db, 3, clock: …)` ajouté
- **D:** Diagnostic #6/#7 → `fixed` ; README M2/M3 → done ; statut global diagnostic → `done`
- **Epic 32 close:** bump `pubspec.yaml` + `README.md` à faire après review (commit séparé)
- **Tests:** migrations (15) · purge (3) · cubit purge (8) · critical (215) — all green

### File List

- `lib/data/contracts/step_ingestion_repository_contract.dart`
- `lib/core/database/migrations.dart`
- `lib/core/database/app_database.dart`
- `test/core/database/migrations_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-couche-donnees.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`
- `_bmad-output/implementation-artifacts/stories/32-5-test-hook-and-deterministic-migration-v3.md`

## Change Log

- 2026-07-25: Story 32-5 created — remove test hook from contract + inject TimeProvider into migration v3 seed
- 2026-07-25: Story 32-5 implemented — contract cleanup, migration clock injection, deterministic tests, diagnostic close
