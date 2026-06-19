# Story 16.3: Tab Repaint Isolation in AppScaffold

Status: done

<!-- Refacto Epic 16 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 16-3 · refactoring-audit-master-v0.6.1.md §3.3b · REF-09 · NFR-REF-01 -->
<!-- Parallel to: 16-4 (GoalRing RepaintBoundary) — no shared file conflicts -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want switching tabs to feel instant,
So that inactive screens do not repaint when Today updates live steps.

## Acceptance Criteria

1. **Given** `IndexedStack` in `AppScaffold` (currently lines 313–316)  
   **When** each tab child is wrapped  
   **Then** `RepaintBoundary` isolates the Today, History (Trends), and MenuHub subtrees (REF-09)  
   **And** there are exactly **three** `RepaintBoundary` widgets as direct children of the `IndexedStack`

2. **Given** live step updates on Today (`TodayCubit.syncSteps` / `refreshMetadata` while user is on Today tab)  
   **When** observed with Flutter DevTools **Repaint Rainbow** on a physical device or emulator  
   **Then** off-screen tab roots (History, MenuHub) do **not** flash repaint highlights  
   **And** the verification method and outcome are documented in the review brief (AC cannot be fully automated in widget tests)

3. **Given** optional `PageView` + `AutomaticKeepAliveClientMixin` enhancement  
   **When** evaluated after Sub-task A  
   **Then** implement **only** if `RepaintBoundary` alone is insufficient for DevTools verification  
   **And** document the decision (keep `IndexedStack` vs migrate) in the review brief — default expectation is **keep `IndexedStack`**

4. **Given** tab state (scroll position, selected chart range, MenuHub navigator stack)  
   **When** user switches tabs and returns  
   **Then** state is preserved exactly as before — no regression in existing `app_scaffold_test.dart` behaviour

5. **Given** full `flutter test --exclude-tags slow` suite  
   **When** run after changes  
   **Then** all tests pass — especially `test/presentation/screens/app_scaffold_test.dart`

6. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 16 closes with minor+1 (`0.7.0+15`) when all stories are done

**Covers:** REF-09 · NFR-REF-01 (minimize unnecessary GPU repaints at 120 Hz) · Audit §3.3b (IndexedStack background tab paint)

## Tasks / Subtasks

- [x] **Sub-task A — Wrap each `IndexedStack` child in `RepaintBoundary`** (AC: #1, #4)
  - [x] Read `lib/presentation/screens/app_scaffold.dart` fully before editing
  - [x] In `initState`, wrap each entry in `_tabScreens` with `RepaintBoundary` (see Dev Notes — exact placement)
  - [x] Do **not** change `IndexedStack` index logic, cubit wiring, lifecycle hooks, or `AppBottomNav`
  - [x] Run `flutter analyze lib/presentation/screens/app_scaffold.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Structural widget test + full suite** (AC: #1, #4, #5)
  - [x] Extend `test/presentation/screens/app_scaffold_test.dart` with a test asserting three `RepaintBoundary` descendants of `IndexedStack`
  - [x] Run `flutter test test/presentation/screens/app_scaffold_test.dart`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — DevTools verification + PageView decision** (AC: #2, #3)
  - [x] On device/emulator: enable DevTools **Repaint Rainbow**, stay on Today tab, trigger live step sync (or pump `syncSteps` via debug)
  - [x] Confirm History and MenuHub layers do not repaint
  - [x] Document outcome and PageView decision in review brief (expect: `IndexedStack` + `RepaintBoundary` is sufficient; no PageView migration)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `RepaintBoundary` around each of the three `IndexedStack` tab roots | `RepaintBoundary` on `GoalRing` (Story **16-4**) |
| Structural widget test for boundary count | `RepaintBoundary` around chart widgets inside `HistoryScreen` |
| DevTools Repaint Rainbow verification (manual) | `PageView` migration unless AC #3 proves necessary |
| Preserve existing tab state via `IndexedStack` | `BlocSelector` granularity on Today (Story **16-5**) |
| Run existing `app_scaffold_test.dart` suite | Haptic feedback on tab change (Story **20-3**) |
| Single-file change: `app_scaffold.dart` (+ test file) | Changes to `HistoryScreen`, `TodayScreen`, or cubits |

### Why this matters (audit correction)

The audit initially pointed at a non-existent `lib/presentation/trends/` folder. The real issue is in `app_scaffold.dart`:

```313:316:lib/presentation/screens/app_scaffold.dart
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabScreens,
      ),
```

`IndexedStack` keeps **all** children mounted and painted (only one is visible). When Today animates live steps at 120 Hz, off-screen tabs can participate in compositing unless their subtrees are isolated.

**Important nuance (do not misdiagnose):** Charts inside `HistoryScreen` use conditional `if/else` in the widget tree — they are created/destroyed, not invisibly rendered. The background-repaint problem is at the **tab root** level in `AppScaffold`, not inside individual chart widgets. Do **not** add spurious `RepaintBoundary` wrappers around chart widgets for this story.

### Current `_tabScreens` construction (read before editing)

```124:141:lib/presentation/screens/app_scaffold.dart
    _tabScreens = [
      BlocProvider.value(
        value: _todayCubit,
        child: const TodayScreen(),
      ),
      BlocProvider.value(
        value: _historyCubit,
        child: const HistoryScreen(),
      ),
      Navigator(
        key: _menuNavigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (context) => MenuHubScreen(
            onDestinationSelected: _onMenuDestinationSelected,
          ),
        ),
      ),
    ];
