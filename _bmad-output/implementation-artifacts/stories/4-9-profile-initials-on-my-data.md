# Story 4.9: Profile Initials on My Data (Settings Entry)

Status: done

<!-- Depends on Story 4.8 `display_name`. English-only Phase 0. Ultimate context engine analysis completed — comprehensive developer guide created. -->

## Story

As a **user**,
I want a simple profile affordance on My Data using my initials,
So that I have a recognizable entry point for preferences even without an account.

## Acceptance Criteria

1. **Given** a non-empty `display_name` in preferences (trimmed)
   **When** My Data profile header renders
   **Then** a circular badge (~40dp diameter) shows one or two uppercase initials derived from the trimmed name
   **And** single-token names show one letter (first grapheme); space-separated names show first grapheme of first word + first grapheme of last word
   **And** tap scrolls the Profile preferences block into view (display name, and nearby goal/appearance rows per integrated layout)

2. **Given** no display name stored (null or whitespace-only after trim)
   **When** My Data profile header renders
   **Then** a neutral placeholder icon is shown (no fake letters such as `?` or `U`)
   **And** tap opens the display-name editor sheet (same flow as Story 4.8 `DisplayNameEditorRow`)

3. **Given** user updates display name on My Data and save succeeds
   **When** `MyDataCubit` emits updated `displayName`
   **Then** the initials badge updates on rebuild without app restart

4. **Given** UX tone and sovereignty model (UX §4.6, FR9)
   **When** profile header is shown
   **Then** no account CTA, no cloud sync copy, no photo picker, no coach/gamification copy

5. **Given** export, import, or purge in flight
   **When** profile header is interactive
   **Then** tap is disabled (mirror `dataActionInFlight` on goal/display-name rows)

## Tasks / Subtasks

