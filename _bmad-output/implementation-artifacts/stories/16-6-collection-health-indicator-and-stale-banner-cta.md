# Story 16.6: Collection Health Indicator and Stale Banner CTA

Status: done

<!-- Refacto Epic 16 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 16-6 · refactoring-audit-master-v0.6.1.md §5.2 · REF-12 · UX-REF-01 · UX-REF-02 -->
<!-- Prerequisite: 16-5 done (granular BlocSelectors) — health indicator must use its own selector slice -->
<!-- Next in epic: 16-7 (Cold-Start Loading Shimmer) — do not start 16-7 in this story -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want to know when step collection is stale or permission is denied,
So that I can fix tracking issues without guessing.

## Acceptance Criteria

1. **Given** `TodayState.isStale`, `TodayState.status`, and `TodayState.lastIngestionUtc` already computed in `TodayCubit`  
   **When** Today screen renders  
   **Then** a collection health indicator appears **above the GoalRing** (inside the goal-ring card, top of the column) with three states (UX-REF-02, REF-12):
   - **Active:** `"Collection active ●"` (English — app is not i18n-ready until Epic 19; French UX-REF-02 strings are future ARB keys)
   - **Stale:** `"Last sync {relative time} ⚠"` where `{relative time}` comes from `formatRelativeTime(lastIngestionUtc, nowUtc)` (e.g. `"3 hours ago"`)
   - **Permission denied:** `"Sensor access revoked ✕"` when `status == TodayStatus.noPermission`

2. **Given** fresh data and granted permission  
   **When** Today loads  
   **Then** indicator shows the **active** state **or** is hidden — document the chosen behaviour in the review brief (recommendation: show subtle active line; audit §5.2 motivates visibility for diagnostics)

3. **Given** `_StaleBannerSlot` renders `StatusBannerVariant.staleCompact` when `isStale == true`  
   **When** data is stale  
   **Then** the banner is **tappable** (UX-REF-01)  
   **And** tap triggers `TodayCubit.refresh(silent: false)` (forced refresh)  
   **And** stale banner copy is updated from legacy `"Steps may be delayed — see My Data"` to an action-oriented line (e.g. `"Steps may be delayed — tap to refresh"`) — refacto audit §5.2 pivots CTA away from My Data navigation

4. **Given** `TodayStatus.noPermission`  
   **When** user needs to restore tracking  
   **Then** existing `_PermissionCta` below GoalRing remains unchanged (`openAppSettings()`)  
   **And** health indicator shows permission-denied state (priority over stale)

5. **Given** Story 16-5 granular selectors  
   **When** live step increments fire  
   **Then** health indicator and stale banner selectors do **not** rebuild (they depend on `isStale`, `status`, `lastIngestionUtc` — not `steps`)

6. **Given** full `flutter test --exclude-tags slow` suite  
   **When** run after changes  
   **Then** all tests pass — update `screen_smoke_test.dart`, `status_banner_test.dart`, and add focused health-indicator tests

7. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 16 closes with minor+1 (`0.7.0+15`) when all stories are done

**Covers:** REF-12 · UX-REF-01 · UX-REF-02 · Audit §5.2 (Today health + clickable stale banner)

## Tasks / Subtasks

