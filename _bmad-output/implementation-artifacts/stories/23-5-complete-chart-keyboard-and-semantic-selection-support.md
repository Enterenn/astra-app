# Story 23.5: Complete Chart Keyboard and Semantic Selection Support

Status: review

<!-- Post-audit Epic 23 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 23-5 · diagnostic-accessibilité-statique.md charts Majeur · AUD-29 · NFR-AUD-05 -->
<!-- Prerequisite: Story 23-4 — done (segmented control keyboard focus; PeriodToggle on History inherits) -->
<!-- Version bump: deferred to Epic 23 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **keyboard / TalkBack user**,
I want chart bars to be focusable with announced selection,
So that Trends charts are not touch-only.

## Acceptance Criteria

1. **Given** `AstraBarChartCore` plot area (currently `GestureDetector` only — L108–122)
   **When** user Tabs to the chart on History/Trends
   **Then** plot receives keyboard focus with **visible** focus feedback (AUD-29, NFR-AUD-05)
   **And** focus uses `FocusableActionDetector`, `Focus` + `Shortcuts`/`Actions`, or equivalent — not touch-only `GestureDetector`

2. **Given** chart plot has keyboard focus and `barCount > 0`
   **When** user presses **ArrowLeft** / **ArrowRight** (or **Home** / **End** for first/last bar)
   **Then** focus moves between bar indices without changing selection until activation
   **And** focused bar has a visual indicator distinct from selected-bar highlight (23-4 lesson: focus ≠ selection)

3. **Given** chart plot has keyboard focus on bar index `i`
   **When** user presses **Enter** or **Space**
   **Then** selection toggles like touch: first activation selects bar `i`; second activation on same bar deselects (AUD-29)
   **And** **Escape** clears selection when a bar is selected
   **And** tap behaviour (tap bar / tap gap / re-tap deselect) is unchanged

4. **Given** `StepBarChart._ReadyChart` with a selected bar (`_touchedIndex != null`)
   **When** selection changes (touch or keyboard)
   **Then** outer `Semantics.label` continues to use `_selectionSemanticsLabel` (existing — do not remove)
   **And** `liveRegion: true` is set while a bar is selected so TalkBack announces the new summary (AUD-29, diagnostic L245–248)
   **And** when no bar selected, label reverts to `trendsStepBarChartSemantics` without liveRegion

5. **Given** `TrendsMonthlyBarChart._ReadyChart` with bar selection
   **When** user selects a month bar (touch or keyboard)
   **Then** dynamic semantics label announces month + avg steps + total/days (mirror daily pattern)
   **And** blanket `ExcludeSemantics` on ready chart is removed or restructured so selection is not hidden from a11y tree (diagnostic L250–253)
   **And** `liveRegion: true` on selection change
   **And** static `trendsMonthlyBarChartSemantics` retained when no bar selected

6. **Given** new monthly selection copy
   **When** ARB keys are added
   **Then** EN + FR strings added via `app_en.arb` / `app_fr.arb` + `flutter gen-l10n`
   **And** reuse existing tooltip fragments where possible (`formatMonthYearFull`, `trendsMonthlyTooltipStepsPerDay`, `trendsMonthlyTooltipTotal`)

7. **Given** widget tests for chart a11y
   **When** this story ships
   **Then** `step_bar_chart_test.dart` asserts `liveRegion` on selected daily chart
   **And** keyboard tests cover Tab-to-chart, arrow navigation, Enter/Space toggle (follow `astra_segmented_control_test.dart` Tab pattern)
   **And** `trends_monthly_bar_chart_test.dart` adds selection semantics tests (currently touch-only)
   **And** existing touch/tooltip/goal-line tests still pass
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-29 · NFR-AUD-05 · diagnostic-accessibilité-statique.md charts Majeur (L38–45, L245–254, L286–289, L355–365)

**Depends on:** Story 23-4 — **done** (keyboard focus pattern on `InkWell.focusColor`; chart keyboard was explicitly out of scope for 23-4)