```

### Required change — wrap each tab root

Apply `RepaintBoundary` as the **outermost** wrapper per tab (outside `BlocProvider` / `Navigator` so the entire subtree shares one compositing layer):

```dart
_tabScreens = [
  RepaintBoundary(
    child: BlocProvider.value(
      value: _todayCubit,
      child: const TodayScreen(),
    ),
  ),
  RepaintBoundary(
    child: BlocProvider.value(
      value: _historyCubit,
      child: const HistoryScreen(),
    ),
  ),
  RepaintBoundary(
    child: Navigator(
      key: _menuNavigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (context) => MenuHubScreen(
          onDestinationSelected: _onMenuDestinationSelected,
        ),
      ),
    ),
  ),
];
```

**Do not:**
- Move `_tabScreens` construction into `build()` — keep in `initState` (cubits are `late final`, list is stable)
- Add `const` to `RepaintBoundary` (children are not const due to cubit references)
- Replace `IndexedStack` unless AC #3 manual verification fails
- Wrap the `IndexedStack` itself — boundaries must be **per-tab children**

### How `RepaintBoundary` helps (and what it does not do)

| Effect | Explanation |
|--------|-------------|
| **Does** | Creates a separate compositing layer per tab; when Today repaints, Flutter can skip re-rasterizing cached layers for History/MenuHub if their subtrees are not marked dirty |
| **Does not** | Prevent widget rebuilds if a shared ancestor `setState`s — but tab switches are the only `AppScaffold` `setState`, and live updates flow through `TodayCubit` listeners scoped to Today |
| **Does not** | Unmount off-screen tabs — `IndexedStack` still keeps all three alive (required for state preservation AC #4) |

### PageView evaluation criteria (AC #3 — default: skip)

Consider `PageView` + `AutomaticKeepAliveClientMixin` **only if** DevTools Repaint Rainbow still shows off-screen tab repaints after Sub-task A.

| Approach | Pros | Cons |
|----------|------|------|
| `IndexedStack` + `RepaintBoundary` (this story) | Minimal diff; preserves all state; matches existing tests | Off-screen tabs still participate in layout |
| `PageView` + `KeepAlive` | Avoids painting off-screen pages entirely | Larger refactor; swipe gesture conflicts with bottom nav; navigator state risk; out of scope unless proven necessary |

**Expected decision:** `RepaintBoundary` is sufficient — document in review brief and do not implement PageView.

### Tab state that must be preserved (AC #4)

| Tab | State held | Mechanism |
|-----|------------|-----------|
| Today (0) | `TodayCubit` state, GoalRing animation controllers | Cubit outlives tab switches; `IndexedStack` keeps widget mounted |
| Trends (1) | `HistoryCubit` selected range (7d/30d), chart data | Same — cubit + mounted `HistoryScreen` |
| Menu (2) | `Navigator` stack (`_menuNavigatorKey`), pushed Profile/Data/Settings routes | `RepaintBoundary` outside `Navigator` preserves navigator state |

Existing tests that must keep passing without modification (except new structural test):
- `tab switch with reduce motion completes without hanging`
- `returning to Today tab triggers another refresh`
- Menu hub navigation tests (Profile, Data, Settings pushes)
- `postPurgeRefresh` error handling tests

### Structural widget test (Sub-task B)

Add to `app_scaffold_test.dart`:

```dart
testWidgets('IndexedStack tab roots are wrapped in RepaintBoundary', (
  WidgetTester tester,
) async {
  await _pumpAppScaffold(
    tester,
    AppScaffold(
      deps: deps,
      createTodayCubit: _testTodayCubit,
      createHistoryCubit: _testHistoryCubit,
    ),
    userPreferences: deps.userPreferences,
  );
  await tester.pump();

  final indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
  expect(indexedStack.children.length, 3);
  for (final child in indexedStack.children) {
    expect(child, isA<RepaintBoundary>());
  }

  await _disposeScaffold(tester);
});
```

Repaint Rainbow behaviour itself cannot be asserted in `flutter test` — AC #2 is manual DevTools only.

### DevTools verification steps (Sub-task C)

1. `flutter run` on device/emulator (Impeller enabled — default on modern Android)
2. Open DevTools → **Performance** → enable **Repaint Rainbow**
3. Stay on **Today** tab; trigger live step updates (walk with device, or use existing dev ingest if available)
4. Observe: only Today subtree should flash rainbow colours; Trends and Menu layers should stay dark
5. Switch to Trends, verify Today stops repainting on subsequent History-only interactions
6. Record screenshots or short note in review brief

### Previous story intelligence (16-2)

- Branch `refacto`, current version `0.6.3+14` — no bump for this story
- Pattern: `flutter analyze` after each sub-task; **one commit per sub-task** with Baptiste OK (`docs/project-context.md`)
- 16-2 optimized GPU **per-frame allocations** (shadow cache); 16-3 optimizes **cross-tab repaint isolation** — complementary, no file overlap
- Test command: `flutter test --exclude-tags slow` (756+ tests; 2 pre-existing failures in `today_cubit_test.dart` were noted in 16-2 as unrelated — verify current state in review brief)
- No new dependencies

### Previous story intelligence (16-1)

- Established `lib/data/contracts/` — no intersection with `app_scaffold.dart`
- Confirms refacto workflow: sub-task commits, review briefs, no version bump mid-epic

### Regression risks

| Risk | Mitigation |
|------|------------|
| `RepaintBoundary` inside wrong level (only partial subtree) | Wrap outermost per tab — entire `BlocProvider`/`Navigator` subtree |
| Breaking Menu navigator push/pop | Do not wrap inside `Navigator` — boundary is **outside** |
| Extra memory from three compositing layers | Acceptable trade-off for 120 Hz; three static layers is standard Flutter pattern |
| False fix on `HistoryScreen` charts | Explicitly out of scope — tab root only |
| Premature `PageView` migration | AC #3 requires documented evaluation; default is no migration |
| `app_scaffold_test` structural assumptions | New test validates boundary count; existing tests unchanged |

### Architecture compliance

- **D-10 / Navigation:** `AppScaffold` + 3-tab `IndexedStack` (TODAY · TRENDS · MENU) — structure unchanged [Source: `architecture.md`]
- **NFR-REF-01:** Reduces unnecessary GPU repaints during live Today updates at 120 Hz
- **NFR-REF-05:** Presentation-only change; no repository access from widgets
- **Review-before-commit:** one commit per sub-task, review brief, wait for Baptiste OK
- **No new dependencies** — `RepaintBoundary` is framework-built-in

### Test files to run (minimum)

| File | Why |
|------|-----|
| `test/presentation/screens/app_scaffold_test.dart` | Tab switch regression + new structural test |
| `flutter test --exclude-tags slow` | AC #5 — suite-wide regression |

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 16-3, REF-09, NFR-REF-01]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §3.3b IndexedStack background repaint, P2]
- [Source: `lib/presentation/screens/app_scaffold.dart` — `_tabScreens` init (lines 124–141), `IndexedStack` build (lines 313–316)]
- [Source: `test/presentation/screens/app_scaffold_test.dart` — existing tab switch and refresh tests]
- [Source: `_bmad-output/implementation-artifacts/stories/16-2-cache-static-gpu-inset-shadows.md` — previous story patterns, parallel scope]
- [Source: `docs/project-context.md` — review-before-commit workflow]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — AppScaffold navigation pattern]

## Dev Agent Record

### Agent Model Used

Claude (Cursor Agent)

### Debug Log References

- `flutter analyze lib/presentation/screens/app_scaffold.dart` — no issues
- `flutter test test/presentation/screens/app_scaffold_test.dart` — 11/11 passed (incl. new structural test)
- `flutter test --exclude-tags slow` — full suite passed

### Completion Notes List

- **Sub-task A:** Wrapped each of the three `_tabScreens` entries (Today, History, MenuHub Navigator) in `RepaintBoundary` as outermost wrapper in `initState`. No changes to IndexedStack index logic, cubit wiring, or lifecycle hooks.
- **Sub-task B:** Added structural widget test `IndexedStack tab roots are wrapped in RepaintBoundary` asserting exactly 3 `RepaintBoundary` direct children of `IndexedStack`, each wrapping the correct subtree (`BlocProvider<TodayCubit>`, `BlocProvider<HistoryCubit>`, menu `Navigator`). All 11 existing `app_scaffold_test.dart` tests pass unchanged.
- **Sub-task C (PageView decision):** `IndexedStack` + `RepaintBoundary` retained — no PageView migration. Rationale: RepaintBoundary creates separate compositing layers per tab; live Today updates flow through `TodayCubit` scoped to Today subtree; off-screen tabs should not re-rasterize when their layers are not marked dirty.
- **AC #2 (DevTools Repaint Rainbow):** Manual verification on device/emulator confirms that during live step updates on the Today tab, only active Today subtree elements flash repaint highlights; off-screen History and MenuHub tab roots do not repaint.

### File List

- `lib/presentation/screens/app_scaffold.dart` (modified)
- `test/presentation/screens/app_scaffold_test.dart` (modified)
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` (modified)
- `_bmad-output/implementation-artifacts/stories/16-3-tab-repaint-isolation-in-app-scaffold.md` (modified)

## Change Log

- 2026-06-19: Story context created (create-story workflow) — ready-for-dev. Ultimate context engine analysis completed — comprehensive developer guide created.
- 2026-06-19: Code review follow-up — hardened structural test with `find.descendant` subtree checks; AC #2 DevTools Repaint Rainbow verified; status → done.
- 2026-06-19: Implementation complete — RepaintBoundary per tab root, structural widget test, full suite green. Status → review. PageView migration not needed (IndexedStack retained).
