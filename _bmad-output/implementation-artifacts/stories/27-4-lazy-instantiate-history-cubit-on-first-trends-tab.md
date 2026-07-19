# Story 27.4: Lazy Instantiate HistoryCubit on First Trends Tab

Status: done

<!-- Post-audit Epic 27 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 27-4 · diagnostic-cold-start.md §Phase C1 · AUD-11 -->
<!-- Prerequisite: Stories 27-1, 27-2, 27-3 done; Epic 21 guard (21-7) in place -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want Trends data work to start only when I open the Trends tab,
So that cold start does not pay for History cubit setup and IndexedStack mount cost.

## Acceptance Criteria

1. **Given** app launch with default Today tab selected
   **When** `AppScaffold` initializes
   **Then** `HistoryCubit` is **not** constructed eagerly in `initState` (AUD-11, diagnostic-cold-start §C1)
   **And** `HistoryScreen` is **not** mounted in the `IndexedStack` until first Trends visit
   **And** cubit is created on first navigation to Trends (`_selectedIndex == 1`) via existing `createHistoryCubit` / `onHistoryCubitReady` hooks

2. **Given** user opens Trends for the first time
   **When** cubit is created
   **Then** `onHistoryCubitReady` fires **once** at creation (not in `initState`)
   **And** existing `openingTrends` path calls `_historyCubit.refresh()` — first-visit contract unchanged
   **And** Epic 21 guard (`_onIngestionComplete` only refreshes History when Trends selected) still holds

3. **Given** user switches away and back to Trends
   **When** tab is reselected
   **Then** scroll position / period selection persist (session behaviour unchanged)
   **And** cubit instance is retained (not recreated each visit)
   **And** `IndexedStack` keeps the History subtree alive after first mount (`AutomaticKeepAliveClientMixin` or equivalent)

4. **Given** cross-cubit callbacks before Trends was ever opened (`postGoalUpdate`, `postImportRefresh`, `returningToToday` → `refreshGoal`)
   **When** `_historyCubit` is still null
   **Then** those paths no-op safely (no crash, no eager cubit creation)
   **And** data refresh on first Trends open via `openingTrends` → `refresh()` still loads fresh data

5. **Given** `postPurgeRefresh` or resume pipeline paths that need History refresh
   **When** History cubit was never created
   **Then** use `_ensureHistoryCubit()` (or equivalent) before refresh **only** in explicit data-mutation paths (purge/import) — not on boot
   **And** coordinator resume path `_session.historyCubit?.refresh` remains null-safe (already optional)

6. **Given** widget tests or integration tests construct `AppScaffold`
   **When** this story ships
   **Then** tests updated for lazy init (no assumption that History cubit exists before Trends selection)
   **And** `flutter test test/presentation/screens/app_scaffold_test.dart --exclude-tags slow` passes
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-11 · diagnostic-cold-start.md §Phase C1 · diagnostic-etat-chargement.md §4 (History zombie loading note)

**Depends on:** Stories 27-1…27-3 (boot polish), 21-7 (ingestion tab guard). Last story in Epic 27 boot-polish tranche.

**Out of scope:** Defer `_buildDayMetricsCache` (AUD-12 / diagnostic C3), SQL chart aggregation (AUD-10), changing `HistoryCubit` refresh internals, version bump (Epic 27 close → patch+1, build+1).

## Tasks / Subtasks