**Out of scope:** Per-bar individual `Semantics` nodes inside `CustomPainter` (container-level label + liveRegion is the established 12-4 contract), `history_cubit.dart` / selection in cubit (selection stays local widget state per Story 12-4), `PeriodToggle` (fixed in 23-4), week day pill semantics (23-6), settings MergeSemantics (23-7), decorative `ExcludeSemantics` sweep (AUD-33), version bump until Epic 23 closes, chart layout token centralization (Epic 24), `chart_benchmark_test.dart` regression beyond ensuring 7d↔30d toggle still passes.

## Tasks / Subtasks

- [x] **Sub-task A — Keyboard focus + navigation in `AstraBarChartCore`** (AC: #1, #2, #3)
  - [x] Read `_AstraBarChartCoreState` — touch-only `GestureDetector`; zero `FocusNode`/`Shortcuts` in `lib/presentation/` today
  - [x] Wrap plot area with focusable pattern; keep `GestureDetector` for pointer (can nest inside focusable or use `FocusableActionDetector` + `onTap` equivalent)
  - [x] Add internal `_focusedIndex` (nullable); initialize to `0` or `selectedIndex ?? 0` on focus
  - [x] Wire `Shortcuts`/`Actions`: ArrowLeft/Right, Home/End, ActivateIntent (Enter/Space), Escape → clear selection
  - [x] Pass `focusedIndex` to `AstraBarChartPainter` for focus ring/outline — use `AstraColors.borderDefault` token, not hardcoded hex (NFR-AUD-08)
  - [x] Visible focus on chart container (inset border or focused-bar outline) — must not be identical to selected-bar fill
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Daily chart semantics + liveRegion** (AC: #4)
  - [x] In `StepBarChart._ReadyChart`, add `liveRegion: _touchedIndex != null` on outer `Semantics`
  - [x] Preserve `ExcludeSemantics` on visual chart children (GoalRing pattern from 23-3)
  - [x] Verify empty/loading shells still use static `trendsStepBarChartSemantics` wrapper (L59–66)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Monthly chart selection semantics + ARB** (AC: #5, #6)
  - [x] Refactor `TrendsMonthlyBarChart._ReadyChart` to Stateful semantics wrapper like daily `_ReadyChart`
  - [x] Add `_monthlySelectionSemanticsLabel` using new ARB key (e.g. `chartMonthlySelectionSemantics`: `{month}, {avgSteps} steps/day, {total} total · {days} days`)
  - [x] Remove or narrow `ExcludeSemantics` so outer `Semantics` label updates on selection
  - [x] Run `flutter gen-l10n`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Widget tests + regression** (AC: #7)
  - [x] Extend `test/presentation/widgets/step_bar_chart_test.dart`: liveRegion flag, keyboard select path
  - [x] Extend `test/presentation/widgets/trends_monthly_bar_chart_test.dart`: selection semantics label
  - [x] Optional helper in `test/helpers/bar_chart_touch_test_helper.dart`: `focusChartAndSelectBar(tester, index)` for keyboard simulation
  - [x] `dart analyze` + `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Keyboard focus + arrow/activate in `astra_bar_chart_core.dart` | Cubit-owned selection state |
| Focus visual distinct from selected bar | Per-bar Semantics widgets in painter |
| Daily `liveRegion` on selection | History screen orchestration changes |
| Monthly dynamic semantics + ARB | PeriodToggle / segmented control (23-4) |
| Widget tests for keyboard + semantics | TalkBack/VoiceOver runtime audit (NFR-AUD-05 disclaimer) |

### Root cause (read before editing)

**Audit finding:** `StepBarChart` / `TrendsMonthlyBarChart` use `GestureDetector` in `AstraBarChartCore` — touch-only, no keyboard role. Monthly ready chart wrapped in `ExcludeSemantics` hides selection. Daily chart updates `Semantics.label` on selection but lacks `liveRegion` [Source: diagnostic-accessibilité-statique.md L38–45, L245–254, L286–289].

**Epic note:** "Base Semantics exist; remaining = keyboard/role (AUD-29)" — extend, do not remove [Source: epics-post-audit.md L265].

**Story 12-4 contract:** Bar selection is **local widget state** (`_touchedIndex`); touch does not trigger cubit refresh. Keyboard must use same `onSelectedIndexChanged` callback [Source: 12-4-trends-historical-goal-line.md AC #3, #6].

### Current implementation (UPDATE — do not rewrite)

**Touch-only core — primary edit site:**

```108:122:lib/presentation/widgets/chart/astra_bar_chart_core.dart
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (details) =>
                          _handleTapUp(details, plotConstraints),
                      onTapDown: (details) {
                        final index = barIndexAtPlotX(
                          localX: details.localPosition.dx,
                          plotWidth: plotWidth,
                          barCount: barCount,
                          barWidth: widget.barWidth,
                        );
                        if (index == null) {
                          _handleTapOutside();
                        }
                      },
```

**Daily chart — partial semantics (extend with liveRegion):**

```191:201:lib/presentation/widgets/step_bar_chart.dart
    final semanticsLabel = _touchedIndex == null
        ? l10n.trendsStepBarChartSemantics
        : _selectionSemanticsLabel(
            l10n: l10n,
            point: points[_touchedIndex!],
            goal: resolvedGoals[_touchedIndex!],
          );

    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
```

**Monthly chart — semantics gap:**

```48:50:lib/presentation/widgets/trends_monthly_bar_chart.dart
    return Semantics(
      label: l10n.trendsMonthlyBarChartSemantics,
      child: ConstrainedBox(
```

```167:168:lib/presentation/widgets/trends_monthly_bar_chart.dart
    return ExcludeSemantics(
      child: Padding(
```

**Existing ARB (daily — reuse pattern for monthly):**

- `chartSelectionSemantics`: `{date}, {steps} of {goal} steps, {status}` (EN) / `{date}, {steps} sur {goal} pas, {status}` (FR)
- `chartGoalStatus(steps, goal)` via `l10n_date_labels.dart`
- Monthly tooltips already localized: `trendsMonthlyTooltipStepsPerDay`, `trendsMonthlyTooltipTotal`

### Recommended implementation approach

**AstraBarChartCore keyboard (preferred):**

```dart
// Pseudocode — adapt to project style
FocusableActionDetector(
  focusNode: _focusNode,
  autofocus: false,
  shortcuts: {
    LogicalKeySet(LogicalKeyboardKey.arrowLeft): _MoveFocusIntent(-1),
    LogicalKeySet(LogicalKeyboardKey.arrowRight): _MoveFocusIntent(1),
    LogicalKeySet(LogicalKeyboardKey.home): _MoveFocusIntent.toStart,
    LogicalKeySet(LogicalKeyboardKey.end): _MoveFocusIntent.toEnd,
    LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
    LogicalKeySet(LogicalKeyboardKey.space): ActivateIntent(),
    LogicalKeySet(LogicalKeyboardKey.escape): _ClearSelectionIntent(),
  },
  actions: { /* map intents to _focusedIndex / onSelectedIndexChanged */ },
  child: GestureDetector(/* preserve existing touch handlers */),
)
```

**Focus visual:** Add optional `focusedIndex` param to `AstraBarChartPainter`; draw inset stroke at focused bar X using `colors.borderDefault.withValues(alpha: 0.8)` — lighter than selected fill (`accentPrimary` @ 0.8).

**Daily liveRegion (minimal):**

```dart
return Semantics(
  label: semanticsLabel,
  liveRegion: _touchedIndex != null,
  child: ExcludeSemantics(/* unchanged */),
);
```

**Monthly semantics:** Move `Semantics` wrapper from stateless `build` into `_ReadyChartState` (like daily) so label reacts to `_touchedIndex`; build label from `_monthlySelectionSemanticsLabel(l10n, points[i])`.

**Do not:**

- Move `_touchedIndex` into `HistoryCubit`
- Remove existing touch handlers or tooltip overlay
- Delete `chartSelectionSemantics` or daily `_selectionSemanticsLabel`
- Add hardcoded focus colors
- Break `chart_benchmark_test.dart` 7d↔30d toggle path (NFR-AUD-04)

### Consumers (verify manually — shared core fix propagates)

| Widget | File | Chart period |
|--------|------|--------------|
| `StepBarChart` | `lib/presentation/widgets/step_bar_chart.dart` | 7d / 30d daily |
| `TrendsMonthlyBarChart` | `lib/presentation/widgets/trends_monthly_bar_chart.dart` | 12mo |
| `HistoryScreen` | `lib/presentation/screens/history_screen.dart` | Switches chart by `HistoryPeriod` — no edits expected |
| `PeriodToggle` | `lib/presentation/widgets/period_toggle.dart` | Adjacent control — keyboard fixed in 23-4 |

### Architecture compliance

- **Presentation-only** — no cubit, repository, schema, or SQL changes [Source: architecture.md layering]
- **Selection = local UI state** — same contract as Story 12-4; no repository refresh on bar select
- **Design tokens:** focus ring via `AstraColors.borderDefault` — no new hex [Source: NFR-AUD-08]
- **OK commit gate:** one commit per sub-task; wait for Baptiste approval [Source: project-context.md § Development Workflow]
- **Localization:** new monthly selection ARB key only; daily keys unchanged

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/chart/astra_bar_chart_core.dart` | UPDATE — keyboard focus, shortcuts, focus index |
| `lib/presentation/widgets/chart/astra_bar_chart_painter.dart` | UPDATE — optional focused-bar visual |
| `lib/presentation/widgets/step_bar_chart.dart` | UPDATE — `liveRegion` on selection Semantics |
| `lib/presentation/widgets/trends_monthly_bar_chart.dart` | UPDATE — dynamic selection semantics, restructure ExcludeSemantics |
| `lib/l10n/app_en.arb` | ADD monthly selection semantics key |
| `lib/l10n/app_fr.arb` | ADD monthly selection semantics key |
| `test/presentation/widgets/step_bar_chart_test.dart` | ADD liveRegion + keyboard tests |
| `test/presentation/widgets/trends_monthly_bar_chart_test.dart` | ADD selection semantics tests |
| `test/helpers/bar_chart_touch_test_helper.dart` | OPTIONAL — keyboard helper |

**No changes expected:** `history_cubit.dart`, `history_screen.dart`, `period_toggle.dart`, data layer, `chart_benchmark_test.dart` (unless perf regression — then investigate, do not weaken keyboard)

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md § Test commands]
- Existing daily semantics test template (extend, do not break):

```485:524:test/presentation/widgets/step_bar_chart_test.dart
    testWidgets('selected bar updates semantics summary', (tester) async {
      // ... tap bar ...
      expect(semantics.label, contains('9 June'));
      expect(semantics.label, contains('547 over goal'));
    });
```

- Add: `expect(semantics.hasFlag(SemanticsFlag.isLiveRegion), isTrue)` when selected (use `tester.getSemantics` properties API)
- Keyboard template (from 23-4):

```dart
await tester.sendKeyEvent(LogicalKeyboardKey.tab);
await tester.pump();
// Tab until AstraBarChartCore plot focused, then:
await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
await tester.sendKeyEvent(LogicalKeyboardKey.enter);
await tester.pump();
```

- Reuse `tapBarAtIndex` / `tapPlotAtLocalX` from `bar_chart_touch_test_helper.dart` for touch regression
- Run `step_bar_chart_test.dart` + `trends_monthly_bar_chart_test.dart` + `screen_smoke_test.dart` (HistoryScreen)
- Static audit disclaimer: manual Tab-through on device/emulator recommended before Epic 23 close [Source: NFR-AUD-05]

### Previous story intelligence

**From 23-4 (direct predecessor):**
- Keyboard focus visuals use `colors.borderDefault.withValues(alpha: …)` on interactive surface — apply same token family for chart focus ring
- Focus ≠ selection: selected thumb vs focus tint must be distinguishable — same applies to selected bar vs focused bar
- Tab test pattern: `FocusManager.instance.primaryFocus?.context` + ancestor widget check
- Fix once in shared widget (`AstraBarChartCore`) propagates to both daily and monthly charts

**From 23-3:**
- `liveRegion: true` on dynamic value widgets (GoalRing, ActivityStatsRow) — apply same pattern to chart selection label
- Keep `ExcludeSemantics` on decorative/visual children inside labeled Semantics node

**From 23-2 / 23-1:**
- Container-level `Semantics` with `button`/`label`/`selected` — charts use container `label` + `liveRegion`, not per-child buttons
- Do not introduce global `FocusNode` architecture project-wide

**From Story 12-4:**
- `_touchedIndex` local state; toggle deselect on re-activation
- Daily `_selectionSemanticsLabel` + `chartSelectionSemantics` ARB already implemented — only add liveRegion + keyboard path
- Monthly touch tooltip exists; semantics was deferred to Epic 23

### Git intelligence summary

Recent Epic 23 commits (23-4):
- `fix(a11y): close story 23-4 — segmented control keyboard focus`
- `test(a11y): cover segmented control keyboard focus styling`
- `fix(a11y): restore keyboard focusColor on segmented control segments`

Chart files untouched in 23-4. Last chart work: native `AstraBarChartCore` migration (Epic 12). Tests: daily semantics on tap exists; monthly has no semantics tests.

### Latest tech information

- **Flutter 3.x `FocusableActionDetector`:** Combines focus, keyboard shortcuts, and actions — preferred over raw `Focus` + manual `RawKeyboardListener` for discrete bar navigation [Flutter API docs].
- **WCAG 2.1.1 Keyboard (A):** All functionality available via keyboard — chart bar select/deselect must mirror touch [Source: NFR-AUD-05 aspirational AA].
- **WCAG 4.1.3 Status Messages (AA):** Dynamic selection announcements via `Semantics.liveRegion` [Source: diagnostic recommendation L364].
- **Material charts a11y pattern:** Single container Semantics with updated `label` + `liveRegion` is valid for canvas/CustomPaint charts where per-bar widgets are impractical — matches existing 12-4 implementation direction.
- **No new dependencies** — Flutter SDK only, same as 23-4.

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Version bump at Epic 23 close only: `sprint-status-post-audit.yaml` WORKFLOW NOTES
- Sprint tracker for post-audit epics: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (not `sprint-status.yaml`)
- UX touch targets §4.2 — chart plot focus target should cover plot area; adjacent PeriodToggle already ≥48 dp from 23-4
- Audit source: `_bmad-output/planning-artifacts/audits/diagnostic-accessibilité-statique.md`

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- `flutter gen-l10n` after ARB additions
- `dart analyze` — no issues on chart widgets
- `flutter test` chart suite — 33 tests passed (`--exclude-tags slow`)

### Completion Notes List

- **A:** `AstraBarChartCore` — `FocusableActionDetector` + arrow/home/end/enter/escape; plot border + painter focus ring via `borderDefault`
- **B:** `StepBarChart` — `liveRegion: _touchedIndex != null` on selection semantics
- **C:** `TrendsMonthlyBarChart` — dynamic `chartMonthlySelectionSemantics` + `liveRegion`; loading/empty keep static label
- **D:** 6 core keyboard tests, daily liveRegion + keyboard integration, monthly selection semantics test, `focusChartAndSelectBar` helper

### File List

- `lib/presentation/widgets/chart/astra_bar_chart_core.dart`
- `lib/presentation/widgets/chart/astra_bar_chart_painter.dart`
- `lib/presentation/widgets/step_bar_chart.dart`
- `lib/presentation/widgets/trends_monthly_bar_chart.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_fr.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_fr.dart`
- `test/presentation/widgets/chart/astra_bar_chart_core_test.dart`
- `test/presentation/widgets/step_bar_chart_test.dart`
- `test/presentation/widgets/trends_monthly_bar_chart_test.dart`
- `test/helpers/bar_chart_touch_test_helper.dart`

### Change Log

- 2026-07-17: Story 23-5 — chart keyboard navigation, selection semantics liveRegion, monthly ARB label, widget tests
