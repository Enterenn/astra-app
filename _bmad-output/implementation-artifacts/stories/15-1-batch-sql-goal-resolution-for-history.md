# Story 15.1: Batch SQL Goal Resolution for History

Status: done

<!-- Refacto Epic 15 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 15-1 · refactoring-audit-master-v0.6.1.md §3.4 -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want Trends to load quickly even with 30 days of goal history,
So that opening the History tab feels instant on 120 Hz devices.

## Acceptance Criteria

1. **Given** `HistoryCubit._resolveGoalsForAggregates` needs goals for N distinct local days  
   **When** goals are fetched  
   **Then** a **single** repository batch method runs (one SQL round-trip via `_session.withRetry`) instead of N parallel `getGoalForLocalDay` calls (REF-03)  
   **And** result is a `Map<String, int>` keyed by ISO local day (`YYYY-MM-DD`)  
   **And** the `Future.wait` loop over individual `getGoalForLocalDay` calls in `_resolveGoalsForAggregates` is removed

2. **Given** the `daily_goal_effective` journal table (`effective_from_local_day`, `goal`)  
   **When** batch resolution runs for requested days  
   **Then** semantics match existing `getGoalForLocalDay`: for each day D, use the latest row where `effective_from_local_day ≤ D`  
   **And** resolution uses the **validated journal approach**: one SQL round-trip (`SELECT effective_from_local_day, goal … WHERE effective_from_local_day <= ? ORDER BY effective_from_local_day ASC`) + Dart journal walk (see Dev Notes)  
   **And** when no journal row applies to D, fallback is `kDefaultStepGoal` (8000)  
   **And** invalid/zero `goal` values normalize to `kDefaultStepGoal` (same as single-day method)

3. **Given** an empty distinct-day list  
   **When** batch resolution runs  
   **Then** return `const {}` without hitting SQLite

4. **Given** existing `history_cubit_test.dart` goal tests (`refresh resolves goalsByDay for chart window`, `refreshGoal updates goalsByDay without re-querying steps`)  
   **When** this story ships  
   **Then** all assertions still pass without weakening expectations  
   **And** new test proves **one** batch call for a 30-day window (mock/spy call count)

5. **Given** `getGoalForLocalDay` single-day API  
   **When** this story ships  
   **Then** it remains unchanged for `TodayCubit`, `BackgroundCollector`, and `_resolveTodayGoal` — batch is additive, not a breaking rename

6. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 15 closes with patch+1 (`0.6.2+13` → `0.6.3+14`) when all Epic 15 stories are done

**Covers:** REF-03 · Audit §3.4 (P1) · Supports KPI-01 (History chart latency)

## Tasks / Subtasks

