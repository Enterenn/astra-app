# Story 23.4: Restore Visible Keyboard Focus on Segmented Controls

Status: done

<!-- Post-audit Epic 23 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 23-4 · diagnostic-accessibilité-statique.md Focus Majeur · AUD-28 · NFR-AUD-07 -->
<!-- Prerequisite: Story 23-3 — done (liveRegion pattern on Today/My Data widgets) -->
<!-- Version bump: deferred to Epic 23 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **keyboard user**,
I want a visible focus indicator on segmented controls,
So that I know which segment is focused before I activate it.

## Acceptance Criteria

1. **Given** `_SegmentTarget` / `InkWell` in `astra_segmented_control.dart` (L211–216)
   **When** a segment receives keyboard focus (Tab / Shift+Tab)
   **Then** visible focus feedback is rendered (AUD-28, NFR-AUD-07)
   **And** focus feedback is **not** neutralized by transparent Material overlay colors

2. **Given** a segment with `selected: true` (sliding thumb + elevated typography)
   **When** that same segment is keyboard-focused
   **Then** selection styling (thumb position, font weight, text color) is preserved
   **And** focus feedback is visually distinguishable from selection alone (ring, tint, or border — not identical to the selected thumb fill)

3. **Given** `AstraSegmentedControl` consumers — `PeriodToggle`, `ThemeSelector`, onboarding height/weight unit selectors
   **When** this story ships with a fix in the shared widget only
   **Then** all four call sites inherit keyboard focus feedback without per-screen edits
   **And** existing tap, semantics (`button`, `selected`, `label`, `hint`), thumb animation, and `AstraPressable` scale behaviour are unchanged

4. **Given** touch / pointer interaction on a segment
   **When** the user taps (no keyboard)
   **Then** the current design intent is preserved: no splash ripple flood on the gray track (transparent `splashColor` may remain)
   **And** `AstraPressable` press-scale animation still fires

5. **Given** segment layout constraints (`minHeight: kMinTouchTarget` = 48 dp)
   **When** focus ring/tint is added
   **Then** touch targets remain ≥48 dp (NFR-AUD-07, UX §4.2)
   **And** compact onboarding track (`segmentHorizontalPadding > 0`) still meets min height

6. **Given** widget tests for `AstraSegmentedControl`
   **When** this story ships
   **Then** tests assert non-transparent keyboard focus styling on `_SegmentTarget` InkWell (property or focused-state pump)
   **And** existing tap / thumb-slide / inset-shadow tests still pass
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-28 · NFR-AUD-07 · diagnostic-accessibilité-statique.md Focus Majeur (L265–275, L345–366)

**Depends on:** Story 23-3 — **done** (Epic 23 a11y patterns established; no dependency on liveRegion code)

**Out of scope:** `AccentPresetSelector` focus ring (audit Mineur — separate item), `AstraButton` / export button `overlayColor: transparent` (audit Mineur), chart keyboard focus (Story 23-5), week day pill semantics (23-6), settings notifications MergeSemantics (23-7), adding explicit `FocusNode`s project-wide, version bump until Epic 23 closes, refactoring `AstraSegmentedControl` API or thumb animation.

## Tasks / Subtasks

