# Story 24.2: Remove or Wire Dead Typography and Color Tokens

Status: review

<!-- Post-audit Epic 24 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 24-2 · diagnostic-code-mort.md §1+§3 Haute · AUD-35 · NFR-AUD-08 -->
<!-- Version bump deferred to Epic 24 close (patch+1, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want unused typography wrappers and `borderPrimary` resolved,
So that the design system does not advertise dead APIs.

## Acceptance Criteria

1. **Given** five dead `AstraTypography.*(BuildContext)` wrappers with zero production call sites
   **When** this story ships
   **Then** `display`, `screenTitle`, `label`, `caption`, and `data` are removed from `astra_typography.dart` (AUD-35)
   **And** the corresponding `*For(AstraColors)` helpers remain unchanged and still power `astra_theme.dart` TextTheme mapping

2. **Given** three live `AstraTypography.*(BuildContext)` wrappers still used in presentation code
   **When** this story ships
   **Then** `title`, `headline`, and `body` remain available and all existing call sites compile unchanged
   **And** no drive-by migration of live call sites to `*For(colors)` (out of scope)

3. **Given** `AstraColors.borderPrimary` is assigned in factories/`copyWith`/`lerp` but never read for rendering
   **When** this story ships
   **Then** `borderPrimary` is **removed** from `AstraColors` (preferred over wiring — value duplicates `accentPrimary`; see Dev Notes)
   **And** `borderDefault`, `accentPrimary`, and all other tokens behave identically at runtime

4. **Given** theme construction and accent presets
   **When** light/dark themes build and lerp between presets
   **Then** `buildAstraLightTheme()` / `buildAstraDarkTheme()` still produce valid `ThemeData` with `AstraColors` extension
   **And** `ColorScheme.outline` continues to use `borderDefault` (unchanged)

5. **Given** verification runs after cleanup
   **When** `dart analyze` and `flutter test --exclude-tags slow` execute
   **Then** both pass with zero regressions
   **And** repo grep confirms no remaining `borderPrimary` references under `lib/` or `test/`

**Covers:** AUD-35 · NFR-AUD-08 (no hardcoded hex introduced) · diagnostic-code-mort.md Haute

**Depends on:** Story 24-1 done (explicitly avoided `borderPrimary` on sheet handle — do not revisit).

**Out of scope:** `navLabel` / `weekDayNumber` tokens (24-4), orphan `kDefault*DisplayUnit` (24-5), `displayLabel` getters on display units (code-mort Moyenne — separate story), migrating live `title`/`headline`/`body` call sites to `*For`, wiring accent-colored input focus borders (UX change), version bump until Epic 24 closes.

## Tasks / Subtasks

- [x] **Sub-task A — Remove dead typography wrappers** (AC: #1, #2)
  - [x] Delete lines 110–111, 120–128 from `lib/core/constants/astra_typography.dart` (five methods: `display`, `screenTitle`, `label`, `caption`, `data`)
  - [x] **Keep** `title`, `headline`, `body` wrappers (lines 113–118) — 20+ live call sites in editor sheets, dialogs, settings, profile rows
  - [x] Confirm `astra_theme.dart` `_textTheme` still imports only `*For` helpers — no change expected
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Remove `borderPrimary` from `AstraColors`** (AC: #3, #4)
  - [x] Remove field, constructor param, `copyWith` param, `lerp` line, and factory assignment in `lib/core/constants/astra_colors.dart`
  - [x] Do **not** replace reads with `accentPrimary` — there are no reads today
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Verify analyze + tests + grep** (AC: #5)
  - [x] Run `dart analyze`
  - [x] Run `flutter test test/core/constants/astra_colors_test.dart` + `flutter test --exclude-tags slow`
  - [x] Grep `borderPrimary` under `lib/` and `test/` — expect zero hits
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Remove 5 dead `BuildContext` typography wrappers | Remove live `title`/`headline`/`body` wrappers |
| Remove unused `borderPrimary` token | Wire accent focus borders to a new token |
| Keep all `*For(AstraColors)` helpers | Add `navLabel` / `weekDayNumber` (24-4) |
| Green analyze + test suite | Orphan pref constants (24-5) |
| Grep guard for `borderPrimary` | `displayLabel` enum getters cleanup |

### Root cause (read before editing)

**Audit finding:** Symbol correlation across 181 `lib/` files found five typography `BuildContext` wrappers superseded by `*For(colors)` at call sites, plus `borderPrimary` written but never read [Source: diagnostic-code-mort.md §1 L11–15, §3 L52, Synthèse Haute L110].

**Epic AC:** Remove or wire dead APIs; tests/analyze green [Source: epics-post-audit.md Story 24-2].

**Story 5-8 context:** `borderPrimary` was added as semantic alias for preset `accentPrimary` on accent borders, but no widget ever consumed it — profile sheet fields intentionally use neutral `borderDefault` [Source: profile_sheet_field_decoration.dart L14–37 · story 5-8 gap noted in code-mort].

### Current implementation (UPDATE — surgical deletion only)

**Dead typography wrappers** (zero `lib/` call sites — safe to delete):

```110:128:lib/core/constants/astra_typography.dart
  static TextStyle display(BuildContext context) =>
      displayFor(context.astraColors);
  // ...
  static TextStyle screenTitle(BuildContext context) =>
      screenTitleFor(context.astraColors);
  static TextStyle label(BuildContext context) => labelFor(context.astraColors);
  static TextStyle caption(BuildContext context) =>
      captionFor(context.astraColors);
  static TextStyle data(BuildContext context) => dataFor(context.astraColors);
```

**Live typography wrappers** (DO NOT DELETE — grep-verified call sites):

| Wrapper | Example call sites |
|---------|-------------------|
| `title(context)` | `goal_editor_sheet.dart`, `display_name_editor_sheet.dart`, `confirm_dialog.dart`, `tab_placeholder_body.dart` |
| `headline(context)` | `section_card.dart`, `profile_info_row.dart`, `unit_option_picker_sheet.dart` |
| `body(context)` | `settings_screen.dart`, `menu_nav_row.dart`, `profile_load_error_panel.dart`, 10+ files |

**`*For` helpers stay** — consumed directly by widgets (`screenTitleFor`, `labelFor`, etc.) and by theme:

```7:15:lib/core/constants/astra_theme.dart
TextTheme _textTheme(AstraColors colors) => TextTheme(
  displayLarge: AstraTypography.displayFor(colors),
  headlineMedium: AstraTypography.titleFor(colors),
  titleMedium: AstraTypography.headlineFor(colors),
  bodyLarge: AstraTypography.bodyFor(colors),
  labelLarge: AstraTypography.labelFor(colors),
  bodySmall: AstraTypography.captionFor(colors),
  titleSmall: AstraTypography.dataFor(colors),
);
```

**`borderPrimary` removal targets** in `astra_colors.dart`:

- Constructor field L14, L37
- Factory assignment L107 (`borderPrimary: primary` — duplicates L113 `accentPrimary: primary`)
- `copyWith` param L132, assignment L154
- `lerp` L184

**No presentation widget changes required** — dead code lives entirely in `lib/core/constants/`.

### Recommended approach: remove, do not wire

| Option | Decision |
|--------|----------|
| Wire `borderPrimary` to focus borders | **Reject** — would change profile field focus from neutral gray to accent; UX not requested |
| Wire to any new call site | **Reject** — token value === `accentPrimary`; use `accentPrimary` directly if accent borders needed later |
| Remove `borderPrimary` | **Accept** — eliminates dead API; zero runtime visual change |

### Architecture compliance

- **Core/constants-only** refactor — no cubit, repository, schema, or presentation logic changes [Source: architecture.md layering · design tokens in `core/constants/`]
- **NFR-AUD-08:** no new hardcoded hex; deletion only
- **OK commit gate** — one commit per sub-task; wait for Baptiste OK [Source: docs/project-context.md]
- **ThemeExtension contract:** after removing one field, ensure `copyWith`/`lerp` remain complete for surviving tokens

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/constants/astra_typography.dart` | UPDATE — delete 5 dead wrappers |
| `lib/core/constants/astra_colors.dart` | UPDATE — remove `borderPrimary` |
| `test/core/constants/astra_colors_test.dart` | VERIFY — existing lerp/accent tests should pass unchanged |

**No changes expected:** `astra_theme.dart`, presentation widgets, ARB/l10n, `pubspec.yaml`

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md § Test commands]
- Targeted: `flutter test test/core/constants/astra_colors_test.dart` — lerp t=0/t=1 and preset accent tests must stay green
- No new test file required unless dev agent wants a compile-time guard — existing suite + analyze sufficient for deletion-only diff
- Manual smoke (optional): launch app, open Settings + one editor sheet — typography unchanged on live wrappers

### Previous story intelligence

**From Story 24-1 (done 2026-07-17):**
- Explicitly kept sheet handle on `borderDefault`, not `borderPrimary` — do not revert
- Pattern: 3 sub-tasks, OK commit gate, ~914 tests green with `--exclude-tags slow`
- Presentation-only sibling stories use same gate; this story is even smaller (constants only)
- Quote from 24-1 out-of-scope: *"Typography dead-code cleanup (24-2)"* — that boundary is now in scope here only

**From Epic 23 close:**
- Token/color choices must use `context.astraColors` extension — this story removes unused extension fields, not call-site patterns

### Git intelligence summary

Recent commits (Story 24-1 — same epic, constants-adjacent):
- `389d1e3` — close story 24-1 after code review
- `77023b9` / `ca78f8d` — SheetDragHandle widget + sheet migration
- Commit style: `refactor(design-system): …`, `test(design-system): …`, `chore(review): …`

`astra_typography.dart` / `astra_colors.dart` not touched in 24-1 — clean surface for this story.

### Latest tech information

- **Flutter ThemeExtension:** Removing an unused field from a `ThemeExtension` is a breaking change only for external consumers — this app owns `AstraColors` entirely; update constructor + `copyWith` + `lerp` atomically.
- **Dart analyze:** Unused public members may not always warn on wrappers still referenced by theme via `*For` — manual grep already confirmed dead wrappers.
- **No package upgrades** required for this story.

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (**not** `sprint-status.yaml`)
- Audit source: `_bmad-output/planning-artifacts/audits/diagnostic-code-mort.md`
- Epic source: `_bmad-output/planning-artifacts/epics-post-audit.md` Story 24-2
- Original token spec: `_bmad-output/planning-artifacts/ux-design-specification.md` §1.2–1.3
- Current app version: `0.11.0+25` (`pubspec.yaml`) — do not bump in this story

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5

### Debug Log References

### Completion Notes List

- Sub-task A: Deleted 5 dead BuildContext typography wrappers (`display`, `screenTitle`, `label`, `caption`, `data`) from `astra_typography.dart`. Kept `title`, `headline`, `body`. All `*For` helpers unchanged.
- Sub-task B: Removed `borderPrimary` from `AstraColors` — field, constructor param, factory assignment, `copyWith` param, and `lerp` line. Zero read sites confirmed.
- Sub-task C: `dart analyze` clean (14 pre-existing test warnings, none related). `astra_colors_test.dart` 3/3 green. Full suite `--exclude-tags slow` → 914 passed, 2 skipped, 0 regressions. `rg borderPrimary lib/ test/` → zero hits.

### File List

- lib/core/constants/astra_typography.dart (modified — 13 lines deleted)
- lib/core/constants/astra_colors.dart (modified — 6 lines deleted)

### Change Log

- 2026-07-17: Story context created — ready-for-dev (create-story workflow)
- 2026-07-17: Implementation complete — Sub-tasks A/B/C done, status → review
