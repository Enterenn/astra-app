# Story 24.1: Extract Shared SheetDragHandle Component

Status: review

<!-- Post-audit Epic 24 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 24-1 · diagnostic-coherence-design-system.md Reco #1 · AUD-34 · UX-AUD-08 -->
<!-- First story in Epic 24 — version bump deferred to epic close (patch+1, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want editor sheets to share the same drag handle,
So that sheet chrome feels consistent and duplicated magic numbers disappear.

## Acceptance Criteria

1. **Given** the four profile/goal editor bottom sheets (`display_name`, `goal`, `weight`, `height`)
   **When** the sheet body is built
   **Then** each uses a shared `SheetDragHandle` widget instead of an inline `Center` + `Container` block (AUD-34, UX-AUD-08)
   **And** no `width: 32` / `height: 4` / `BorderRadius.circular(2)` handle literals remain in those four files

2. **Given** `SheetDragHandle` is rendered in light or dark theme
   **When** the handle paints
   **Then** size is **32×4** logical px and corner radius is **2**
   **And** fill color is `context.astraColors.borderDefault` (same as today — do not switch to `borderPrimary` or ad-hoc greys)

3. **Given** existing sheet layout chrome (padding, title, fields, buttons)
   **When** this story ships
   **Then** vertical spacing after the handle stays `SizedBox(height: AstraSpacing.kSpaceMd)` — **do not** fold spacing into the widget unless all four call sites agree
   **And** `MediaQuery.viewInsetsOf`, `SafeArea`, horizontal padding, Save/Cancel order, validation, and return values are unchanged

4. **Given** widget tests for editor sheets
   **When** verification runs
   **Then** existing tests in `goal_editor_sheet_test.dart` and `profile_editor_sheets_test.dart` still pass unchanged in behaviour
   **And** a focused test asserts `SheetDragHandle` renders one `Container` with the canonical dimensions (32×4, radius 2) and `borderDefault` color
   **And** `dart analyze` + `flutter test --exclude-tags slow` pass

5. **Given** a repo-wide search for the duplicated handle pattern
   **When** this story ships
   **Then** the only production implementation of the 32×4 radius-2 sheet handle lives in `sheet_drag_handle.dart`
   **And** no new public spacing tokens are required in `AstraSpacing` for this story (Story 24-4 / AUD-42 may add `kSheetHandle*` later — keep constants private to the widget file for now)

**Covers:** AUD-34 · UX-AUD-08 · diagnostic-coherence-design-system.md Reco #1 (L152)

**Depends on:** Epic 23 complete (no code dependency). Builds on existing editor sheet chrome from Stories 4-6 / 10-7 / 13-3.

**Out of scope:** Dead typography/color tokens (24-2), loading skeleton unification (24-3), chart axis tokens (24-4), orphan pref defaults (24-5), History `PeriodToggle` loading gate (24-6), `ExcludeSemantics` on decorative handle (not in AUD-34), version bump until Epic 24 closes, onboarding sheets (none use this pattern today).

## Tasks / Subtasks

- [x] **Sub-task A — Add `SheetDragHandle` widget** (AC: #2, #5)
  - [x] Create `lib/presentation/widgets/sheet_drag_handle.dart`
  - [x] Stateless widget; private `_kHandleWidth = 32`, `_kHandleHeight = 4`, `_kHandleRadius = 2` (or map width/height to `AstraSpacing.kSpaceXl` / `kSpaceXs` where exact — radius 2 stays literal or `kSpaceXs / 2`)
  - [x] Use `context.astraColors.borderDefault`; wrap in `Center` like current call sites
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Migrate four editor sheets** (AC: #1, #3)
  - [x] Replace duplicated handle block in:
    - `display_name_editor_sheet.dart`
    - `goal_editor_sheet.dart`
    - `weight_editor_sheet.dart`
    - `height_editor_sheet.dart`
  - [x] Import `sheet_drag_handle.dart`; insert `const SheetDragHandle(),` then existing `SizedBox(height: AstraSpacing.kSpaceMd)`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Widget test + regression** (AC: #4)
  - [x] Add `test/presentation/widgets/sheet_drag_handle_test.dart` (dimensions + color token)
  - [x] Run `dart analyze` + `flutter test test/presentation/widgets/sheet_drag_handle_test.dart` + `flutter test test/presentation/widgets/goal_editor_sheet_test.dart` + `flutter test test/presentation/widgets/profile_editor_sheets_test.dart` + `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Shared `SheetDragHandle` widget | `AstraSpacing.kSheetHandle*` public tokens |
| Replace 4 duplicated inline handles | Loading/skeleton patterns (24-3) |
| Widget test for handle + regression | Typography dead-code cleanup (24-2) |
| Preserve sheet behaviour & spacing | Semantic/a11y treatment of handle |

### Root cause (read before editing)

**Audit finding:** Identical sheet drag-handle motif (32×4, radius 2) is copy-pasted across all `*_editor_sheet.dart` files — 16 duplicated lines and three orphan magic numbers [Source: diagnostic-coherence-design-system.md L133, L152 · AUD-34].

**Epic AC:** One shared widget; remove duplicated local handle blocks [Source: epics-post-audit.md Story 24-1].

### Current implementation (UPDATE — do not rewrite sheet logic)

All four sheets share this block at the top of the inner `Column`:

```85:94:lib/presentation/widgets/display_name_editor_sheet.dart
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderDefault,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
```

Same pattern at:
- `goal_editor_sheet.dart` L82–91
- `weight_editor_sheet.dart` L184–193
- `height_editor_sheet.dart` L196–205

**Shared sheet chrome to preserve (read-only context):**
- Outer `Padding(bottom: viewInsets)` → `SafeArea` → horizontal `EdgeInsets.fromLTRB(kScreenHorizontalPadding, kSpaceSm, …, kSpaceMd)`
- Title via `AstraTypography.title(context)`
- Profile sheets use `profileSheetFieldDecoration`; goal sheet uses inline `OutlineInputBorder` — **do not unify here**

### Recommended implementation approach

**New file** `lib/presentation/widgets/sheet_drag_handle.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';

/// Standard modal bottom sheet drag handle (32×4, radius 2).
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  static const double _width = 32;
  static const double _height = 4;
  static const double _radius = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    return Center(
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          color: colors.borderDefault,
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
    );
  }
}
```

**Call-site replacement (each sheet):**

```dart
const SheetDragHandle(),
const SizedBox(height: AstraSpacing.kSpaceMd),
```

Remove now-unused `colors` local **only if** no other references in that `build` method (all four sheets still need `colors` for fields/buttons — keep the variable).

**Do not:**
- Rename to `AstraSheetDragHandle` (epic/AUD name is `SheetDragHandle`)
- Change handle color to `borderPrimary` (dead token — Story 24-2)
- Embed `kSpaceMd` spacing inside the widget (spacing is sheet-layout concern; keeps widget reusable)
- Touch `showModalBottomSheet` signatures or validation logic
- Add golden tests unless Baptiste asks — size + color unit test is enough

### Architecture compliance

- **Presentation-only** refactor — no cubit, repository, or schema changes [Source: architecture.md layering]
- **Design tokens:** color from `AstraColors` extension; spacing after handle stays `AstraSpacing.kSpaceMd`
- **OK commit gate** — one commit per sub-task; wait for Baptiste OK [Source: docs/project-context.md]
- **Naming:** file `sheet_drag_handle.dart`, class `SheetDragHandle` — sits alongside `astra_button.dart`, `profile_sheet_field_decoration.dart` in `lib/presentation/widgets/`

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/sheet_drag_handle.dart` | **NEW** |
| `lib/presentation/widgets/display_name_editor_sheet.dart` | UPDATE — use widget |
| `lib/presentation/widgets/goal_editor_sheet.dart` | UPDATE — use widget |
| `lib/presentation/widgets/weight_editor_sheet.dart` | UPDATE — use widget |
| `lib/presentation/widgets/height_editor_sheet.dart` | UPDATE — use widget |
| `test/presentation/widgets/sheet_drag_handle_test.dart` | **NEW** |

**No changes expected:** cubits, repositories, ARB/l10n, theme definitions, onboarding widgets

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md § Test commands]
- New test sketch:

```dart
testWidgets('renders canonical 32x4 handle with borderDefault', (tester) async {
  await tester.pumpWidget(
    TestMaterialApp(
      theme: buildAstraLightTheme(),
      home: const Scaffold(body: SheetDragHandle()),
    ),
  );
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(SheetDragHandle),
      matching: find.byType(Container),
    ),
  );
  expect(box.constraints?.maxWidth ?? (box as dynamic), /* use find + getSize or inspect decoration */);
  // Prefer: tester.getSize(find.byType(Container)) after pump — width 32, height 4
  // decoration.borderRadius == BorderRadius.circular(2)
  // decoration.color == buildAstraLightTheme()… borderDefault
});
```

- Regression: run existing editor sheet tests — they assert Save/Cancel/validation, not handle markup; should stay green if behaviour unchanged

### Previous story intelligence

**From Epic 23 close (23-7, no story file — git only):**
- Last commit: `feat(a11y): merge semantics on notifications switch, close epic 23, bump 0.11.0+25`
- Epic 23 pattern: small presentation-only diffs, widget tests, OK commit gate per sub-task
- Editor sheets were **not** touched in Epic 23 — safe refactor surface

**From Epic 22 / design-adjacent work:**
- Prefer minimal diffs; do not batch unrelated token cleanup (24-2 owns dead typography)

### Git intelligence summary

Recent commits (Epic 23 a11y — unrelated to sheets):
- `108a5f8` — settings MergeSemantics + version 0.11.0+25
- `2b1c01c` / `a66bb3d` — week day pill semantics tests

Editor sheets last meaningfully touched in profile/onboarding epics (10-7, 13-3). No pending WIP on `*_editor_sheet.dart`.

### Latest tech information

- **Flutter 3.x / Material 3:** Modal bottom sheet drag handles are decorative affordances; centralizing in one widget is standard DS practice — no package dependency required.
- **Theme-aware color:** `borderDefault` already adapts light/dark via `AstraColors` — keep using extension, not hardcoded `Color(0x…)`.
- **Const widget:** `SheetDragHandle` can be `const` at call sites because it reads theme from `context` in `build` (same as current inline pattern).

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Version bump at Epic 24 close only: `sprint-status-post-audit.yaml` WORKFLOW NOTES (patch+1)
- Sprint tracker for post-audit: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (**not** `sprint-status.yaml`)
- Audit source: `_bmad-output/planning-artifacts/audits/diagnostic-coherence-design-system.md`
- Epic source: `_bmad-output/planning-artifacts/epics-post-audit.md` Story 24-1
- UX wireframe: `_bmad-output/planning-artifacts/ux-design-specification.md` §3.8 Goal Editor sheet
- Current app version: `0.11.0+25` (`pubspec.yaml`) — do not bump in this story

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5

### Debug Log References

No blockers encountered.

### Completion Notes List

- Sub-task A: Created `SheetDragHandle` stateless widget with private constants `_width=32`, `_height=4`, `_radius=2`, color from `context.astraColors.borderDefault`.
- Sub-task B: Replaced 10-line `Center(Container(…))` block with `const SheetDragHandle()` in all 4 editor sheets. `colors` variable retained (still used by fields/buttons). `SizedBox(height: kSpaceMd)` preserved at each call site.
- Sub-task C: New `sheet_drag_handle_test.dart` asserts size 32×4, `BorderRadius.circular(2)`, and `Color(0xFFA0A0AA)` (borderDefault). All 914 tests pass (`--exclude-tags slow`), 0 regressions.

### File List

- `lib/presentation/widgets/sheet_drag_handle.dart` (NEW)
- `lib/presentation/widgets/display_name_editor_sheet.dart` (UPDATED)
- `lib/presentation/widgets/goal_editor_sheet.dart` (UPDATED)
- `lib/presentation/widgets/weight_editor_sheet.dart` (UPDATED)
- `lib/presentation/widgets/height_editor_sheet.dart` (UPDATED)
- `test/presentation/widgets/sheet_drag_handle_test.dart` (NEW)

### Change Log

- 2026-07-17: Story context created — ready-for-dev (create-story workflow)
- 2026-07-17: Implemented all 3 sub-tasks — SheetDragHandle widget created, 4 sheets migrated, widget test added, 914 tests passing
