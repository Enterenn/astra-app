# Story 23.2: Add Semantic Coverage for Unit Option Tiles

Status: done

<!-- Post-audit Epic 23 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 23-2 · diagnostic-accessibilité-statique.md Bloquant · AUD-26 -->
<!-- Prerequisite: Story 23-1 — done (Today Set goal semantics + ExcludeSemantics pattern) -->
<!-- Version bump: deferred to Epic 23 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **TalkBack/VoiceOver user**,
I want each unit option tile announced as a button with its unit name,
So that I can change units without unlabeled tappable areas.

## Acceptance Criteria

1. **Given** `_UnitOptionTile` InkWell in `unit_option_picker_sheet.dart` (L70–104)
   **When** the semantics tree is built
   **Then** the tile is wrapped in `Semantics(button: true, label: …)` with the localized unit name (AUD-26)
   **And** the label uses the existing `label` parameter (already localized via `labelFor` at call sites — no duplicate ARB keys required)

2. **Given** a tile with `selected: true`
   **When** semantics are built
   **Then** `Semantics(selected: true)` reflects the current selection (mirror `accent_preset_selector.dart` L85–89)
   **And** unselected tiles report `selected: false`

3. **Given** the tile row contains a `Text` label and optional check `Icon`
   **When** parent `Semantics` is applied
   **Then** child `Text` is wrapped in `ExcludeSemantics` so the parent label is announced once (Story 23-1 lesson)
   **And** the decorative check icon is wrapped in `ExcludeSemantics` (audit Mineur L203–207 — fix while touching the widget)

4. **Given** `showUnitOptionPickerSheet` opened from Settings (distance, weight, height, language)
   **When** assistive tech traverses the sheet
   **Then** each option is individually focusable/activatable with its unit/language name
   **And** tapping via `find.bySemanticsLabel(...)` still selects and pops the sheet (existing behaviour preserved)

5. **Given** existing widget tests
   **When** this story ships
   **Then** `unit_option_picker_sheet_test.dart` adds semantics coverage: button role, selected state, tap-by-semantics
   **And** existing selection test still passes
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-26 · diagnostic-accessibilité-statique.md Bloquant (`_UnitOptionTile`) · settings_screen unit/language pickers

**Depends on:** Story 23-1 — **done** (`ExcludeSemantics` on visual children pattern)

**Out of scope:** Today Set goal button (23-1 — done), `liveRegion` (23-3), segmented control keyboard focus (23-4), chart semantics (23-5), settings notifications `MergeSemantics` (23-7), version bump until Epic 23 closes, refactoring sheet to a new picker widget.

## Tasks / Subtasks

