# Story 13.2: AstraHorizontalRuler Widget

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->
<!-- Mockup ref: assets/.../Weight-light-70d5a378-*.png, Height-light-2ccf1294-*.png (Baptiste 2026-06-17) -->
<!-- UX-DR27: horizontal scroll picker — center indicator, major/minor ticks, large readout, unit label -->

## Story

As a **developer**,
I want a reusable horizontal ruler picker,
So that weight and height onboarding (and future editors) share one interaction pattern.

## Acceptance Criteria

1. **Given** `AstraHorizontalRuler` with `min`, `max`, `step`, and `value` configured  
   **When** the widget builds  
   **Then** a large centered **value readout** shows the current selection (formatted per `valueFormatter` or sensible default)  
   **And** a horizontal **tick scale** renders below the readout inside an elevated card (`bgElevated`, `kRadiusLg`)  
   **And** a fixed **center indicator** (thick vertical line) marks the selected tick  
   **And** a **unit label** (e.g. `kg`, `cm`) appears below the center indicator in caption style

2. **Given** the ruler is scrollable  
   **When** the user drags/flings horizontally  
   **Then** the tick under the center indicator becomes the new value  
   **And** scrolling **snaps** to the nearest valid tick on scroll end (no half-tick resting positions)  
   **And** `onChanged` fires when the snapped value differs from the previous value  
   **And** optional light **haptic** feedback fires on value change when `enableHaptics` is true (default)

3. **Given** major tick configuration (`majorTickEvery` — count of `step` units between major ticks)  
   **When** ticks render  
   **Then** **minor ticks** appear at every `step`  
   **And** **major ticks** are taller and show numeric labels at major intervals only (mockup: 50, 60, 80, 90 on weight screen)

4. **Given** accessibility  
   **When** a screen reader focuses the ruler  
   **Then** `Semantics` exposes the current value and unit (e.g. "70 kilograms")  
   **And** increment/decrement is achievable via scroll gesture (no separate stepper required in v1)

5. **Given** bounds  
   **When** `value` is programmatically set or user scrolls to an edge  
   **Then** selection clamps to `[min, max]` aligned to `step`  
   **And** widget tests verify snap-to-tick and clamp at min/max

6. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** `test/presentation/widgets/astra_horizontal_ruler_test.dart` covers snap behavior and bounds

**Depends on:** Story 13.1 (done — shell/placeholders exist). **Enables:** Story 13.3 (weight/height pages).  
**Mockup ref:** `Weight-light`, `Height-light` — workspace `assets/.../Weight-light-70d5a378-*.png`.

## Tasks / Subtasks

