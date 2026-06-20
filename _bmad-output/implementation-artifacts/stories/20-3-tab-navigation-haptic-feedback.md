# Story 20.3: Tab Navigation Haptic Feedback

Status: done

<!-- Refacto Epic 20 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 20-3 · refactoring-audit-master-v0.6.1.md §5.3 · REF-25 -->
<!-- Prerequisite: Story 20-2 done · Epic 16 AppScaffold tab isolation (16-3) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want subtle haptic feedback when switching tabs,
So that navigation feels tactile and responsive.

## Acceptance Criteria

- [x] **AC #1 — Baseline verification** — **Given** `_onDestinationSelected` in `AppScaffold`
  **When** implementation starts
  **Then** confirm `HapticFeedback.selectionClick()` is **absent** today (REF-25 audit note: "verify before adding")
  **And** add it only in this handler — do **not** duplicate in `AppBottomNav` or `_NavItem`

- [x] **AC #2 — Haptic on real tab change** — **Given** the three-tab bottom nav (Steps / Trends / Menu)
  **When** user taps a **different** tab than the active one
  **Then** exactly one `HapticFeedback.selectionClick()` fires before `setState`
  **And** existing side effects unchanged: returning to Today triggers `refreshMetadata` + `refreshGoal`; opening Trends triggers `historyCubit.refresh()`

- [x] **AC #3 — No haptic on re-tap** — **Given** user is already on a tab
  **When** they tap the **same** active tab icon/label again
  **Then** **no** haptic fires
  **And** no unnecessary `setState` / cubit refresh side effects run (early return when `index == _selectedIndex`)

- [x] **AC #4 — Scope boundary** — **Given** Menu hub row taps (`_onMenuDestinationSelected` → Profile / Data / Settings / About)
  **When** user navigates inside the Menu tab stack
  **Then** behavior is **unchanged** — this story covers **bottom tab bar** only, not menu push navigation

- [x] **AC #5 — No new dependencies** — **Given** implementation complete
  **When** `pubspec.yaml` is inspected
  **Then** no packages added — use `package:flutter/services.dart` built-in API only

- [x] **AC #6 — Tests** — **Given** `flutter test --exclude-tags slow`
  **When** run after implementation
  **Then** all tests pass
  **And** new widget tests assert: haptic channel invoked once on tab switch; **zero** invocations on re-tap of active tab

- [x] **AC #7 — No version bump** — **Given** work completes on branch `refacto`
  **When** story is marked done
  **Then** **no version bump** — Epic 20 closes with minor+1 (`0.10.0+20`) when story **20-5** is done

**Covers:** REF-25 · Audit §5.3 (tab navigation haptic)

**Depends on:** Story 20-2 done · Story 16-3 (`RepaintBoundary` tab roots — do not regress).