- [x] **Sub-task A — Initials helper** (AC: #1, #3)
  - [x] Add `lib/presentation/utils/display_name_initials.dart` with pure `String? initialsFromDisplayName(String? name)`
  - [x] Algorithm: trim → split on whitespace (collapse empty) → if empty return `null`; if one token return uppercase first grapheme; if 2+ tokens return first grapheme of first + first grapheme of last token (uppercase)
  - [x] Grapheme: use first UTF-16 code unit cluster via `String.runes` (no new `characters` dependency)
  - [x] Unit tests: `test/presentation/utils/display_name_initials_test.dart` — `Alex`→`A`, `Marie Dupont`→`MD`, `Jean Paul Sartre`→`JS`, trim, empty/null, `Élise`→`É`, single space, punctuation-only → `null`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `ProfileInitialsBadge` widget** (AC: #1–#2, #4)
  - [x] Add `lib/presentation/widgets/profile_initials_badge.dart`:
    - Props: `String? displayName`, `VoidCallback? onTap`, `bool enabled`
    - Circle ~40dp (`SizedBox` 40×40), `BoxDecoration` color `colors.bgElevated`, shape circle (`kRadiusFull` or `BoxShape.circle`)
    - Letters: `AstraTypography.headline` or `label` centered, `textPrimary`, max 2 chars
    - Placeholder: `Icons.person_outline` (or `Icons.account_circle_outlined`), `textMuted`, semantic label **Profile, no name set**
    - With initials: semantics **Profile, {initials}**
    - Outer tap target: min `kMinTouchTarget` (48dp) via `Material` + `InkWell` padding or `SizedBox` wrapper
  - [x] Widget tests: `test/presentation/widgets/profile_initials_badge_test.dart` — initials vs placeholder; disabled tap; semantics labels
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — My Data header integration + scroll anchor** (AC: #1–#3, #5)
  - [x] Convert `MyDataScreen` body scroll column to **StatefulWidget** (private `_MyDataScreenBody` acceptable) to hold `GlobalKey` on Profile `SectionCard`
  - [x] Insert header row **after** screen title `My Data` and **after** stale/error banners, **before** Background `SectionCard`:
    - Horizontal row: `ProfileInitialsBadge` + optional trailing spacing; badge reads `state.displayName` from `BlocBuilder`
    - `onTap` when name set: `Scrollable.ensureVisible(profileSectionKey.currentContext!, duration: 300ms, curve: easeInOut, alignment: 0.1)`
    - `onTap` when no name: `showDisplayNameEditorSheet` → `cubit.updateDisplayName` (reuse 4.8 save + SnackBar on failure pattern)
    - `enabled: !dataActionInFlight`
  - [x] Attach `key: _profileSectionKey` to existing Profile `SectionCard` (line ~233 in `my_data_screen.dart`)
  - [x] **Do not** reorder locked sections: Background → Footprint → Daily goal → Appearance → Profile → Your data
  - [x] Extend `my_data_screen_test.dart`: header shows `MD` for `displayName: 'Marie Dupont'`; placeholder when null; Profile section order tests still pass
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Verification** (AC: #3–#5)
  - [x] `flutter analyze` + `flutter test`
  - [x] Manual: set name → badge `MD`; clear name → icon; edit name → badge updates without restart; tap with name scrolls to Profile; tap without name opens sheet; export in flight disables badge tap
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope:**
- Profile initials **header** row on My Data (visual affordance + navigation)
- Pure initials derivation helper + tests
- Scroll-to-Profile or open display-name sheet when empty
- Disable header during data admin in-flight

**Out of scope — defer:**
- i18n / localized initials rules
- Photo upload, account linking, cloud avatar
- Today greeting or celebration personalization (4.8)
- Moving Appearance / Your data sections (locked by 4.7–4.8)
- New preference keys or repository APIs (read existing `displayName` on `MyDataState`)

### Pipeline position (Epic 4)

```text
Display name + Today greeting (4.8) ✅
        │
        v
Profile initials header (4.9)   ← THIS STORY
        │
        v
Epic 4 retrospective (optional) → Epic 5 (5.5 KGP first)
```

### Architecture contracts

| Decision / FR | Requirement for 4.9 |
|---------------|---------------------|
| FR9 | Read-only use of `display_name`; no new storage |
| UX §4.6 | Calm, factual; no account/cloud/photo affordances |
| UX §2.5 | Section cards order unchanged; header is **above** section list |
| Story 4.8 | `MyDataState.displayName`, `updateDisplayName`, `showDisplayNameEditorSheet` |
| Story 4.7 | Section order below header preserved |
| D-03 | Do not write prefs from screen — use `MyDataCubit.updateDisplayName` only |

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 4.9 changes | Must preserve |
|------|---------------|------------------|---------------|
| `my_data_screen.dart` | Title → banners → Background…Profile…Your data | Add profile header row + `GlobalKey` on Profile section; likely StatefulWidget for keys | All `BlocListener`s, export/import/purge, `dataActionInFlight`, section order |
| `my_data_state.dart` | Has `displayName` | **No change** unless tests need seeding | All export/import/purge fields |
| `my_data_cubit.dart` | `updateDisplayName` emits new name + `postDisplayNameUpdate` | **No change** — badge rebuilds from emit | In-flight guards |
| `display_name_editor_row.dart` | Profile section row | **No change** — header complements row | Semantics / enabled pattern |
| `display_name_editor_sheet.dart` | Bottom sheet editor | Reuse from header tap when no name | Max length 32 |
| `my_data_screen_test.dart` | Section order + disabled row tests | Add header tests; keep Profile-between-Appearance-and-Your-data tests green | `_SeededMyDataCubit` pattern |

### Profile header layout (UX alignment)

UX §2.5 lists section cards only; this story adds a **non-section** header affordance (epics + 4.8 handoff). Placement:

```text
[My Data title]
[stale / error banners if any]
[NEW: ProfileInitialsBadge row — centered or start-aligned, kSpaceMd below title]
[Background SectionCard]
…
[Profile SectionCard]  ← scroll target when name set
```

| Element | Spec |
|---------|------|
| Badge size | ~40dp circle |
| Touch target | ≥ `AstraSpacing.kMinTouchTarget` (48dp) |
| Background | `colors.bgElevated` |
| Initials typography | Figtree via `AstraTypography` (headline or label, centered) |
| Placeholder | Material icon, `textMuted`, **not** letter glyphs |

### Initials derivation (normative)

```dart
// Pseudocode — implement in display_name_initials.dart
String? initialsFromDisplayName(String? name) {
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  String firstGrapheme(String s) {
    final runes = s.runes;
    if (runes.isEmpty) return '';
    return String.fromCharCodes([runes.first]).toUpperCase();
  }
  if (parts.length == 1) return firstGrapheme(parts.first);
  return firstGrapheme(parts.first) + firstGrapheme(parts.last);
}
```

| Input (trimmed) | Expected |
|-----------------|----------|
| `Alex` | `A` |
| `Marie Dupont` | `MD` |
| `Jean Paul Sartre` | `JS` |
| `  Élise  ` | `É` |
| `""` / null / `"   "` | `null` → placeholder UI |
| `"!!!"` | `!` or `null` if no runes — document in test |

### Tap behavior flow

```text
Badge tap (enabled)
    ├─ displayName present → Scrollable.ensureVisible(Profile SectionCard)
    └─ displayName absent  → showDisplayNameEditorSheet
                              → cubit.updateDisplayName (same as DisplayNameEditorRow)
                              → SnackBar on !saved
```

When name is set, scrolling to Profile section satisfies AC “scrolls to profile/preferences rows”; user still uses the existing row to edit. **Do not** duplicate full editor UI in the header.

### Recommended file layout

```text
lib/presentation/utils/display_name_initials.dart              # NEW
lib/presentation/widgets/profile_initials_badge.dart           # NEW
lib/presentation/screens/my_data_screen.dart                   # UPDATE (StatefulWidget + header + key)

test/presentation/utils/display_name_initials_test.dart        # NEW
test/presentation/widgets/profile_initials_badge_test.dart     # NEW
test/presentation/screens/my_data_screen_test.dart             # UPDATE
```

### Anti-patterns (do NOT)

- Add `display_name` to `MyDataCubit` SQL paths or new tables
- Show fake initials (`?`, `U`, `AA`) when name is unset
- Add photo picker, sign-in, or “Sync profile” copy
- Reorder section cards (move Profile above Appearance, etc.)
- Call `TodayCubit.refresh` for initials-only UI (metadata already updates on name save via 4.8)
- Log display names in `debugPrint` on production paths
- Introduce `characters` package for one helper unless Baptiste approves new dep
- Break existing `my_data_screen_test` section-order assertions

### Previous story intelligence (Story 4.8 — immediate predecessor)

**Reuse directly:**

- `MyDataState.displayName` loaded in `MyDataCubit.refresh` — badge binds to same field
- `updateDisplayName` + `postDisplayNameUpdate` → Today `refreshMetadata` (no 4.9 changes needed)
- `DisplayNameEditorRow` + `showDisplayNameEditorSheet` — copy tap/save/error pattern for empty-name header tap
- `dataActionInFlight` disables interactive controls
- Sub-task commit discipline: French review brief, wait for Baptiste OK (`docs/project-context.md`)

**4.8 handoff (explicit):**

- Profile **section** with display-name row already lives between Appearance and Your data
- 4.9 adds **header badge above Background**; does not remove the Profile section row

**4.8 review fixes to respect:**

- Onboarding skip clears display name — header should show placeholder after skip
- My Data save failure shows SnackBar — reuse for header-initiated save

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `32aeda5` | 4.8 done — review patterns; Profile section + Today greeting live |
| `90d8ac2` | `my_data_screen.dart` Profile block; `display_name_editor_*` widgets |
| `58a7b62` | Today greeting — out of scope for 4.9 |
| `a9d9a18` | Onboarding display name — header placeholder after skip |

### Library / framework notes

- No new dependencies expected
- `Scrollable.ensureVisible` requires `GlobalKey` on Profile `SectionCard` and a `BuildContext` with scrollable ancestor (`SingleChildScrollView` already present)
- Flutter 3.x: prefer small `StatefulWidget` wrapper over converting entire screen if Baptiste prefers — either is acceptable if keys work

### Testing requirements

| Test | Purpose |
|------|---------|
| `display_name_initials_test.dart` | Algorithm edge cases (AC #1) |
| `profile_initials_badge_test.dart` | Placeholder vs letters; disabled state |
| `my_data_screen_test.dart` | Header visible; section order regression; optional scroll test with `tester.ensureVisible` |
| Existing purge/display-name tests | No change unless header tests need seed `displayName` |

### Handoff for Epic 5

- Epic 4 My Data sovereignty surface complete after 4.9
- Epic 5.5 (KGP) is next sprint priority per `sprint-status.yaml` — visual polish stories follow

### Project context reference

- Review-before-commit: `docs/project-context.md` — one sub-task per commit, French review brief, wait for Baptiste OK
- Explain in review brief: why header is above sections, initials algorithm, `GlobalKey` + scroll vs sheet split

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 4.9]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.5 My Data, §4.6 tone]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — presentation layer, user_preferences]
- [Source: `_bmad-output/implementation-artifacts/stories/4-8-local-display-name-and-today-greeting.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/4-7-theme-selector-and-my-data-integration.md` — section order]
- [Source: `lib/presentation/screens/my_data_screen.dart`]
- [Source: `lib/presentation/widgets/display_name_editor_row.dart`]
- [Source: `lib/presentation/cubits/my_data_cubit.dart` — `updateDisplayName`]

## Dev Agent Record

### Agent Model Used

Composer (Cursor Agent)

### Debug Log References

### Completion Notes List

- Added `initialsFromDisplayName` + `hasTrimmedDisplayName` helpers with unit tests (grapheme via `String.runes`, no new deps).
- Added `ProfileInitialsBadge` (40dp circle, 48dp touch target, placeholder `Icons.person_outline`, semantics per AC).
- Extracted `_MyDataScreenBody` StatefulWidget for `GlobalKey` scroll-to-Profile; header badge above Background; shared `_openDisplayNameEditor` with Profile row.
- `flutter test` full suite green; `flutter analyze` no new issues.
- Code review: letter-only initials, `hasDisplayNameInitials` tap routing, trimmed display name row, `context.watch` for live badge, scroll post-frame retry, expanded tests.

### File List

- lib/presentation/utils/display_name_initials.dart (new)
- lib/presentation/widgets/profile_initials_badge.dart (new)
- lib/presentation/screens/my_data_screen.dart (modified)
- test/presentation/utils/display_name_initials_test.dart (new)
- test/presentation/widgets/profile_initials_badge_test.dart (new)
- test/presentation/screens/my_data_screen_test.dart (modified)

## Change Log

- 2026-06-03: Ultimate context engine analysis completed — ready-for-dev comprehensive developer guide
- 2026-06-03: Story 4.9 implemented — profile initials header on My Data; status → review
- 2026-06-03: Code review fixes applied; status → done; epic 4 complete