- [x] **Sub-task A — Semantics wrapper on `_UnitOptionTile`** (AC: #1, #2, #3)
  - [x] Wrap `Material`/`InkWell` block in `Semantics(button: true, label: label, selected: selected)`
  - [x] Wrap `Text(label, …)` in `ExcludeSemantics`
  - [x] Wrap check `Icon` in `ExcludeSemantics` when `selected`
  - [x] Preserve `minHeight: 48`, styling, `onTap`, and generic `<T>` API — no call-site changes in `settings_screen.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Semantics widget tests** (AC: #4, #5)
  - [x] Extend `test/presentation/widgets/unit_option_picker_sheet_test.dart`
  - [x] Test: open sheet → `tester.ensureSemantics()` → each distance option has `button: true` with localized label (`l10n.unitDistanceMetric`, `l10n.unitDistanceImperial`)
  - [x] Test: selected option (`metric`) reports `flagsCollection.isSelected == Tristate.isTrue`; other option `isFalse`
  - [x] Test: `tester.tap(find.bySemanticsLabel(l10n.unitDistanceImperial))` → sheet pops with `DistanceDisplayUnit.imperial`
  - [x] Re-run existing `returns selected distance unit` test — behaviour unchanged
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Regression** (AC: #5)
  - [x] `dart analyze`
  - [x] `flutter test test/presentation/widgets/unit_option_picker_sheet_test.dart`
  - [x] `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `Semantics` on `_UnitOptionTile` (button + label + selected) | New ARB keys (labels already localized at call site) |
| `ExcludeSemantics` on Text + check icon | `settings_screen.dart` changes |
| Semantics widget tests in `unit_option_picker_sheet_test.dart` | Theme selector / accent chip changes |
| Preserve generic sheet API + all four Settings pickers | Version bump (Epic 23 close) |

### Root cause (read before editing)

**Audit finding:** `_UnitOptionTile` InkWell has no `Semantics` — Bloquant for TalkBack/VoiceOver on Settings unit/language sheets [Source: diagnostic-accessibilité-statique.md L131–135, L359–363].

**Impact surface:** `showUnitOptionPickerSheet` is shared by four Settings flows:
- `_pickLanguage` — automatic + language codes
- `_pickDistanceUnit` — `DistanceDisplayUnit`
- `_pickWeightUnit` — `WeightDisplayUnit`
- `_pickHeightUnit` — `HeightDisplayUnit`

All pass localized labels via `labelFor`; fixing the widget fixes all four without call-site edits.

### Current implementation (UPDATE — do not rewrite)

```53:106:lib/presentation/widgets/unit_option_picker_sheet.dart
class _UnitOptionTile<T> extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // Text(label) + optional check Icon — NO Semantics today
```

**Call-site label localization (READ ONLY):**

```105:110:lib/presentation/screens/settings_screen.dart
  final picked = await showUnitOptionPickerSheet<DistanceDisplayUnit>(
    // ...
    labelFor: (unit) => localizedDistanceUnitPreferenceLabel(l10n, unit),
```

Labels resolve via `display_unit_l10n.dart` → ARB keys `unitDistanceMetric`, `unitDistanceImperial`, `unitWeightKg`, `unitWeightLb`, `unitHeightCm`, `unitHeightFtIn`, plus language keys for the language picker.

### Reference pattern — selectable button semantics

Follow `_AccentChip` in `accent_preset_selector.dart`:

```85:89:lib/presentation/widgets/accent_preset_selector.dart
    return Semantics(
      button: enabled && onTap != null,
      enabled: enabled,
      selected: selected,
      label: semanticsLabel,
```

**Adaptation for unit tiles:** All tiles remain tappable (`onTap` always set) → `button: true` always. Use `selected: selected` (not `button: false` on selected — unlike accent chips where selected chip has `onTap: null`).

**ExcludeSemantics pattern (Story 23-1):**

```582:582:lib/presentation/screens/today_screen.dart
                          child: ExcludeSemantics(
```

Child `Text` semantics would override parent `label` without exclusion — mandatory.

### Architecture compliance

- **Presentation-only change** — no cubit, repository, schema, or Settings screen edits
- **Localization:** Reuse existing `label` strings; callers already pass localized text via `labelFor` [Source: Story 10-6, 19-3]
- **OK commit gate:** One commit per sub-task; wait for Baptiste approval [Source: project-context.md § Development Workflow]
- **Generic widget:** Keep `<T>` type param and `showUnitOptionPickerSheet` signature unchanged

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/unit_option_picker_sheet.dart` | UPDATE `_UnitOptionTile.build` — add `Semantics` + `ExcludeSemantics` |
| `test/presentation/widgets/unit_option_picker_sheet_test.dart` | ADD semantics test group |

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md § Test commands]
- Semantics tests: `tester.ensureSemantics()` before assertions [Source: accent_preset_selector_test.dart L82–94]
- Import `dart:ui show Tristate` for `isSelected` assertions
- Use `AppLocalizations` / `l10n_test_helper.dart` — no hardcoded English in new tests
- Existing test taps `find.text('Imperial')` — must still pass (visual label unchanged)

### Previous story intelligence

**From 23-1 (direct epic predecessor):**
- Parent `Semantics.label` is silently overridden by child `Text` without `ExcludeSemantics` — fixed on Today Set goal button
- Dedicated semantics ARB keys only needed when visual copy ≠ action label; unit tiles use same string for both → reuse `label` param
- Semantics tests belong next to the widget under test, not in screen tests

**From 10-6 (original sheet implementation):**
- Sheet returns `T?` — `null` on dismiss, selected value on tap (including re-tapping current selection)
- Settings integration test skipped as flaky; widget-level tests are the contract

**From accent_preset_selector_test (semantics test template):**
- `find.bySemanticsLabel(...)` for discovery and tap
- `tester.getSemantics(...).flagsCollection.isSelected` for selected state

### Git intelligence summary

Recent Epic 23 commits (23-1):
- `feat(l10n): add todaySetGoalSemantics accessibility label`
- `feat(today): wire dedicated Set goal semantics label`
- `test(today): cover Set goal button semantics enabled and disabled`

No conflicting in-flight changes on `unit_option_picker_sheet.dart`.

### Latest tech information

- **Flutter Semantics API (3.x):** `Semantics(button: true, selected: bool, label: String)` maps to platform accessibility bridges. `selected: true` announces as selected/checked in TalkBack/VoiceOver.
- **No new packages** — built-in semantics via `material.dart`.
- **Static audit disclaimer:** Runtime TalkBack/VoiceOver spot-check recommended before Epic 23 close [Source: epics-post-audit.md NFR-AUD-05].

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Version bump at Epic 23 close only: `sprint-status-post-audit.yaml` WORKFLOW NOTES
- UX semantics table: `_bmad-output/planning-artifacts/ux-design-specification.md` §4.3 (Theme selector selected-state pattern applies conceptually)

## Dev Agent Record

### Agent Model Used

claude-sonnet-5-thinking-high

### Debug Log References

### Completion Notes List

- Sub-task A: `_UnitOptionTile` wrapped in `Semantics(button: true, label, selected)`; `Text` and check `Icon` in `ExcludeSemantics` (pattern from 23-1 / accent_preset_selector).
- Sub-task B: Added `semantics` test group — button role, selected state (`Tristate`), tap-by-semantics-label; existing selection test unchanged.
- Sub-task C: `dart analyze` clean (0 errors); widget tests 4/4 pass; full suite `--exclude-tags slow` pass.

### File List

- `lib/presentation/widgets/unit_option_picker_sheet.dart`
- `test/presentation/widgets/unit_option_picker_sheet_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

### Change Log

- 2026-07-17: Story 23-2 — Semantics coverage for unit option tiles (AUD-26); sprint status → review.
- 2026-07-17: Code review passed; story → done.
