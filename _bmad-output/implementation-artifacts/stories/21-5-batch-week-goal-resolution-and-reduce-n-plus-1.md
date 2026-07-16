# Story 21.5: Batch Week Goal Resolution and Reduce N+1

Status: in-progress

<!-- Post-audit Epic 21 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 21-5 · diagnostic-cold-start.md §B1 · AUD-06 · NFR-AUD-02 -->
<!-- Prerequisite: Stories 21-1…21-4 — done -->
<!-- Version bump: deferred to Epic 21 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want the week strip under Today to load without seven separate goal queries,
So that post–fast-path enrichment stays snappy (NFR-AUD-02).

## Acceptance Criteria

1. **Given** `_loadWeekDays` needs goals for 7 local days  
   **When** goals are resolved  
   **Then** a single batch API is used (`getGoalsForLocalDays`) (AUD-06)  
   **And** the per-day `getGoalForLocalDay` ×7 `Future.wait` loop is removed from `_loadWeekDays`

2. **Given** a day with no goal journal row (or only prior effective rows)  
   **When** the batch map is applied  
   **Then** default goal behaviour matches prior single-query semantics (`kDefaultStepGoal` via journal walk — same as `getGoalForLocalDay`)

3. **Given** mid-week goal changes (Epic 8 journal)  
   **When** `_loadWeekDays` builds `WeekDayStatus.goalMet`  
   **Then** each day uses its **historical** effective goal — identical to pre-batch behaviour (regression tests must pass)

4. **Given** `_loadWeekDays` is invoked from deferred enrichment (`_enrichAfterFastPath`) or full refresh paths  
   **When** week strip loads  
   **Then** only **one** `getGoalsForLocalDays` call runs per `_loadWeekDays` invocation  
   **And** `getChartDailyAggregates` behaviour is unchanged

5. **Given** unit tests  
   **When** story verification runs  
   **Then** a spy test proves `_loadWeekDays` path calls `getGoalsForLocalDays` once (not 7× `getGoalForLocalDay`) on `refresh` / `refreshFastPath` enrichment  
   **And** existing per-day `goalMet` tests (`goalMet respects per-day goals after mid-week change`, etc.) still pass  
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-06 · NFR-AUD-02 · diagnostic-cold-start §B1

**Depends on:** Stories 21-1…21-4 — **done**