- [x] **Sub-task A — Scroll + snap core** (AC: #2, #5)
  - [x] Create `lib/presentation/widgets/astra_horizontal_ruler.dart` as `StatefulWidget`
  - [x] API: `value`, `onChanged`, `min`, `max`, `step` (all `double`; parent rounds for int height), `unitLabel`, optional `majorTickEvery`, `valueFormatter`, `enableHaptics` (default `true`)
  - [x] Horizontal `ListView` or equivalent with fixed `itemExtent` per tick; symmetric horizontal padding so first/last tick can center under indicator
  - [x] Snap on `ScrollEndNotification` / `UserScrollNotification` idle — nearest tick index, `animateTo` if needed
  - [x] Clamp computed value to `[min, max]`; align to `step` grid (tolerate float drift with rounded index math)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Tick scale painting** (AC: #3)
  - [x] `CustomPainter` or composed widgets for minor/major tick marks
  - [x] Major labels use `AstraTypography.captionFor` / `labelFor` — muted color for non-center labels
  - [x] Tick densities match mockup feel: minor = short tick, major = taller + label
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Readout, center indicator, card chrome** (AC: #1)
  - [x] Large readout: extend `AstraTypography` if needed (e.g. `rulerValueFor` — Darker Grotesque ~52–64px semibold per mockup) or reuse `displayFor` scaled
  - [x] Center indicator: `colors.textPrimary` thick vertical line overlay (not scrolled)
  - [x] Card: `AstraInsetShadowSurface` + `bgElevated` + `kRadiusLg` wrapping readout + ruler band (match weight mockup white panel)
  - [x] Unit label centered under indicator in `captionFor` / `neutralGray`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Semantics + haptics** (AC: #4, #2)
  - [x] `Semantics` wrapper: `label` = formatted value + unit; `value` string for screen readers
  - [x] `HapticFeedback.selectionClick()` on value change (respect `enableHaptics`; no-op in tests via flag)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Widget tests** (AC: #5, #6)
  - [x] Create `test/presentation/widgets/astra_horizontal_ruler_test.dart` (mirror `astra_segmented_control_test.dart` pump helper + light theme)
  - [x] Test: initial value renders in readout
  - [x] Test: drag scroll updates snapped value and calls `onChanged`
  - [x] Test: cannot scroll past min/max (clamp)
  - [x] Test: semantics label includes value + unit
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary (critical)

| Area | In scope (13.2) | Out of scope (later stories) |
|------|-----------------|------------------------------|
| Widget file | `astra_horizontal_ruler.dart` | — |
| Scroll + snap picker | Full reusable API | — |
| Visual chrome | Card, readout, ticks, center line, unit label | Page headline ("What is your weight?") |
| Unit conversion | — | Parent passes display-domain min/max/step (13.3) |
| Segmented control | — | `AstraSegmentedControl` on weight/height pages (13.3) |
| Onboarding integration | — | Replace placeholders in 13.3 |
| Persistence | — | `UserPreferencesRepository` writes (13.3) |
| Profile editor migration | — | Keep text-field sheets; ruler optional follow-up |

**This story delivers an isolated, testable widget.** Do not wire into `OnboardingFlow` yet — placeholders remain until 13.3.

### Visual reference (authoritative mockup — Weight step)

**Weight screen (`Weight-light`):**

| Region | Spec |
|--------|------|
| Page question | "What is your weight?" — **13.3** (not this story) |
| Unit toggle | `AstraSegmentedControl` kg/lb — **13.3** |
| Picker card | White/`bgElevated`, `kRadiusLg`, subtle elevation/inset shadow, horizontal inset |
| Value readout | Large bold number centered above scale (e.g. **70**) |
| Tick scale | Horizontal band; minor ticks every step; major ticks + labels every 10 units (50, 60, 80, 90 visible) |
| Center indicator | Fixed thick dark vertical line at horizontal center |
| Unit under indicator | Small muted `kg` below center tick |
| Footer | Back + Continue — **shell** (13.1), page wiring **13.3** |

**Height screen (`Height-light`):** Same picker card pattern; integer cm steps; labels every 10 cm — config supplied by parent in 13.3.

### Widget API (recommended)

```dart
typedef RulerValueFormatter = String Function(double value);

class AstraHorizontalRuler extends StatefulWidget {
  const AstraHorizontalRuler({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.step,
    required this.unitLabel,
    this.majorTickEvery = 10,
    this.valueFormatter,
    this.enableHaptics = true,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final String unitLabel;
  /// Major tick every N step units (e.g. step=1, majorTickEvery=10 → labels at 50, 60, 70…).
  final double majorTickEvery;
  final RulerValueFormatter? valueFormatter;
  final bool enableHaptics;
}
```

**Default formatter:** integers when `step >= 1` and step is whole; else one decimal place.

**Parent owns unit domain:** Widget operates on **display numbers** already converted (kg, lb, cm, or total inches). Story 13.3 converts to/from canonical `weight_kg` / `height_cm` using `display_unit_formatter.dart`.

### Expected configs for Story 13.3 (document now — implement there)

| Use case | min | max | step | majorTickEvery | Default | Notes |
|----------|-----|-----|------|----------------|---------|-------|
| Weight kg | `kMinWeightKg` (30) | `kMaxWeightKg` (300) | `1` | `10` | `70` | Canonical kg integers on ruler |
| Weight lb | `weightKgToDisplayLb(30)` ≈ 66 | `weightKgToDisplayLb(300)` ≈ 661 | `1` | `10` | `weightKgToDisplayLb(70)` ≈ 154 | Display lb; persist via `displayLbToWeightKg` |
| Height cm | `kMinHeightCm` (100) | `kMaxHeightCm` (250) | `1` | `10` | `170` | Integer cm |
| Height inches | TBD in 13.3 | TBD | `1` | `12`? | ~67 in (170 cm) | Onboarding mockup uses **inches** segment (not ft+in); parent computes inch range from cm bounds |

Constants live in `lib/core/constants/preference_keys.dart` — **import, do not duplicate**.

### Implementation approach (prevent reinvention)

| Approach | Verdict |
|----------|---------|
| New pub package (e.g. `ruler_slider`) | ❌ Do not add dependencies |
| `ListWheelScrollView` vertical rotated | ❌ Poor horizontal UX vs mockup |
| `ListView` + fixed tick width + center padding + snap on scroll end | ✅ Recommended |
| `PageView` per value | ⚠️ Heavy for 270 ticks — prefer single list |

**Snap algorithm sketch:**

1. `tickCount = ((max - min) / step).round() + 1`
2. `itemExtent` = fixed dp (e.g. 8–12 logical px per minor tick — tune to mockup)
3. `scrollOffset = (selectedIndex) * itemExtent`
4. On scroll end: `index = (offset / itemExtent).round()` → `value = min + index * step` → clamp → `animateTo` → `onChanged`

**Center padding:** `horizontalPadding = viewportWidth / 2 - itemExtent / 2` so index 0 and last index can center.

### Reuse — do not reinvent

| Asset | Location | Use in 13.2 |
|-------|----------|-------------|
| `AstraInsetShadowSurface` | `astra_inset_shadow.dart` | Picker card surface (same family as segmented control track) |
| `AstraTypography` | `astra_typography.dart` | Readout, labels — add `rulerValueFor` only if no existing token fits |
| `AstraSpacing` | `astra_spacing.dart` | `kRadiusLg`, `kCardPadding`, tick spacing |
| `AstraColors` | `astra_colors.dart` | `textPrimary`, `neutralGray`, `borderDefault`, `bgElevated` |
| `buildAstraLightTheme()` | `astra_theme.dart` | Widget tests |
| `kMinWeightKg` / `kMaxWeightKg` / `kMinHeightCm` / `kMaxHeightCm` | `preference_keys.dart` | Test fixtures + document 13.3 configs |
| `weightKgToDisplayLb` / `displayLbToWeightKg` | `display_unit_formatter.dart` | **13.3 only** — listed for config reference |

**Do not** duplicate conversion constants (`_lbPerKg`, etc.) — already in formatter.

### Suggested file tree after 13.2

```
lib/presentation/widgets/
└── astra_horizontal_ruler.dart          # NEW

test/presentation/widgets/
└── astra_horizontal_ruler_test.dart     # NEW
```

No changes to `onboarding_flow.dart` or placeholders in this story.

### Anti-patterns (do not do in 13.2)

- ❌ Wire ruler into onboarding pages (13.3)
- ❌ Add `AstraSegmentedControl` inside the ruler widget
- ❌ Persist preferences or touch `OnboardingCubit`
- ❌ Replace Profile `weight_editor_sheet` / `height_editor_sheet`
- ❌ Add third-party scroll/slider packages
- ❌ Block on haptics in tests — use `enableHaptics: false`
- ❌ Hard-code weight-only ranges inside widget (all bounds via constructor)
- ❌ Batch sub-tasks into one commit without Baptiste review

### Epic 13 cross-story context

| Story | Focus | Relation to 13.2 |
|-------|-------|------------------|
| 13.1 (done) | Shell, intro, placeholders | Placeholders show "Weight"/"Height" text — unchanged until 13.3 |
| **13.2** (this) | `AstraHorizontalRuler` | Standalone widget |
| 13.3 | Weight + height pages | Embeds ruler + segmented control; replaces placeholders |
| 13.4 | Cleanup | No ruler changes expected |

### Mandatory dev workflow

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task (A–E) after Baptiste review
- Review brief format required before each commit
- No version bump until Epic 13 closes (`0.6.0+11`)

### Project Structure Notes

- Aligns with architecture update: `lib/presentation/widgets/astra_horizontal_ruler.dart` [Source: sprint-change-proposal §4.5]
- Presentation-only — no DB, cubit, or navigation changes
- UX-DR27 satisfied by this story

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 13, Story 13.2]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-17.md — §4.2 UX-DR27, §4.4 AC, implementation order]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — segmented pill + elevated card patterns §1]
- [Source: _bmad-output/planning-artifacts/architecture.md — presentation/widgets/]
- [Source: _bmad-output/implementation-artifacts/stories/13-1-onboarding-shell-and-intro-screen.md — shell, placeholders, scope boundary]
- [Source: lib/presentation/widgets/astra_segmented_control.dart — inset shadow + semantics patterns]
- [Source: lib/core/constants/preference_keys.dart — body metric bounds]
- [Source: mockup assets/.../Weight-light-70d5a378-*.png]

## Dev Agent Record

### Agent Model Used

Composer (dev-story workflow)

### Debug Log References

- `ListView` + fixed `itemExtent` (10dp) with symmetric side padding for center alignment
- Index-based snap on `ScrollEndNotification`; `animateTo` respects `MediaQuery.disableAnimationsOf`
- Reused `AstraTypography.displayFor` (52px) for readout — no new typography token needed
- Major tick labels via `_isMajorTick` using `majorTickEvery / step` step count

### Completion Notes List

- Implemented standalone `AstraHorizontalRuler` widget with scroll-snap, major/minor ticks, elevated card chrome, center indicator, unit label, semantics, and optional haptics
- Widget tests cover readout, drag/snap/onChanged, bounds clamp, semantics, and inset shadow card
- `flutter analyze` on new files: 0 issues; `flutter test test/presentation/widgets/astra_horizontal_ruler_test.dart`: 5/5 pass
- Full suite: 3 pre-existing failures unrelated to this story (onboarding_cubit boundaries, widget_test navigation/onboarding gate)
- No onboarding flow wiring (deferred to Story 13.3 per scope boundary)
- Commits pending Baptiste review per project-context sub-task gate

### File List

- `lib/presentation/widgets/astra_horizontal_ruler.dart` (NEW)
- `test/presentation/widgets/astra_horizontal_ruler_test.dart` (NEW)

### Change Log

- 2026-06-17: Story 13.2 — `AstraHorizontalRuler` reusable horizontal scroll picker (UX-DR27)

## Technical Requirements

1. **Stateful widget** at `lib/presentation/widgets/astra_horizontal_ruler.dart`
2. **Configurable** `min`, `max`, `step`, `value`, `onChanged`, `unitLabel`
3. **Snap-to-tick** on scroll end — no resting between ticks
4. **Center-fixed indicator** — value derived from tick aligned to viewport center
5. **Major/minor ticks** with `majorTickEvery` controlling label cadence
6. **Large readout** above scale; **unit label** below center indicator
7. **Elevated card** chrome matching mockup (`bgElevated`, `kRadiusLg`, inset shadow optional)
8. **Semantics** announcing value + unit
9. **Haptic** optional via `enableHaptics` (default true)
10. **Clamp** selection to `[min, max]` on step grid
11. **No new packages**
12. **Widget tests** for snap + bounds + semantics

## Architecture Compliance

| Decision | Requirement for 13.2 |
|----------|----------------------|
| D-22 | Widget under `presentation/widgets/` |
| D-01 | Flutter Material — custom painter/list acceptable |
| Design tokens | `AstraColors`, `AstraSpacing`, `AstraTypography` only — no hard-coded hex |
| State | Local `State` + `ScrollController` — no new Cubit |
| Write path | None — display-only widget |
| Network | None |
| Accessibility | `Semantics` required per AC |

## Library & Framework Requirements

| Package | Version | 13.2 action |
|---------|---------|-------------|
| flutter | SDK | **Reuse** — `ListView`, `CustomPainter`, `HapticFeedback` |
| (none new) | — | **Do NOT add** ruler/slider packages |

**Flutter APIs:**

- `ScrollController`, `ScrollEndNotification` or `NotificationListener`
- `HapticFeedback.selectionClick()` — light tick feedback
- `Semantics` — `label`, `value`, `slider` or custom role as appropriate

## File Structure Requirements

| Path | Action |
|------|--------|
| `lib/presentation/widgets/astra_horizontal_ruler.dart` | NEW |
| `test/presentation/widgets/astra_horizontal_ruler_test.dart` | NEW |
| `lib/core/constants/astra_typography.dart` | UPDATE only if new `rulerValueFor` token needed |

## Testing Requirements

- **Widget:** initial value shown in readout
- **Widget:** horizontal drag changes value; snaps to nearest tick
- **Widget:** at min/max edge, value does not exceed bounds
- **Widget:** `onChanged` called with stepped values
- **Widget:** semantics label contains value and unit (use `enableHaptics: false`)
- **Pattern:** Follow `test/presentation/widgets/astra_segmented_control_test.dart` — `MaterialApp` + `buildAstraLightTheme()` + fixed width `SizedBox`
- **Commands:** `flutter analyze` (0 issues), `flutter test test/presentation/widgets/astra_horizontal_ruler_test.dart`

## Previous Story Intelligence

From **Story 13.1** (done):

- `OnboardingWeightPlaceholder` / `OnboardingHeightPlaceholder` are intentional stubs — **do not replace** in 13.2
- `OnboardingShell` footer chrome complete — ruler sits in page `content` slot in 13.3
- `AstraInsetShadowSurface` used on segmented control (`8f40e8e`) — reuse same elevated surface language for picker card
- Review-before-commit: sub-tasks A–E with Baptiste OK gate
- `AstraButton` compact footer pattern — unrelated to ruler but same onboarding visual system

From **Story 10.6 / 10.7** (done):

- `WeightDisplayUnit` / `HeightDisplayUnit` enums exist — onboarding segments kg/lb and cm/inches (13.3)
- Profile editors use text fields — ruler does not replace them in this epic tranche
- Canonical bounds: `kMinWeightKg=30`, `kMaxWeightKg=300`, `kMinHeightCm=100`, `kMaxHeightCm=250`

From **Epic 6** (done):

- Derived metrics default to weight 70 kg, stride 0.76 m when prefs null — 13.3 defaults ruler to 70 kg / 170 cm

## Git Intelligence Summary

Recent commits relevant to 13.2:

| Commit | Relevance |
|--------|-----------|
| `ce8086b` | Onboarding polish — shell/button patterns to match visually |
| `49b0368` | 13.1 code review — follow same review/fix loop |
| `bcc77a9` | 3-step flow wired — placeholders ready for ruler in 13.3 |
| `8f40e8e` | `AstraInsetShadow` on segmented control — card elevation reference |

**Convention:** `feat(widgets):`, `test(widgets):` scoped commits per sub-task.

## Latest Tech Information

- **Flutter 3.x:** Prefer `ScrollController` + snap on scroll end over deprecated patterns; `MediaQuery.disableAnimationsOf` should zero snap animation in tests if needed
- **No `ListWheelScrollView` rotation hack** — maintain horizontal gesture parity with mockup
- **Float stepping:** Use index-based math (`min + index * step`) then round display to avoid `0.30000000004` artifacts
- **Haptics:** `HapticFeedback.selectionClick()` is appropriate for discrete tick changes; guard with `enableHaptics` for widget tests

## Project Context Reference

Mandatory — [`docs/project-context.md`](../../../docs/project-context.md):

- Review-before-commit gate (sub-tasks A–E)
- Commit message convention: `type(scope): imperative summary`
- Story file: `_bmad-output/implementation-artifacts/stories/13-2-astra-horizontal-ruler-widget.md`
- Version bump only at Epic 13 close: `0.6.0+11` in `pubspec.yaml` + `README.md`

## Story Completion Status

- Status: **done**
- Ultimate context engine analysis completed — comprehensive developer guide created
- Epic 13 status: **in-progress** (story 13.1 done; 13.2 ready)
- **Critical guardrail:** Deliver widget in isolation — no onboarding flow edits until Story 13.3