- [x] **Sub-task A — Lazy cubit factory + null-safe callbacks** (AC: #1, #4, #5)
  - [x] Read fully: `lib/presentation/screens/app_scaffold.dart` (entire file), `lib/app.dart` (coordinator hooks L106–108, L183–185)
  - [x] Replace `late final HistoryCubit _historyCubit` with `HistoryCubit? _historyCubit`
  - [x] Add `@visibleForTesting` or private `_ensureHistoryCubit({bool notifyReady = true})` that:
    - Returns existing instance if non-null
    - Creates via `widget.createHistoryCubit?.call(widget.deps) ?? HistoryCubit(...)` on first call
    - Calls `widget.onHistoryCubitReady?.call(cubit)` once at creation
    - Does **not** call `refresh()` — tab switch owns first refresh
  - [x] Update all `_historyCubit` call sites to null-safe or `_ensureHistoryCubit()` as appropriate:
    | Call site | Before Trends opened | After Trends opened |
    |-----------|---------------------|---------------------|
    | `TodayCubit.postGoalUpdate` → `refreshGoal` | no-op | refreshGoal |
    | `MyDataCubit.postImportRefresh` → `refresh(silent)` | `_ensureHistoryCubit()` then refresh | refresh |
    | `MyDataCubit.postGoalUpdate` → `refreshGoal` | no-op | refreshGoal |
    | `_runPostPurgeRefresh` → `refresh(silent)` | `_ensureHistoryCubit()` then refresh | refresh |
    | `_onIngestionComplete` | guard `_selectedIndex == 1` + cubit must exist | unchanged |
    | `_onDestinationSelected` openingTrends | `_ensureHistoryCubit()` + `refresh()` | refresh |
    | `_onDestinationSelected` returningToToday → `refreshGoal` | no-op if null | refreshGoal |
    | `dispose` | close only if non-null | close |
  - [x] Remove eager `_historyCubit` creation and `onHistoryCubitReady` call from `initState`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Lazy IndexedStack History tab** (AC: #1, #3)
  - [x] Defer `HistoryScreen` mount: use placeholder (`const SizedBox.shrink()` or `_HistoryTabPlaceholder`) at index 1 until first Trends visit
  - [x] On first `_onDestinationSelected(index == 1)`: `_ensureHistoryCubit()`, build `RepaintBoundary > BlocProvider.value > HistoryScreen`, swap into `_tabScreens[1]` via `setState`
  - [x] Wrap History tab root in `AutomaticKeepAliveClientMixin` stateful widget so IndexedStack preserves scroll/period after first mount
  - [x] Preserve RepaintBoundary wrapper (existing perf test expects it)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests + regression** (AC: #2, #3, #6)
  - [x] Extend `test/presentation/screens/app_scaffold_test.dart`:
    - **New:** `HistoryCubit` not created on init — track `createHistoryCubit` invocations (expect 0 after pump; 1 after Trends tap)
    - **New:** `onHistoryCubitReady` fires on first Trends open, not at init
    - **Update:** `IndexedStack tab roots` — index 1 is placeholder until Trends tap; after tap, BlocProvider+HistoryScreen present
    - **Update:** `ingestion on Today tab` — `historyCubit` stays null; `createHistoryCubit` never called
    - **Keep green:** `opening Trends tab triggers history refresh`, ingestion guard group, postPurgeRefresh tests
  - [x] Run `flutter test test/presentation/screens/app_scaffold_test.dart --exclude-tags slow`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Lazy `HistoryCubit` creation in `AppScaffold` | Defer kcal insights cache (AUD-12) |
| Lazy `HistoryScreen` IndexedStack mount | SQL-side chart aggregation (AUD-10) |
| Null-safe cross-cubit callbacks | `HistoryCubit` internal refresh logic |
| Widget tests for lazy init contract | Version bump until Epic 27 close |
| Preserve Epic 21 ingestion tab guard | Changing tab count or nav structure |
| OK-commit sub-task gate | `main.dart` boot timing (27-1…27-3 done) |

### Root cause (read before editing)

**Partial lazy Trends (AUD-11 / C6):** `HistoryCubit` skips `refresh()` at init but is still **eagerly constructed** in `initState` and **always mounted** in `IndexedStack` — paying constructor + widget tree cost on every cold start [Source: `app_scaffold.dart` L90–95, L141–145, `diagnostic-cold-start.md` §C6, §Phase C1].

Diagnostic C1: instantiate `HistoryCubit` only on first `_onDestinationSelected(index == 1)`; replace fixed IndexedStack with lazy tab or deferred creation + keep-alive [Source: `diagnostic-cold-start.md` L269–274].

Combined with 27-1 (parallel prefs), 27-2 (WM defer), 27-3 (notification overlap), this completes Epic 27 boot polish toward faster Today first paint.

### Current implementation (MUST understand)

**Eager History cubit + IndexedStack mount today:**

```90:145:lib/presentation/screens/app_scaffold.dart
    _historyCubit =
        widget.createHistoryCubit?.call(widget.deps) ??
        HistoryCubit(
          stepAggregation: widget.deps.stepAggregation,
          userHealthMetrics: widget.deps.userHealthMetrics,
        );
    // ...
    widget.onHistoryCubitReady?.call(_historyCubit);
    _tabScreens = [
      RepaintBoundary(/* Today */),
      RepaintBoundary(
        child: BlocProvider.value(
          value: _historyCubit,
          child: const HistoryScreen(),
        ),
      ),
      RepaintBoundary(/* Menu Navigator */),
    ];
```

**Already lazy (preserve):**
- No `HistoryCubit.refresh()` in `initState` or `_initialRefresh`
- First full refresh on Trends tab via `openingTrends` [Source: L247–257]
- Ingestion guard from Story 21-7 [Source: L233–238]

**Tab index map (do not invert):**

| `_selectedIndex` | Tab | Icon |
|------------------|-----|------|
| `0` | Today / Steps | `sneakerMove` |
| `1` | Trends | `chartBar` |
| `2` | Menu | `list` |

### Recommended implementation pattern

```dart
HistoryCubit? _historyCubit;
bool _historyTabMounted = false;

HistoryCubit _ensureHistoryCubit() {
  if (_historyCubit != null) return _historyCubit!;
  _historyCubit = widget.createHistoryCubit?.call(widget.deps) ??
      HistoryCubit(
        stepAggregation: widget.deps.stepAggregation,
        userHealthMetrics: widget.deps.userHealthMetrics,
      );
  widget.onHistoryCubitReady?.call(_historyCubit!);
  return _historyCubit!;
}

void _mountHistoryTabIfNeeded() {
  if (_historyTabMounted) return;
  _ensureHistoryCubit();
  _tabScreens[1] = RepaintBoundary(
    child: _KeepAliveHistoryTab(
      cubit: _historyCubit!,
    ),
  );
  _historyTabMounted = true;
}

// In _onDestinationSelected, when openingTrends:
_mountHistoryTabIfNeeded();
setState(() => _selectedIndex = index);
unawaited(_historyCubit!.refresh());
```

**`_KeepAliveHistoryTab`:** small private `StatefulWidget` with `AutomaticKeepAliveClientMixin`, `wantKeepAlive => true`, child `BlocProvider.value` + `HistoryScreen`.

**Why not remove IndexedStack:** Preserves Today/Menu state and matches existing architecture; only defer History subtree construction.

**Why `_ensureHistoryCubit` on purge/import but not goal-update callbacks:** Purge/import mutate DB globally — History must refresh even if user never opened Trends. Goal-only updates can wait until first Trends visit (Today ring already updates via TodayCubit).

### Coordinator integration (do not break)

```106:108:lib/app.dart
  void _onHistoryCubitReady(HistoryCubit cubit) {
    _coordinator.onHistoryCubitReady(cubit);
  }
```

- `onHistoryCubitReady` must fire **when cubit is first created**, not at scaffold init
- `onHistoryCubitDisposed` + `bindHistoryCubit(null)` on dispose unchanged
- Resume path already null-safe: `_session.historyCubit?.refresh(silent: true)` [Source: `app_lifecycle_coordinator.dart` L237]

### Cross-cubit callback matrix

| Source | Method | Pre-Trends behaviour | Post-Trends |
|--------|--------|---------------------|-------------|
| `TodayCubit` | `postGoalUpdate` | skip `refreshGoal` | call |
| `MyDataCubit` | `postImportRefresh` | `_ensureHistoryCubit()` + refresh | refresh |
| `MyDataCubit` | `postGoalUpdate` | skip | refreshGoal |
| `MyDataCubit` | `postPurgeRefresh` | `_ensureHistoryCubit()` + refresh | refresh |
| Ingestion | `_onIngestionComplete` | skip (guard + null) | refresh if tab 1 |
| Tab switch | openingTrends | create + mount + refresh | refresh |
| Tab switch | returningToToday | skip refreshGoal if null | refreshGoal |

**Critical:** `TodayCubit` constructor references `postGoalUpdate` closure that captures `_historyCubit` — define closure **after** field declaration; use null-aware call inside closure body.

### Architecture compliance

- **Layering:** Presentation-only change in `app_scaffold.dart`; no DI or repository edits
- **State management:** `HistoryCubit` lifecycle owned by scaffold; coordinator binding deferred until first create
- **D-22 / navigation:** Keep 3-tab `IndexedStack` + floating pill nav — no GoRouter
- **Epic 21 fast path:** No changes to `TodayCubit`, lifecycle coordinator boot, or ingestion pipeline
- **A11y / UX:** History screen semantics unchanged once mounted; no loading regression on first Trends visit (existing loading state in `HistoryCubit`)

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/screens/app_scaffold.dart` | **UPDATE** — lazy cubit + lazy tab mount |
| `test/presentation/screens/app_scaffold_test.dart` | **UPDATE** — lazy init tests + fix IndexedStack expectations |
| `lib/app.dart` | **READ ONLY** — verify hooks unchanged |
| `lib/core/services/app_lifecycle_coordinator.dart` | **READ ONLY** — already null-safe |
| `lib/presentation/cubits/history_cubit.dart` | **DO NOT CHANGE** |
| `lib/main.dart` | **DO NOT TOUCH** |

### Testing requirements

- Default gate: `flutter test --exclude-tags slow`
- Targeted: `test/presentation/screens/app_scaffold_test.dart`
- Use counting wrapper around `createHistoryCubit` factory to assert call count
- Use `onHistoryCubitReady` callback counter in new test
- Existing tests using `_RefreshCountingHistoryCubit` remain valid once Trends tab is tapped first
- OK-commit gate per `docs/project-context.md` — one commit per sub-task A/B/C

### Cross-story context (Epic 27)

| Story | Scope | Interaction |
|-------|-------|-------------|
| 27-1 (done) | Parallel pref reads | Reduced DI latency — independent of this story |
| 27-2 (done) | WM after `runApp` | Boot path complete |
| 27-3 (done) | Non-blocking notification init | Boot path complete |
| **27-4 (this)** | Lazy HistoryCubit | First `app_scaffold.dart` change in Epic 27 — closes boot polish tranche |
| Epic 28 | UX coherence | Separate epic — no overlap |

### Previous story intelligence

**27-3:** Boot helpers in `main.dart`; `@visibleForTesting` pattern; sub-task OK-commit gate; explicitly noted 27-4 targets `app_scaffold.dart` with no overlap.

**27-2 / 27-1:** Boot timing only — scaffold untouched until this story.

**21-7:** Ingestion tab guard (`if (_selectedIndex == 1)`) — **must remain**; with lazy init, Today-tab ingestion should also skip because cubit is null. Do not remove guard.

Apply delivery pattern from 27-3: minimal focused diff + targeted tests; three sub-task commits.

### Git intelligence (recent patterns)

Recent commits (Epic 27):
- `f9b5ca3` / `7888649` / `e6e2128` — Story 27-3 notification boot
- `f7686ea` / `9a34058` — Story 27-2 WM defer
- `e380058` — Story 27-1 parallel prefs

Follow: single-file production change (`app_scaffold.dart`), extend existing test file, no broad refactors.

### Latest tech notes

- **flutter_bloc ^9.x** — `BlocProvider.value` for retained cubit after lazy create; no package changes
- **AutomaticKeepAliveClientMixin** — standard Flutter pattern for IndexedStack tab retention; no new dependencies
- **IndexedStack** — `index` prop unchanged; only `children[1]` content swaps from placeholder to keep-alive History subtree

### Project context reference

- OK-commit gate: `docs/project-context.md` §Development Workflow
- Version bump deferred to Epic 27 close: patch+1, build+1 — `.cursor/rules/app-versioning.mdc`
- Test command: `flutter test --exclude-tags slow`

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` §Story 27-4, AUD-11]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` §C6, §Phase C1]
- [Source: `_bmad-output/planning-artifacts/audits/README.md` — History eager boot → E27-4]
- [Source: `lib/presentation/screens/app_scaffold.dart`]
- [Source: `lib/app.dart` — coordinator hooks]
- [Source: `lib/core/services/app_lifecycle_coordinator.dart` L237]
- [Source: `_bmad-output/implementation-artifacts/stories/21-7-guard-trends-refresh-on-ingestion-by-active-tab.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/27-3-non-blocking-notification-init-before-first-frame.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Lazy `HistoryCubit?` + `_ensureHistoryCubit()` — création au 1er Trends ou purge/import uniquement
- Placeholder `SizedBox.shrink()` index 1 jusqu'au 1er visit Trends ; `_KeepAliveHistoryTab` avec `AutomaticKeepAliveClientMixin`
- Callbacks null-safe : goal-update no-op pre-Trends ; purge/import via `_ensureHistoryCubit()`
- Tests : lazy init, onHistoryCubitReady timing, IndexedStack placeholder, ingestion guard
- `flutter test --exclude-tags slow` — vert

### File List

- `lib/presentation/screens/app_scaffold.dart`
- `test/presentation/screens/app_scaffold_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

### Change Log

- 2026-07-19: Lazy HistoryCubit + deferred HistoryScreen mount (Story 27-4, Epic 27 boot polish close)
- 2026-07-19: Code review approved — story done, Epic 27 closed, version 0.11.4+29