- [x] **Sub-task A — Restore keyboard focus feedback on `_SegmentTarget`** (AC: #1, #2, #4, #5)
  - [x] Read `_SegmentTarget.build` — root cause is `InkWell` with `highlightColor: Colors.transparent` and no explicit `focusColor` (Flutter uses `highlightColor` for focus when `focusColor` is null)
  - [x] Set explicit non-transparent `focusColor` on `InkWell` using `AstraColors` tokens (prefer `colors.borderDefault.withValues(alpha: …)` or theme-aligned focus tint — **no hardcoded hex** per NFR-AUD-08)
  - [x] If tint alone is insufficient vs selected thumb, add an inset focus ring (e.g. `Border.all` on focused `Material` via `Focus` ancestor or `WidgetStateColor`) — selection thumb must remain visible underneath
  - [x] Keep `splashColor: Colors.transparent` unless product asks for touch ripple on segments
  - [x] Verify light + dark themes manually or via dual-theme widget test
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Focus semantics widget tests** (AC: #6)
  - [x] Extend `test/presentation/widgets/astra_segmented_control_test.dart`
  - [x] Test: first `InkWell` has non-null, non-transparent `focusColor` (or equivalent focus decoration)
  - [x] Test (optional but valuable): `tester.sendKeyEvent(LogicalKeyboardKey.tab)` + pump → focused segment shows focus overlay (if reliably assertable in harness)
  - [x] Re-run existing tap + thumb-slide tests unchanged
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Consumer regression** (AC: #3, #6)
  - [x] `flutter test test/presentation/widgets/period_toggle_test.dart`
  - [x] `flutter test test/presentation/widgets/theme_selector_test.dart`
  - [x] `dart analyze`
  - [x] `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Keyboard focus feedback in `astra_segmented_control.dart` `_SegmentTarget` | `AccentPresetSelector` / color chips |
| Shared fix propagates to PeriodToggle, ThemeSelector, onboarding unit pills | Chart bar focus (23-5) |
| Widget tests for focus styling | Global `FocusNode` strategy |
| Preserve semantics, thumb, press scale, 48 dp targets | Touch splash redesign beyond focus fix |

### Root cause (read before editing)

**Audit finding:** `_SegmentTarget / InkWell` sets `splashColor`, `highlightColor`, and `hoverColor` to `Colors.transparent` — keyboard focus has no visible feedback. `PeriodToggle` on History inherits this via `AstraSegmentedControl` [Source: diagnostic-accessibilité-statique.md L46–48, L271–275, L365–366].

**Flutter mechanism:** `InkWell.highlightColor` applies to **both** pressed and focused states when `focusColor` is omitted. Transparent `highlightColor` therefore silences keyboard focus [Source: Flutter `InkWell` API — `focusColor` overrides focus highlight independently].

**Design tension:** Selected segment already has sliding `bgElevated` thumb + bold label. Focus indicator must stack on top without being mistaken for “new selection” before Enter/Space activation.

### Current implementation (UPDATE — do not rewrite)

**Problem site — all overlay colors transparent, no focusColor:**

```211:216:lib/presentation/widgets/astra_segmented_control.dart
              child: InkWell(
                onTap: canSelect ? () => onChanged(option.value) : null,
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
```

**Semantics + structure to preserve:**

```196:205:lib/presentation/widgets/astra_segmented_control.dart
    return Semantics(
      button: canSelect,
      enabled: canSelect,
      selected: selected,
      label: option.effectiveSemanticsLabel,
      hint: semanticsHint,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AstraPressable(
```

**Touch target already compliant:**

```217:220:lib/presentation/widgets/astra_segmented_control.dart
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AstraSpacing.kMinTouchTarget,
                  ),
```

### Recommended implementation approach

**Minimal fix (preferred first):**

```dart
focusColor: colors.borderDefault.withValues(alpha: 0.35),
hoverColor: colors.borderDefault.withValues(alpha: 0.12), // optional: desktop pointer users
// keep splashColor + highlightColor transparent for touch press (AstraPressable owns press scale)
```

**If tint insufficient on selected segment (thumb = `bgElevated`):** wrap `Material` child with focus-aware inset border using `colors.borderDefault` (UX focus ring palette ≈ `#4A5568` dark / `#9CA3AF` light — map via `borderDefault`, not new hex). Example pattern: detect `Focus.of(context).hasFocus` in a thin `StatefulWidget` wrapper or use `InkWell` inside `Focus` with custom `focusNode` — **avoid** converting entire control to Stateful unless needed.

**Do not:**

- Remove `AstraPressable` or Semantics tree
- Change `fireOnReselect`, thumb `AnimatedPositioned`, or compact-track layout
- Set non-transparent `highlightColor` without testing touch press (would add press fill conflicting with thumb design)
- Add hardcoded `Color(0x…)` focus colors

### Consumers (verify manually — no edits expected)

| Widget | File | Usage |
|--------|------|-------|
| `PeriodToggle` | `lib/presentation/widgets/period_toggle.dart` | History/Trends chart range |
| `ThemeSelector` | `lib/presentation/widgets/theme_selector.dart` | Settings appearance |
| Height unit pill | `lib/presentation/onboarding/onboarding_height_page.dart` L43 | cm / in |
| Weight unit pill | `lib/presentation/onboarding/onboarding_weight_page.dart` | kg / lb |

Audit lists `ThemeSelector / AccentPresetSelector` focus as Mineur — **only** `AstraSegmentedControl` is in scope for 23-4; ThemeSelector benefits automatically; AccentPresetSelector does not use this widget.

### Architecture compliance

- **Presentation-only** — no cubit, repository, schema, or screen orchestration edits [Source: architecture.md NFR-5]
- **Design tokens:** use `AstraColors` / `AstraSpacing` — no new hardcoded hex [Source: NFR-AUD-08, project-context.md]
- **OK commit gate:** one commit per sub-task; wait for Baptiste approval [Source: project-context.md § Development Workflow]
- **Localization:** no new ARB keys — existing segment labels and `semanticsHint` unchanged

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/astra_segmented_control.dart` | UPDATE — `_SegmentTarget` focus styling on `InkWell` / `Material` |
| `test/presentation/widgets/astra_segmented_control_test.dart` | ADD focus-color / focus-state tests |

**No changes expected:** `period_toggle.dart`, `theme_selector.dart`, onboarding pages, `history_screen.dart`, `settings_screen.dart`, ARB files

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md § Test commands]
- Property assertion template:
  ```dart
  final inkWell = tester.widget<InkWell>(find.byType(InkWell).first);
  expect(inkWell.focusColor, isNotNull);
  expect(inkWell.focusColor, isNot(Colors.transparent));
  ```
- Keyboard navigation (if added): wrap in `TestMaterialApp`, `await tester.sendKeyEvent(LogicalKeyboardKey.tab)`, pump — assert `FocusManager.instance.primaryFocus != null`
- Run existing `astra_segmented_control_test.dart` tap + thumb tests — must not regress
- Static audit disclaimer: runtime Tab-through on device/emulator recommended before Epic 23 close [Source: NFR-AUD-05]

### Previous story intelligence

**From 23-3 (direct epic predecessor):**
- Leaf-widget fixes propagate to all consumers — fix once in `astra_segmented_control.dart`
- OK commit gate + sub-task stops remain mandatory
- Widget tests live beside the widget under test

**From 23-2 / 23-1:**
- Semantics on segments already correct (`button`, `selected`, `label`) — do not refactor Semantics tree
- `ExcludeSemantics` pattern unrelated to this story

**From audit note (L301):** Project has no explicit `FocusNode`s in `lib/presentation/` — this story restores Material focus **visuals** only; do not introduce a global focus architecture.

### Git intelligence summary

Recent Epic 23 commits (23-3):
- `fix(a11y): close story 23-3 — empty-day semantics and review test coverage`
- `test(a11y): cover liveRegion semantics on Today and My Data widgets`
- `feat(a11y): add liveRegion to BackgroundStatusCard status row`

No in-flight changes on `astra_segmented_control.dart`. Last functional tests: tap + thumb animation only (`astra_segmented_control_test.dart`).

### Latest tech information

- **Flutter 3.x InkWell:** `focusColor` property sets overlay when segment has keyboard focus; independent of `splashColor`. Setting only `focusColor` preserves transparent touch highlight/splash.
- **WCAG 2.4.7 Focus Visible (AA):** UI component receiving keyboard focus needs visible indicator — satisfied by non-transparent focus overlay or ring [Source: NFR-AUD-05 aspirational AA].
- **Material 3 / Theme:** `ThemeData.focusColor` exists but segmented control should use `AstraColors` for theme/accent consistency, not raw `Theme.of(context).focusColor` alone.
- **Desktop hover (optional):** subtle non-transparent `hoverColor` improves pointer users without affecting AC; keep alpha low to avoid clash with selected thumb.

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Version bump at Epic 23 close only: `sprint-status-post-audit.yaml` WORKFLOW NOTES
- UX touch targets §4.2 (48 dp segments): `_bmad-output/planning-artifacts/ux-design-specification.md`
- UX semantics for PeriodToggle / ThemeSelector §4.3 — unchanged by this story
- Sprint tracker for post-audit epics: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (not `sprint-status.yaml` — original epics 1–13 complete)

## Dev Agent Record

### Agent Model Used

claude-4.6-sonnet-medium-thinking

### Debug Log References

- Root cause confirmed: transparent `highlightColor` silenced keyboard focus when `focusColor` omitted
- Minimal fix applied: explicit `focusColor` + subtle `hoverColor` via `colors.borderDefault`; inset ring deferred (tint sufficient per dual-theme tests)

### Completion Notes List

- Added `focusColor: colors.borderDefault.withValues(alpha: 0.35)` and `hoverColor: …(alpha: 0.12)` on `_SegmentTarget` InkWell; kept splash/highlight transparent
- Added 3 widget tests: focusColor non-transparent, light/dark theme alpha, Tab focus acquisition
- Consumer regression: PeriodToggle (3), ThemeSelector (6), full fast suite — all green

### File List

- `lib/presentation/widgets/astra_segmented_control.dart` — keyboard focus + hover overlay on InkWell
- `test/presentation/widgets/astra_segmented_control_test.dart` — focus styling + Tab tests
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` — 23-4 → review

### Change Log

- 2026-07-17: Restore visible keyboard focus on AstraSegmentedControl segments (Story 23-4)