**Out of scope:** `end_time` index (21-6), Trends tab guard (21-7), pedometer drain timeout (21-8), repository SQL changes (`getGoalsForLocalDays` already shipped in Story 15-1), deduplicating today's goal between `_resolveTodayGoal` and `_loadWeekDays` (optional follow-up — not AC), version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Map N+1 site and read UPDATE files** (AC: #1)
  - [x] Read fully: `lib/presentation/cubits/today_cubit.dart` — `_loadWeekDays` (L994–1026), all call sites (L286, 310, 564, 603, 658, 704)
  - [x] Read: `lib/data/repositories/user_health_metrics_repository.dart` — `getGoalsForLocalDays` (L60–98)
  - [x] Read reference: `lib/presentation/cubits/history_cubit.dart` — `_resolveGoalsForAggregates` (L347–359)
  - [x] Read: `test/presentation/cubits/history_cubit_test.dart` — `_BatchGoalSpyHealthMetricsRepository` pattern
  - [x] Confirm gap: `_loadWeekDays` uses `Future.wait` + 7× `getGoalForLocalDay` [Source: diagnostic-cold-start §B1, diagnostic-acces-concurrents step #30]
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (docs-only map if no code yet)

- [x] **Sub-task B — Refactor `_loadWeekDays` to batch resolution** (AC: #1, #2, #3)
  - [x] Build sorted ISO list: `weekDayIsos = [for (final day in weekDayKeys) localDayIsoFromDateOnly(day)]`
  - [x] Replace `Future.wait` loop with single `await userHealthMetrics.getGoalsForLocalDays(weekDayIsos)`
  - [x] Map goals back to `weekDayKeys` order when computing `goalMet` — preserve `goal > 0 && steps >= goal` formula verbatim
  - [x] Do **not** change `WeekDayStatus` shape, `CalendarWeek.daysContaining`, or aggregate fetch
  - [x] Do **not** modify `UserHealthMetricsRepository` — batch API is complete
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Spy test for batch call count** (AC: #4, #5)
  - [x] Add `_BatchGoalSpyHealthMetricsRepository` to `today_cubit_test.dart` (mirror `history_cubit_test.dart` L23–42)
  - [x] Test: `refresh()` → `getGoalsForLocalDaysCallCount == 1`, `getGoalForLocalDayCallCount == 1` (only `_resolveTodayGoal` in refresh path — not 7 extra)
  - [x] Test: `refreshFastPath()` + pump deferred enrichment → `getGoalsForLocalDaysCallCount == 1` on week load
  - [x] Verify existing `goalMet respects per-day goals after mid-week change` still passes unchanged
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task D — Regression** (AC: #5)
  - [ ] Run: `flutter test test/presentation/cubits/today_cubit_test.dart`
  - [ ] Run: `flutter test --exclude-tags slow`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `_loadWeekDays` → `getGoalsForLocalDays` | Repository SQL / journal walk algorithm |
| Spy test proving 1 batch call | Eliminating `_resolveTodayGoal` duplicate for today |
| Preserve `goalMet` / trophy semantics | `end_time` index (21-6), Trends guard (21-7) |
| All `_loadWeekDays` call sites benefit automatically | Parallelizing aggregates + goals in one `Future.wait` (optional, not required) |

### Current state (read before editing)

**N+1 in `_loadWeekDays`:**

```994:1026:lib/presentation/cubits/today_cubit.dart
  Future<List<WeekDayStatus>> _loadWeekDays() async {
    // ... weekDayKeys from CalendarWeek.daysContaining ...
    final aggregates = await stepAggregation.getChartDailyAggregates(days: 7);
    // ...
    final goals = await Future.wait<int>([
      for (final day in weekDayKeys)
        userHealthMetrics.getGoalForLocalDay(localDayIsoFromDateOnly(day)),
    ]);

    return [
      for (var i = 0; i < weekDayKeys.length; i++)
        WeekDayStatus(
          // ...
          goalMet:
              goals[i] > 0 && (stepsByDay[weekDayKeys[i]] ?? 0) >= goals[i],
        ),
    ];
  }
```

**Batch API already exists (Story 15-1) — do not reimplement:**

```60:98:lib/data/repositories/user_health_metrics_repository.dart
  Future<Map<String, int>> getGoalsForLocalDays(
    List<String> localDayIsos,
  ) async {
    // single withRetry + journal walk — output matches getGoalForLocalDay per day
  }
```

**HistoryCubit reference pattern (same repo, already migrated):**

```347:359:lib/presentation/cubits/history_cubit.dart
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
    return userHealthMetrics.getGoalsForLocalDays(distinctIsos);
  }
```

**Cold-start timeline:** `_loadWeekDays` runs in `_enrichAfterFastPath` **after** fast-path paint (Story 21-1) — step #29–30 in diagnostic-acces-concurrents. Batch reduces 7 SQLite round-trips to 1 on this deferred path.

**Duplicate today goal (informational, out of scope):** Full `refresh` also calls `_resolveTodayGoal()` → `getGoalForLocalDay(today)` in parallel with other queries; `_loadWeekDays` previously queried today again. Batch removes today's duplicate **within** `_loadWeekDays` only; `_resolveTodayGoal` single call remains.

### Target implementation (guidance)

```dart
Future<List<WeekDayStatus>> _loadWeekDays() async {
  // ... existing timeSnapshot, weekDayKeys, aggregates unchanged ...

  final weekDayIsos = [
    for (final day in weekDayKeys) localDayIsoFromDateOnly(day),
  ];
  final goalsByIso = await userHealthMetrics.getGoalsForLocalDays(weekDayIsos);

  return [
    for (var i = 0; i < weekDayKeys.length; i++)
      WeekDayStatus(
        localDay: weekDayKeys[i],
        weekdayLabel: CalendarWeek.weekdayLabelFor(weekDayKeys[i]),
        dayNumber: weekDayKeys[i].day,
        isToday: weekDayKeys[i] == referenceToday,
        isFuture: weekDayKeys[i].isAfter(referenceToday),
        goalMet: () {
          final goal = goalsByIso[weekDayIsos[i]]!;
          return goal > 0 && (stepsByDay[weekDayKeys[i]] ?? 0) >= goal;
        }(),
      ),
  ];
}
```

Prefer inline `final goal = goalsByIso[weekDayIsos[i]]!` over IIFE — repo guarantees every requested ISO is in the map. Do **not** add `?? kDefaultStepGoal` unless repo contract changes (it won't this story).

**Optional micro-opt (not required):** `Future.wait([getChartDailyAggregates(...), getGoalsForLocalDays(...)])` — saves serial latency but not in AC; skip unless trivial.

### Regression cautions

| Risk | Mitigation |
|------|------------|
| Wrong goal order vs `weekDayKeys` | Index via `weekDayIsos[i]`, not map iteration order |
| Journal mid-week change semantics | Run existing `goalMet respects per-day goals after mid-week change` test |
| Empty journal → default goal | Repo batch returns `kDefaultStepGoal` — verified in `user_health_metrics_repository_test.dart` L156–182 |
| Live today `goalMet` patch | `_patchTodayGoalMetForLiveSteps` unchanged — operates on loaded `WeekDayStatus` |
| Trophy X/7 badge | Derives from `weekDays[].goalMet` — no widget changes |

### UI / behaviour expectations (no widget changes)

| Scenario | User-visible effect |
|----------|---------------------|
| Week strip dots / trophy | Unchanged — same `goalMet` flags |
| Fast-path first paint | Unchanged — still empty `weekDays` until enrichment |
| Mid-week goal edit + refresh | Unchanged — historical per-day thresholds |
| Future days | Unchanged — `isFuture` + `goalMet` rules preserved |

### Architecture compliance

- **Presentation → contract:** `TodayCubit` calls `UserHealthMetricsRepositoryContract.getGoalsForLocalDays` — no direct SQL in cubit [Source: `architecture.md` layering].
- **Single-writer rule:** Read-only goal resolution — no new writers to `daily_goal_effective`.
- **Journal semantics (Epic 8):** Batch uses `effective_from_local_day ≤ D` walk — must match `getGoalForLocalDay`; do not use `WHERE local_day IN (...)` [Source: Story 15-1 Dev Notes].
- **NFR-AUD-02:** Contributes to ~100–200 ms full Today refresh target (with 21-6 index story).
- **OK-commit gate:** One commit per sub-task [Source: `docs/project-context.md`].

### Project structure notes

| Path | Role |
|------|------|
| `lib/presentation/cubits/today_cubit.dart` | **UPDATE** — `_loadWeekDays` batch call |
| `lib/data/repositories/user_health_metrics_repository.dart` | **READ only** — batch API complete |
| `lib/presentation/cubits/history_cubit.dart` | **READ** — reference migration |
| `lib/core/time/local_day_formatter.dart` | **READ** — `localDayIsoFromDateOnly` |
| `test/presentation/cubits/today_cubit_test.dart` | **UPDATE** — spy + call-count test |
| `test/presentation/cubits/history_cubit_test.dart` | **READ** — `_BatchGoalSpyHealthMetricsRepository` template |
| `test/data/repositories/user_health_metrics_repository_test.dart` | **READ** — batch ≡ per-day equivalence tests |

### Testing requirements

- **Primary:** `flutter test test/presentation/cubits/today_cubit_test.dart`
- **Regression:** `flutter test --exclude-tags slow`
- **Spy pattern:** Copy `_BatchGoalSpyHealthMetricsRepository` from `history_cubit_test.dart`; inject via `buildCubit(healthMetrics: spy)`
- **Must-pass existing tests:**
  - `marks past day goalMet when steps meet daily goal`
  - `goalMet respects per-day goals after mid-week change`
  - Week strip layout tests in `week strip` group
- **For `refreshFastPath` enrichment test:** use `await cubit.refreshFastPath()` then `await Future<void>.delayed(Duration.zero)` or pump async microtasks until `weekDays.length == 7` — match existing deferred-test patterns in file
- **Do not** add timing-based performance assertions — call-count spy is sufficient for AC

### Previous story intelligence (21-4)

- **Pattern:** Small targeted change + spy/call-count test + full regression; OK-commit gate per sub-task.
- **Scope discipline:** Only `_loadWeekDays` goal resolution — do not touch ingestion lock, monitor seed, or fast-path orchestration.
- **Deferred items:** Document in `deferred-work.md` only if review surfaces pre-existing issues — this story is unlikely to need deferrals.

### Git intelligence

Recent Epic 21 commits (adjacent — lock/session, not week goals):
- `1265784` — story 21-4 done + review
- `09d1925` — lock tests + `database_closed` retry
- `05c1102` — story 21-3 done + review tests

Pattern: one concern per commit; cubit perf change isolated from services/DB work.

### Latest tech notes

- No new packages. `getGoalsForLocalDays` already on `UserHealthMetricsRepositoryContract`.
- Batch reduces N inter-isolate sqflite channel round-trips to 1 — gain is orchestration, not UI thread blocking [Source: Story 15-1 trade-off note].
- Repository deduplicates input via `.toSet().toList()..sort()` — passing 7 ISO strings (possibly with duplicate boundary days) is safe.

### Project context reference

- OK-commit gate: sub-task → review brief → Baptiste OK → commit
- Tests: `flutter test --exclude-tags slow`
- No version bump until Epic 21 closes

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 21-5, AUD-06]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` — §B1 batch goals]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-acces-concurrents.md` — step #30 `getGoalForLocalDay` ×7]
- [Source: `_bmad-output/implementation-artifacts/stories/15-1-batch-sql-goal-resolution-for-history.md` — batch algorithm rationale]
- [Source: `_bmad-output/implementation-artifacts/stories/21-1-fast-path-today-refresh-for-cold-start.md` — deferred `_loadWeekDays`, explicit out-of-scope for 21-1]
- [Source: `_bmad-output/implementation-artifacts/stories/21-4-route-ingestion-lock-through-session-with-retry.md` — epic patterns]
- [Source: `lib/presentation/cubits/today_cubit.dart` — `_loadWeekDays`]
- [Source: `test/presentation/cubits/today_cubit_test.dart` — goalMet regression fixtures]
- [Source: `docs/project-context.md`]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

## Change Log

- 2026-07-16: Story context created (ready-for-dev) — ultimate context engine analysis completed