- [x] **Sub-task A — Add `getGoalsForLocalDays` on repository** (AC: #1–#3, #5)
  - [x] Read `getGoalForLocalDay` and `daily_goal_effective` schema in `user_preferences_repository.dart` / `migrations.dart` **before editing**
  - [x] Add `Future<Map<String, int>> getGoalsForLocalDays(List<String> localDayIsos)` next to `getGoalForLocalDay`
  - [x] Implementation shape — **validated journal approach** (see Dev Notes § Validated batch SQL):
    - Deduplicate + sort requested ISO strings; early-return `{}` when empty
    - `maxDay = sorted.last`
    - Run the canonical batch SQL (bind `?` = `maxDay`)
    - Walk sorted requested days + journal rows to assign effective goal per day (mirror single-day `ORDER BY effective_from_local_day DESC LIMIT 1` logic)
  - [x] **Do not** use the audit/epic shorthand SQL (`local_day IN (…)`, `goal_steps`) — invalid for Epic 8 journal semantics
  - [x] Add repository tests in `test/data/repositories/user_preferences_repository_test.dart` under existing `daily goal history` group:
    - Multi-day journal → per-day goals match existing `getGoalForLocalDay` expectations
    - Day before any row → `kDefaultStepGoal`
    - Empty input → `{}` without DB access (optional: assert via in-memory DB left untouched)
  - [x] Run `flutter analyze` + `flutter test test/data/repositories/user_preferences_repository_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Wire HistoryCubit to batch API + call-count test** (AC: #1, #4)
  - [x] Replace `_resolveGoalsForAggregates` body to call `userPreferences.getGoalsForLocalDays(distinctIsos)` — remove `Future.wait` / per-day `getGoalForLocalDay`
  - [x] Keep `_resolveTodayGoal()` as single `getGoalForLocalDay` (one day only — not in scope)
  - [x] Add spy subclass in `history_cubit_test.dart` (pattern: `_ChartAggregateSpyRepository`, `_ThrowingDistancePreferencesRepository` in `units_cubit_test.dart`):
    - Count `getGoalsForLocalDays` invocations
    - Fail test if `getGoalForLocalDay` is called from aggregate resolution path during `refresh` / `refreshGoal`
  - [x] Inject 30-day chart window (reuse `DataInjectService.inject90Days` or bucket loop) → assert batch call count == 1
  - [x] Run `flutter analyze` + `flutter test test/presentation/cubits/history_cubit_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Batch goal fetch for `HistoryCubit._resolveGoalsForAggregates` | `TodayCubit` week-dot goal loop (`today_cubit.dart` ~776) — separate perf path |
| New `getGoalsForLocalDays` on `UserPreferencesRepository` | Repository interface extraction (Story 16-1) |
| Repository + cubit tests | `RepaintBoundary` / IndexedStack (Story 16-3) |
| Preserve `getGoalForLocalDay` for all existing single-day callers | GoalRing persistence move (Story 15-2) |
| Branch `refacto` only | Version bump (deferred to Epic 15 close) |

### Critical baseline — read before editing

**Current N-call hotspot (`history_cubit.dart` 347–363):**

```347:363:lib/presentation/cubits/history_cubit.dart
  Future<Map<String, int>> _resolveGoalsForAggregates(
    List<ChartDayAggregate> aggregates,
  ) async {
    final distinctIsos = {
      for (final aggregate in aggregates)
        localDayIsoFromDateOnly(aggregate.localDay),
    }.toList(growable: false);
    if (distinctIsos.isEmpty) {
      return const {};
    }

    final goals = await Future.wait<int>([
      for (final iso in distinctIsos)
        userPreferences.getGoalForLocalDay(iso),
    ]);
    return Map.fromIterables(distinctIsos, goals);
  }
```

**Single-day semantics to preserve (`user_preferences_repository.dart` 45–63):**

```45:63:lib/data/repositories/user_preferences_repository.dart
  Future<int> getGoalForLocalDay(String localDayIso) async {
    return _session.withRetry((db) async {
      final rows = await db.rawQuery(
        '''
        SELECT goal
        FROM daily_goal_effective
        WHERE effective_from_local_day <= ?
        ORDER BY effective_from_local_day DESC
        LIMIT 1
        ''',
        [localDayIso],
      );
      if (rows.isEmpty) {
        return kDefaultStepGoal;
      }
      final raw = rows.first['goal'];
      final goal = raw is int ? raw : (raw as num).toInt();
      return goal > 0 ? goal : kDefaultStepGoal;
    });
  }
```

**Schema (migration v3):** table `daily_goal_effective` — PK `effective_from_local_day TEXT`, column `goal INTEGER NOT NULL CHECK (goal > 0)`. No `local_day` or `goal_steps` columns.

### Validated batch SQL (journal model — Epic 8)

**Approved for Story 15-1.** Replaces the audit §3.4 shorthand (`local_day`, `goal_steps`, `WHERE local_day IN (…)`) which does not match the production schema or goal-resolution semantics.

**Canonical SQL** (single round-trip; bind `?` = `max(requested local days)`):

```sql
SELECT effective_from_local_day, goal
FROM daily_goal_effective
WHERE effective_from_local_day <= ?
ORDER BY effective_from_local_day ASC
```

**Trade-off:** Résolution par balayage (walk) en Dart pour respecter le modèle de journal d'`effective_from` de l'Epic 8 — une ligne par *changement* de goal, pas une ligne par jour calendaire. Pour chaque jour D demandé, le goal effectif est la dernière entrée du journal où `effective_from_local_day ≤ D`. Un `WHERE local_day IN (…)` serait incorrect (jours intermédiaires héritent du goal précédent). Le walk en mémoire sur ~30 jours × quelques lignes de journal est négligeable ; le gain REF-03 vient du passage de N aller-retours inter-isolate sqflite à 1.

Audit §3.4 — diagnostic confirmé : le coût réel est N × transitions inter-isolate (sérialisation channel Flutter + curseurs SQLite), pas un blocage du thread UI (`Future.wait` lance déjà en parallèle).

### Call sites — do not break

| Caller | Method | Action |
|--------|--------|--------|
| `HistoryCubit._resolveGoalsForAggregates` | batch | **Migrate** to `getGoalsForLocalDays` |
| `HistoryCubit._resolveTodayGoal` | single | Keep `getGoalForLocalDay` |
| `TodayCubit` (goal, week dots) | single | No change this story |
| `BackgroundCollector` | single | No change this story |
| `StepBarChart` | reads `goalsByDay` map from state | No change — map shape unchanged |

### Batch resolution algorithm (journal walk)

Implement inside `getGoalsForLocalDays` — SQL above + Dart walk:

```dart
// Pseudocode — canonical SQL in § Validated batch SQL
final days = localDayIsos.toSet().toList()..sort();
if (days.isEmpty) return const {};

final rows = await db.rawQuery(
  '''
  SELECT effective_from_local_day, goal
  FROM daily_goal_effective
  WHERE effective_from_local_day <= ?
  ORDER BY effective_from_local_day ASC
  ''',
  [days.last],
);

var journalIndex = 0;
var currentGoal = kDefaultStepGoal;
final result = <String, int>{};

for (final day in days) {
  while (journalIndex < rows.length &&
      (rows[journalIndex]['effective_from_local_day'] as String) <= day) {
    final raw = rows[journalIndex]['goal'];
    final parsed = raw is int ? raw : (raw as num).toInt();
    currentGoal = parsed > 0 ? parsed : kDefaultStepGoal;
    journalIndex++;
  }
  result[day] = currentGoal;
}
return result;
```

Extract shared goal parsing if duplication with `getGoalForLocalDay` is >2 lines — keep minimal.

### Project structure notes

- Repository methods live in `lib/data/repositories/user_preferences_repository.dart` — sole writer to `user_preferences` + goal journal reads
- Cubit stays in `lib/presentation/cubits/history_cubit.dart` — no direct SQL in presentation layer
- Tests mirror existing layout: `test/data/repositories/` for repository, `test/presentation/cubits/` for cubit

### Testing requirements

| Test file | What to prove |
|-----------|---------------|
| `user_preferences_repository_test.dart` | Batch output == per-day `getGoalForLocalDay` for journal fixtures already used in group `daily goal history` |
| `history_cubit_test.dart` | Existing goal map tests still pass; new spy asserts `getGoalsForLocalDays` called once on 30-day refresh |
| Regression | `flutter test test/presentation/cubits/history_cubit_test.dart` full file |

Optional: document batch vs N-call timing in review brief using existing `test/dev/chart_benchmark_test.dart` harness — not required for AC.

### Architecture compliance

- **Transaction boundaries:** Read-only query inside `_session.withRetry` — same as `getGoalForLocalDay`; no UI-layer transactions
- **Time semantics:** Input keys are already ISO local days from `localDayIsoFromDateOnly(aggregate.localDay)` — do not recompute with device timezone
- **Single-writer rule:** No new writers to `daily_goal_effective`
- **Review before commit:** One commit per sub-task; review brief per `docs/project-context.md`

### Library / framework requirements

- `sqflite` ^2.x via existing `AstraDatabaseSession.withRetry` — no new dependencies
- Flutter SDK / Dart 3 — match `pubspec.yaml` constraints
- No `uuid`, no code generation

### Previous story intelligence (Epic 14)

Epic 14 closed at `v0.6.2+13` with lifecycle + post-purge hardening. Patterns to reuse:

- Sub-task gate: implement → review brief → Baptiste OK → commit
- Test extraction via spy subclasses (`_ChartAggregateSpyRepository` pattern in `history_cubit_test.dart`)
- `kDebugMode` logging on cubit failure paths — do not add user-facing errors for internal preference reads (`refreshGoal` already swallows and logs)

Story 14-2 landed `test/app_lifecycle_transition_test.dart` for mutex hardening — unrelated to this story but confirms refacto branch test style.

### Git intelligence (recent refacto commits)

| Commit | Relevance |
|--------|-----------|
| `c9d761d` Epic 14 close `v0.6.2+13` | Current base version for Epic 15 |
| `355a6d8` postPurgeRefresh hardening | `HistoryCubit.refresh` still in purge path — batch goals must not break silent refresh |
| `12c6dcd` / `3f9b29b` lifecycle mutex | Unrelated; confirms one-commit-per-sub-task on `refacto` |

### Latest technical notes

- **sqflite 2.x:** `rawQuery` on read path uses the plugin's background isolate — batching reduces message-passing overhead, not CPU on UI isolate
- **Journal vs per-day table:** Epic 8 chose effective-dated journal; batch resolver must respect retroactive goal changes (days before a change keep prior effective goal)
- **KPI-01:** History chart target <100ms with 90-day inject — this story removes up to 29 extra preference round-trips on 30-day windows; full KPI validation remains Epic 3 benchmark harness

### Project context reference

- Branch: `refacto` until merge review
- Review-before-commit workflow: `docs/project-context.md`
- Versioning at epic close: `epics-refacto.md` → Epic 15 = patch+1
- Story location: `_bmad-output/implementation-artifacts/stories/`

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Fixed Dart `as` vs `<=` precedence in journal walk (`compareTo` used instead)

### Completion Notes List

- Ultimate context engine analysis completed — comprehensive developer guide created
- Validated journal batch SQL canonized; audit §3.4 shorthand superseded (2026-06-18)
- **Sub-task A:** Added `getGoalsForLocalDays` with single SQL round-trip + journal walk; extracted `_normalizeJournalGoal` shared with `getGoalForLocalDay`; 3 new repository tests pass
- **Sub-task B:** `HistoryCubit._resolveGoalsForAggregates` now delegates to batch API; `_BatchGoalSpyPreferencesRepository` proves 1 batch call + 1 today-only `getGoalForLocalDay` on refresh/refreshGoal with 30-day inject
- `flutter analyze` clean on touched lib files; full `flutter test` suite green (no version bump per AC #6)

### File List

- `lib/data/repositories/user_preferences_repository.dart` (add `getGoalsForLocalDays`, `_normalizeJournalGoal`)
- `lib/presentation/cubits/history_cubit.dart` (wire batch method)
- `test/data/repositories/user_preferences_repository_test.dart` (batch semantics)
- `test/presentation/cubits/history_cubit_test.dart` (call-count spy + regression)
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` (status tracking)

### Change Log

- 2026-06-18: Batch SQL goal resolution for History chart (REF-03) — repository batch API + cubit wiring + tests
- 2026-06-18: Code review approved — story marked done