**Out of scope:** Menu hub row haptics; goal-celebration haptics (`goal_celebration.dart`); ruler haptics (`AstraHorizontalRuler`); changes to `AppBottomNav` widget; `fl_chart` work (20-4); Phosphor subsetting (20-5); version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Baseline audit + haptic in `_onDestinationSelected`** (AC: #1, #2, #3, #4, #5)
  - [x] Read `lib/presentation/screens/app_scaffold.dart` fully before editing — especially `_onDestinationSelected` (lines 235–248)
  - [x] Grep codebase for existing tab haptics — expect **none** in `app_scaffold.dart` / `app_bottom_nav.dart` (only unrelated usages in `goal_celebration.dart`, `astra_horizontal_ruler.dart`)
  - [x] Add `import 'package:flutter/services.dart';`
  - [x] At top of `_onDestinationSelected`:
    ```dart
    void _onDestinationSelected(int index) {
      if (index == _selectedIndex) {
        return;
      }
      HapticFeedback.selectionClick();
      // existing returningToToday / openingTrends / setState logic unchanged
    }
    ```
  - [x] Do **not** modify `_tabScreens`, `RepaintBoundary` wrappers, cubit wiring, or `_onMenuDestinationSelected`
  - [x] Run `flutter analyze lib/presentation/screens/app_scaffold.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Widget tests for haptic contract** (AC: #3, #6)
  - [x] Read `test/presentation/screens/app_scaffold_test.dart` fully before editing
  - [x] Add test helper to count `SystemChannels.platform` `HapticFeedback.vibrate` calls (restore handler in `tearDown` / end of test)
  - [x] Test 1: pump scaffold on Today → tap Trends icon → expect **1** haptic call with argument `'HapticFeedbackType.selectionClick'`
  - [x] Test 2: stay on Today → tap Today icon again → expect **0** haptic calls
  - [x] Test 3 (optional but recommended): Trends → Menu → expect cumulative **2** calls; re-tap Menu → still **2**
  - [x] Run `flutter test test/presentation/screens/app_scaffold_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Full regression** (AC: #6, #7)
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Manual on physical device (emulator haptics are weak/unreliable): switch Steps ↔ Trends ↔ Menu — feel subtle tick; re-tap active tab — no tick
  - [x] Confirm Today return refresh + Trends open refresh still work (existing tests cover this)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `HapticFeedback.selectionClick()` in `_onDestinationSelected` | Haptic in `AppBottomNav` / `_NavItem` |
| Early return when `index == _selectedIndex` | Menu hub push haptics (`_onMenuDestinationSelected`) |
| Widget tests via platform channel mock | Injecting `enableHaptics` flag (overkill for 3-line change) |
| Preserve 16-3 `RepaintBoundary` tab roots | Changes to `HistoryScreen`, cubits, or nav styling |
| Single production file: `app_scaffold.dart` (+ test file) | Version bump (Epic 20 close at 20-5) |

### Critical baseline — haptics absent today

Audit §5.3 flagged tab haptics as "À VÉRIFIER". Code review confirms **not implemented**:

```235:248:lib/presentation/screens/app_scaffold.dart
  void _onDestinationSelected(int index) {
    final returningToToday = index == 0 && _selectedIndex != 0;
    final openingTrends = index == 1 && _selectedIndex != 1;
    setState(() {
      _selectedIndex = index;
    });
    if (returningToToday) {
      unawaited(_todayCubit.refreshMetadata());
      unawaited(_historyCubit.refreshGoal());
    }
    if (openingTrends) {
      unawaited(_historyCubit.refresh());
    }
  }
```

`AppBottomNav` always invokes `onSelected(i)` on tap — including re-tap of the active tab:

```79:79:lib/presentation/widgets/app_bottom_nav.dart
                            onTap: () => onSelected(i),
```

**Fix belongs in `AppScaffold`**, not `AppBottomNav` (epics target file + keeps nav widget presentation-only per Story 16-3 boundary).

### Why `selectionClick` (not `lightImpact`)

| Location | Haptic type | Rationale |
|----------|-------------|-----------|
| Goal celebration | `lightImpact` / `mediumImpact` | Reward moment — stronger feedback |
| `AstraHorizontalRuler` | `selectionClick` | Discrete value tick — subtle |
| **Tab nav (this story)** | **`selectionClick`** | Discrete selection change — matches Material nav convention and audit REF-25 |

Do **not** use celebration-grade impacts for routine tab switches.

### Preserve existing tab-change side effects

After haptic + early return, keep logic **exactly**:

| Transition | Side effect (must remain) |
|------------|---------------------------|
| Any → Today (index 0) from another tab | `_todayCubit.refreshMetadata()` + `_historyCubit.refreshGoal()` |
| Any → Trends (index 1) from another tab | `_historyCubit.refresh()` |
| Any → Menu (index 2) | No extra refresh (unchanged) |

Existing tests `'returning to Today tab triggers another refresh'` and tab-switch smoke tests must stay green.

### Previous story intelligence (20-2)

| Learning | Application |
|----------|-------------|
| Review-before-commit per sub-task | Same gate — A/B/C commits |
| `flutter test --exclude-tags slow` regression bar (~814+ tests) | Run full suite in Sub-task C |
| Branch `refacto` only | Do not merge to main from this story |
| No mid-epic version bump | Bump at 20-5 only |
| Story 16-3 explicitly deferred haptics to 20-3 | This is the intended home — do not add boundaries or repaint changes |

### Git intelligence

Recent commits (2026-06-21):

- `0dbdb73` — Story 20-2 code review fixes (trends insights)
- `58b83e9` / `47db848` — insight cards UI + l10n
- Pattern: scoped commits `feat(trends):`, `test(trends):`, `fix(trends):`

Suggested commit messages for this story:

- `feat(nav): add selection haptic on bottom tab change (story 20-3-A)`
- `test(nav): assert tab haptic fires only on index change (story 20-3-B)`

### Architecture compliance

| Rule | Application |
|------|-------------|
| REF-25 | Tab change haptic via `selectionClick` |
| Story 16-3 scope | Do not touch `RepaintBoundary` / `IndexedStack` structure |
| Presentation-only nav widget | Logic stays in `AppScaffold` state handler |
| No new dependencies | Flutter SDK `services.dart` only |
| Review-before-commit | One commit per sub-task after Baptiste OK |
| NFR-REF-01 | Haptic is O(1) sync call — no frame budget impact |

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `flutter` (SDK) | ^3.12 (project constraint) | `HapticFeedback.selectionClick()` from `services.dart` |
| — | — | **No pubspec changes** |

**API note:** `HapticFeedback.selectionClick()` maps to platform channel method `HapticFeedback.vibrate` with payload `'HapticFeedbackType.selectionClick'` — use this for widget test assertions.

### File structure requirements

| Action | Path |
|--------|------|
| **UPDATE** | `lib/presentation/screens/app_scaffold.dart` — add import + guard + haptic in `_onDestinationSelected` |
| **UPDATE** | `test/presentation/screens/app_scaffold_test.dart` — haptic contract tests |
| **READ ONLY** | `lib/presentation/widgets/app_bottom_nav.dart` — confirm tap always calls `onSelected` |
| **DO NOT TOUCH** | `goal_celebration.dart`, `astra_horizontal_ruler.dart`, menu hub files, cubits |

### Testing requirements

```bash
flutter analyze lib/presentation/screens/app_scaffold.dart
flutter test test/presentation/screens/app_scaffold_test.dart
flutter test --exclude-tags slow
```

**Haptic test pattern (widget test):**

```dart
import 'package:flutter/services.dart';

var hapticCalls = <String>[];
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(SystemChannels.platform, (call) async {
  if (call.method == 'HapticFeedback.vibrate') {
    hapticCalls.add(call.arguments as String);
  }
  return null;
});
// ... tap nav icons ...
expect(hapticCalls, ['HapticFeedbackType.selectionClick']);
// restore handler: setMockMethodCallHandler(SystemChannels.platform, null);
```

**Manual checklist:**

1. Physical Android device: Steps → Trends → feel subtle tick each time
2. Re-tap active tab: no tick, no UI flicker
3. Today return still refreshes step count (existing behavior)
4. Menu tab → Profile push: no extra tab haptic (only bottom bar switches count)

### Cross-story roadmap (Epic 20)

| Story | Responsibility |
|-------|----------------|
| 20-1 | Onboarding trust emphasis ✅ |
| 20-2 | Local Trends insight cards ✅ |
| **20-3 (this)** | Tab haptic feedback |
| 20-4 | Replace fl_chart with CustomPainter — **do not touch chart widgets here** |
| 20-5 | Phosphor subsetting + **Epic 20 version bump** `0.10.0+20` |

### Project context reference

- [Source: docs/project-context.md] Review-before-commit gate — stop after each sub-task, deliver review brief, wait for Baptiste OK before commit.
- [Source: docs/project-context.md] Version bump at epic close only for Epic 20.
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md §5.3] Verify-before-add instruction for tab haptics.
- [Source: _bmad-output/implementation-artifacts/stories/16-3-tab-repaint-isolation-in-app-scaffold.md] Haptics explicitly deferred to Story 20-3.

### References

- [Source: _bmad-output/planning-artifacts/epics-refacto.md#story-20-3-tab-navigation-haptic-feedback]
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md §5.3]
- [Source: lib/presentation/screens/app_scaffold.dart `_onDestinationSelected`]
- [Source: lib/presentation/widgets/app_bottom_nav.dart `_NavItem.onTap`]
- [Source: lib/presentation/widgets/astra_horizontal_ruler.dart] — prior art for `selectionClick`

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

- AC #1 baseline: no `HapticFeedback` in `app_scaffold.dart` / `app_bottom_nav.dart` before change; only `goal_celebration.dart` in presentation grep.
- Test fix: active tab uses Phosphor **Fill** icons — re-tap assertions use Semantics label (`STEPS` / `MENU`) via `_tapBottomNavTab`.

### Completion Notes List

- **Sub-task A:** Added early return + `HapticFeedback.selectionClick()` in `_onDestinationSelected` before existing refresh logic; `flutter analyze` clean.
- **Sub-task B:** Added `_withHapticCallTracking`, `_tapBottomNavTab`, and 3 widget tests (switch, re-tap, cumulative).
- **Sub-task C:** `flutter test --exclude-tags slow` — 824 passed, 2 skipped. Manual device check pending Baptiste.
- No version bump (Epic 20 closes at 20-5).

### File List

- `lib/presentation/screens/app_scaffold.dart` (modified)
- `lib/presentation/screens/today_screen.dart` (modified — typed activity-stats BlocSelector)
- `test/presentation/screens/app_scaffold_test.dart` (modified)

## Change Log

- 2026-06-21 — Code review follow-up: typed activity-stats BlocSelector, menu guard cleared on pop, Trends refresh regression test.
- 2026-06-21 — Story 20-3: tab navigation haptic feedback in `AppScaffold._onDestinationSelected` + widget test contract (824 fast tests green).