- [x] **Sub-task A — Collection health indicator widget + BlocSelector slot** (AC: #1, #2, #4, #5)
  - [x] `(state) => state.isStale` only — read `today_screen.dart` and `today_state.dart` fully first
  - [x] Add `lib/presentation/widgets/collection_health_indicator.dart` — stateless widget taking `CollectionHealthDisplay` enum + optional `lastIngestionUtc` + `nowUtc`
  - [x] Derive display enum via pure helper (e.g. `lib/core/health/collection_health_display.dart` or private top-level in widget file):
    ```dart
    enum CollectionHealthDisplay { active, stale, permissionDenied }

    CollectionHealthDisplay deriveCollectionHealthDisplay({
      required TodayStatus status,
      required bool isStale,
    }) {
      if (status == TodayStatus.noPermission) return CollectionHealthDisplay.permissionDenied;
      if (isStale) return CollectionHealthDisplay.stale;
      return CollectionHealthDisplay.active;
    }
    ```
  - [x] Reuse `formatRelativeTime` from `lib/presentation/formatters/relative_time_formatter.dart` for stale copy
  - [x] Style: caption typography (`AstraTypography.captionFor`), status dot colours from `AstraColors` (`statusOk` / `statusStale` / `textMuted`) — mirror dot pattern from `background_status_card.dart` (8dp circle + label row)
  - [x] Add `_CollectionHealthSlot` in `today_screen.dart` with `BlocSelector` on a view-model slice `{ status, isStale, lastIngestionUtc }` — implement `_CollectionHealthViewModel` with manual `==`/`hashCode` (same pattern as Story 16-5)
  - [x] Insert slot inside `_GoalRingCard` **above** the GoalRing `BlocSelector` (first child in card `Column`)
  - [x] Active-state visibility: pick show vs hide; note decision in review brief
  - [x] Run `flutter analyze` on touched files
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Wire stale banner CTA + copy update** (AC: #3)
  - [x] Update `_StaleBannerSlot` to pass `onTap: () => context.read<TodayCubit>().refresh(silent: false)`
  - [x] Update `StatusBanner` staleCompact default copy (or add optional `message` override for staleCompact) to action-oriented refresh text
  - [x] Update `status_banner_test.dart` and `screen_smoke_test.dart` stale assertions for new copy
  - [x] Add widget test: tap stale banner invokes refresh (mock cubit or `_SeededTodayCubit` pattern from selector tests)
  - [x] **Do not** reintroduce `onNavigateToMyData` / My Data tab navigation — refacto UX-REF-01 specifies refresh or settings, not Data tab (Story 5.10 removed Data-tab stale banner by design)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests + selector isolation verification** (AC: #5, #6)
  - [x] Add `test/presentation/widgets/collection_health_indicator_test.dart` — pump three states, assert copy + semantics
  - [x] Extend `today_screen_selector_test.dart` (or new section): health slot and stale banner counters stay cold on live step tick emit
  - [x] Run `flutter test test/presentation/widgets/collection_health_indicator_test.dart`
  - [x] Run `flutter test test/presentation/screens/today_screen_selector_test.dart`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Manual: force stale via old `lastIngestionUtc` in debug / cubit test seed → banner tappable, indicator shows stale line
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Collection health indicator above GoalRing (REF-12, UX-REF-02) | Cold-start shimmer (Story **16-7**) |
| Tappable stale compact banner with refresh CTA (UX-REF-01) | Full `staleFull` banner on My Data tab (removed in Story 5.10) |
| Stale banner copy pivot (refresh, not My Data nav) | i18n / ARB migration (Epic **19**) |
| `BlocSelector` slice for health indicator (16-5 pattern) | Changing `TodayCubit` stale computation |
| Widget + formatter reuse; optional pure health enum helper | Extracting `MyDataCubit._deriveBackgroundStatus` (optional follow-up) |
| `today_screen.dart`, new indicator widget, `status_banner.dart`, tests | Battery/OEM deep-links (removed with BackgroundStatusCard in 5.10) |

### Epic terminology correction

Epics reference `TodayState.permissionStatus` — **this field does not exist**. Permission is represented by `TodayState.status == TodayStatus.noPermission`, already emitted by `TodayCubit._refreshImpl` when `_activityPermissionGranted()` returns false. Do **not** add a redundant `permissionStatus` field.

### Current Today layout (post Story 16-5)

```51:71:lib/presentation/screens/today_screen.dart
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // static title
                const _StaleBannerSlot(),           // BlocSelector → isStale
                const _WeekSection(),
                const _GoalRingCard(),              // ← insert health indicator HERE (top of card Column)
                const _PermissionCta(),             // BlocSelector → noPermission
                const _ActivityStatsSection(),
              ],
            ),
```

**Placement rule:** Health indicator lives **inside** `_GoalRingCard`, as the first child above the GoalRing `BlocSelector` — satisfies "above GoalRing" without affecting week-section selector isolation.

### Stale data pipeline (read-only — do not modify)

| Layer | Responsibility |
|-------|----------------|
| `isStaleData()` | `lib/core/health/stale_data_evaluator.dart` — 12h Android / 4h iOS thresholds |
| `TodayCubit._refreshImpl` / `refreshMetadata` | Computes `isStale` + `lastIngestionUtc` from `stepRepository.getLastIngestionUtc()` |
| `TodayState.isStale` | Boolean flag consumed by UI |
| `_StaleBannerSlot` | Shows compact banner when `isStale == true` — **currently no `onTap`** |

```270:293:lib/presentation/screens/today_screen.dart
class _StaleBannerSlot extends StatelessWidget {
  // ...
    return BlocSelector<TodayCubit, TodayState, bool>(
      selector: (state) => state.isStale,
      builder: (context, isStale) {
        if (!isStale) {
          return const SizedBox.shrink();
        }
        return const Column(
          children: [
            SizedBox(height: AstraSpacing.kSpaceMd),
            StatusBanner(variant: StatusBannerVariant.staleCompact),  // ← no onTap today
          ],
        );
      },
    );
```

### UX-REF-02 copy mapping (English until Epic 19)

| Design intent (French) | Implementation string (English) | Visual |
|------------------------|----------------------------------|--------|
| Collecte active ● | `Collection active ●` | Green dot (`statusOk`) |
| Dernière sync il y a Xh ⚠ | `Last sync {formatRelativeTime(...)} ⚠` | Amber dot (`statusStale`) |
| Accès capteur révoqué ✕ | `Sensor access revoked ✕` | Muted dot (`textMuted`) |

Use `DateTime.now().toUtc()` for `nowUtc` in the widget builder (same approach as `BackgroundStatusCard` receiving `nowUtc` from parent). Relative label updates on next cubit emit / rebuild — acceptable; do not add a periodic timer.

### Reuse — do not reinvent

| Existing artifact | Reuse for |
|-------------------|-----------|
| `formatRelativeTime` | Stale health copy |
| `BackgroundStatusCard` dot + row layout | Visual pattern reference (widget was removed from My Data UI but file remains) |
| `StatusBanner.onTap` + InkWell | Stale banner tappable behaviour (already tested in `status_banner_test.dart`) |
| `_PermissionCta` + `openAppSettings()` | Permission recovery — keep as-is; health indicator complements, does not replace |
| `MyDataCubit._deriveBackgroundStatus` logic | Reference for priority order: permission → stale → healthy (Today uses simplified 3-state enum) |

### Recommended `_CollectionHealthViewModel`

```dart
@immutable
final class _CollectionHealthViewModel {
  const _CollectionHealthViewModel({
    required this.display,
    required this.lastIngestionUtc,
  });

  final CollectionHealthDisplay display;
  final DateTime? lastIngestionUtc;

  static _CollectionHealthViewModel fromState(TodayState state) =>
      _CollectionHealthViewModel(
        display: deriveCollectionHealthDisplay(
          status: state.status,
          isStale: state.isStale,
        ),
        lastIngestionUtc: state.lastIngestionUtc,
      );

  @override
  bool operator ==(Object other) { /* display + lastIngestionUtc */ }

  @override
  int get hashCode => Object.hash(display, lastIngestionUtc);
}
```

**Selector rebuild triggers:** permission change, stale flag toggle, ingestion timestamp change — **not** step ticks.

### Stale banner CTA behaviour

| Condition | Tap action |
|-----------|------------|
| `isStale == true` (permission granted) | `TodayCubit.refresh(silent: false)` — shows loading skeleton briefly, re-fetches ingestion timestamp |
| Permission denied | Banner hidden (`isStale` may still be true but health indicator + `_PermissionCta` handle permission UX) |

Do **not** wire stale banner tap to My Data tab — `onNavigateToMyData` was removed from `AppScaffold`; Story 5.10 explicitly removed Data-tab stale banner. Refacto audit §5.2 specifies refresh or Android settings.

### `StatusBanner` copy change

Current staleCompact copy:

```38:39:lib/presentation/widgets/status_banner.dart
    StatusBannerVariant.staleCompact => 'Steps may be delayed — see My Data',
```

Update to action-oriented copy aligned with refresh CTA. If adding optional `message` for staleCompact, keep default in enum switch as fallback. Update semantics labels in tests accordingly.

### Previous story intelligence (16-5)

- Today screen uses five `BlocSelector` sections — add a **sixth** for health (`_CollectionHealthSlot`) inside `_GoalRingCard`, not a global `BlocBuilder`
- `@visibleForTesting` hooks: `todaySectionBuildProbe`, section keys — add `todayHealthSelectorSlice` / `Key('today_health_slot')` for isolation tests
- **Activity stats selector quirk:** use `Object`-typed selector + `@visibleForTesting` slice getter — tear-off on view-model `fromState` broke BlocSelector listener updates in widget tests
- Sub-task commit workflow: review brief → Baptiste OK → commit (`docs/project-context.md`)
- Version stays `0.6.3+14` until epic close
- Do **not** regress 16-5 build-isolation tests — run `today_screen_selector_test.dart` after changes

### Previous story intelligence (16-4 / 16-3)

- GoalRing has internal `RepaintBoundary` — health indicator is a sibling above ring selector, not inside GoalRing widget
- Tab-level `RepaintBoundary` in `AppScaffold` — orthogonal to this story

### Regression risks

| Risk | Mitigation |
|------|------------|
| Health indicator rebuilds every step tick | Selector must exclude `steps`, `activityMetrics`, `weekDays` |
| Duplicate permission UX clutter | Health line is compact; `_PermissionCta` button stays for actionable recovery |
| Stale banner + health indicator redundant copy | Banner = actionable CTA; indicator = inline diagnostic above ring — both required by AC |
| Breaking `status_banner_test.dart` | Update copy assertions when staleCompact text changes |
| `screen_smoke_test` stale test expects old copy | Update `find.textContaining('Steps may be delayed')` |
| Adding `permissionStatus` field to TodayState | Use existing `TodayStatus.noPermission` — epics typo |

### Architecture compliance

- **NFR-REF-05:** Presentation-only; no repository or cubit logic changes (stale already computed)
- **NFR-REF-01:** Health slot uses targeted selector — no extra rebuilds on 120 Hz step ticks
- **D-10 / Today hero:** GoalRing remains pure presentation; cubit remains single writer
- **Review-before-commit:** one commit per sub-task, review brief, wait for Baptiste OK
- **No new dependencies**

### Test files to run (minimum)

| File | Why |
|------|-----|
| `test/presentation/widgets/collection_health_indicator_test.dart` | New — three display states |
| `test/presentation/widgets/status_banner_test.dart` | Stale copy + onTap |
| `test/presentation/screens/today_screen_selector_test.dart` | Selector isolation regression |
| `test/presentation/screens/screen_smoke_test.dart` | TodayScreen stale banner group |
| `test/core/health/stale_data_evaluator_test.dart` | Unchanged — sanity if touching health folder |
| `flutter test --exclude-tags slow` | AC #6 — suite-wide regression |

### Manual verification steps

1. Grant permission, walk or inject steps → health shows **Collection active ●** (or hidden per design choice)
2. Mock old ingestion (cubit test seed or debug) → stale banner visible + tappable; tap triggers refresh spinner
3. Deny activity permission → health shows **Sensor access revoked ✕**; `_PermissionCta` visible below ring
4. DevTools Rebuild Stats: live step tick → health slot and stale banner stay cold (same method as Story 16-5)

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 16-6, REF-12, UX-REF-01, UX-REF-02]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §5.2 Today health indicator + clickable stale banner]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` — `isStale` computed but not surfaced; staleCompact stubs]
- [Source: `lib/presentation/screens/today_screen.dart` — `_StaleBannerSlot`, `_GoalRingCard`, `_PermissionCta`]
- [Source: `lib/presentation/cubits/today_state.dart` — `isStale`, `lastIngestionUtc`, `TodayStatus.noPermission`]
- [Source: `lib/presentation/cubits/today_cubit.dart` — stale computation in `_refreshImpl` / `refreshMetadata`]
- [Source: `lib/core/health/stale_data_evaluator.dart` — threshold logic]
- [Source: `lib/presentation/formatters/relative_time_formatter.dart` — `formatRelativeTime`]
- [Source: `lib/presentation/widgets/status_banner.dart` — staleCompact variant + `onTap`]
- [Source: `lib/presentation/widgets/background_status_card.dart` — dot + copy pattern reference]
- [Source: `lib/presentation/cubits/my_data_cubit.dart` — `_deriveBackgroundStatus` priority order]
- [Source: `_bmad-output/implementation-artifacts/stories/16-5-granular-bloc-selector-on-today-screen.md` — BlocSelector patterns, test hooks]
- [Source: `_bmad-output/implementation-artifacts/stories/5-10-data-screen-sovereignty-layout.md` — My Data stale banner removed]
- [Source: `docs/project-context.md` — review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

Claude (Cursor Agent)

### Debug Log References

- `flutter analyze` on touched lib files: no issues
- `flutter test --exclude-tags slow`: all pass

### Completion Notes List

- **Sub-task A:** Added `CollectionHealthIndicator` widget + `deriveCollectionHealthDisplay` helper. `_CollectionHealthSlot` uses `_CollectionHealthViewModel` BlocSelector inside `_GoalRingCard` (first child). **Active state:** shown subtly (always visible when fresh) per audit §5.2 recommendation.
- **Sub-task B:** Stale banner now tappable → `TodayCubit.refresh(silent: false)`. Copy updated to `"Steps may be delayed — tap to refresh"`.
- **Sub-task C:** Widget tests for 3 health states; selector isolation tests confirm health + stale banner stay cold on step ticks; stale banner tap test via `_TrackingRefreshCubit`.

### File List

- `lib/core/health/collection_health_display.dart` (new)
- `lib/presentation/widgets/collection_health_indicator.dart` (new)
- `lib/presentation/screens/today_screen.dart` (modified)
- `lib/presentation/widgets/status_banner.dart` (modified)
- `test/core/health/collection_health_display_test.dart` (new)
- `test/presentation/widgets/collection_health_indicator_test.dart` (new)
- `test/presentation/widgets/status_banner_test.dart` (modified)
- `test/presentation/screens/today_screen_selector_test.dart` (modified)
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` (modified)

## Change Log

- 2026-06-19: Story context created (create-story workflow) — ready-for-dev. Ultimate context engine analysis completed — comprehensive developer guide created.
- 2026-06-19: Story 16-6 implemented — collection health indicator, stale banner CTA, tests. Status → review.
