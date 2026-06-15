# Story 10.2: Menu Hub Full-Screen List

Status: done

<!-- User mockup attached 2026-06-15: Menu-light — mockup title "My Data" superseded by product decision: screen title **Menu** (aligns with MENU tab). Informations (Profile, Data), Other (Settings, About). Mockup also shows Achievements + Help rows; sprint scope excludes them (deferred backlog). Nav-only list UI this story; row navigation wired in 10.3. -->

## Story

As a **user**,
I want a menu page listing Profile, Data, Settings, and About,
So that I can reach secondary screens from one place.

## Acceptance Criteria

1. **Given** the **MENU** tab is selected  
   **When** the menu hub screen renders (light or dark theme, any accent preset)  
   **Then** the screen **title** reads **Menu** once at the top (`AstraTypography.screenTitleFor` — same gray caption style as Today/Profile/Data screens)  
   **And** this title is the **menu hub** label — **not** the Data sovereignty screen (`MyDataScreen`, titled **My Data** until Story 10.8 renames it to **Data**)

2. **Given** the menu hub layout (mockup `Menu-light`)  
   **When** content renders  
   **Then** exactly **two** `SectionCard` sections appear, in order:  
   - **Informations** → rows: **Profile**, **Data**  
   - **Other** → rows: **Settings**, **About**  
   **And** each row shows a right chevron (`PhosphorIconsRegular.caretRight`, same as Profile rows)  
   **And** rows are tappable with semantics (`button: true`, label includes destination name)  
   **And** content scrolls above the floating nav without clipping (bottom padding ≥ `kBottomNavBottomOffset` + `kBottomNavBarHeight` + `kSpaceMd`)

3. **Given** the attached mockup (`Menu-light`)  
   **When** compared to implementation  
   **Then** card spacing, section headlines, and row typography match existing `SectionCard` / profile-row patterns  
   **And** **Achievements** and **Help** rows are **absent** (deferred backlog per sprint-change-proposal 2026-06-15 — mockup shows them but they are out of sprint scope)

4. **Given** a menu row tap  
   **When** the user selects Profile, Data, Settings, or About  
   **Then** **no navigation occurs yet** — `Navigator.push` and secondary-screen stack are Story **10.3**  
   **And** rows remain wired with `onTap` callbacks (no-op or debug-only) so 10.3 can attach push routes without restructuring the list

5. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** nav smoke tests updated: MENU tab shows **Menu** title + four rows + two section headlines; **not** sovereignty content ("Storage on this device", Export CSV, etc.)

**Mockup ref:** `assets/c__Users_Baptiste_..._Menu-light-*.png` — mockup title was "My Data"; product title **Menu**; Informations card; Other card; MENU tab active in bottom pill.

**Depends on:** Story 10.1 (done). **Enables:** Story 10.3 (Navigator stack), Stories 10.4–10.8 (secondary screen content).

## Tasks / Subtasks

- [x] **Sub-task A — `MenuNavRow` widget** (AC: #2, #3)
  - [x] Add `lib/presentation/widgets/menu_nav_row.dart` — single-line label + `caretRight` chevron; `InkWell` + semantics pattern aligned with `ProfileInfoRow` but **no value sub-line** (navigation row, not editor row)
  - [x] Props: `label`, `onTap`, optional `semanticsHint` (default: "Double tap to open.")
  - [x] Use `AstraTypography.body(context)` for label; padding `kSpaceXs` vertical + `kSpaceSm` horizontal (Baptiste-requested touch inset)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `MenuHubScreen` full layout** (AC: #1, #2, #3, #4)
  - [x] Replace stub in `lib/presentation/screens/menu_hub_screen.dart`:
    - Title: `_kScreenTitle = 'Menu'`
    - `SingleChildScrollView` shell (mirror `MyDataScreen` / `ProfileScreen` padding + bottom nav clearance)
    - `SectionCard(headline: 'Informations')` with `MenuNavRow` × Profile, Data
    - `SectionCard(headline: 'Other')` with `MenuNavRow` × Settings, About
    - `onTap: () {}` or private `_onDestinationSelected(MenuHubDestination)` no-op until 10.3
  - [x] Wrap body in `Semantics(label: 'Menu')` for screen reader (menu hub, not sovereignty screen)
  - [x] **Do not** import or embed `MyDataScreen`, `ProfileScreen`, cubits, or sovereignty widgets
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests** (AC: #5)
  - [x] Add `test/presentation/screens/menu_hub_screen_test.dart`:
    - Pump `MenuHubScreen` inside `MaterialApp` + theme
    - Assert title "Menu", sections "Informations" / "Other"
    - Assert rows Profile, Data, Settings, About present
    - Assert Achievements, Help absent
    - Assert sovereignty strings absent ("Storage on this device", "Export CSV")
    - Tap each row — no crash (navigation deferred)
  - [x] Update `test/presentation/screens/app_scaffold_test.dart`: MENU tab expects **Menu** title; assert section rows visible
  - [x] Update `test/widget_test.dart`: same title expectation after MENU tap
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope (10.2):**
- `MenuHubScreen`: full-screen list UI matching mockup (minus deferred rows)
- New `MenuNavRow` reusable widget
- Widget tests for menu hub content
- Nav smoke test title/row updates

**Out of scope — do not touch:**
- `Navigator.push` / back arrow / nested stack → **Story 10.3**
- `ProfileScreen` slim layout, title rename to "Profile" → **Story 10.4**
- `SettingsScreen` (notifications, theme, units) → **Story 10.5**
- `MyDataScreen` sovereignty layout, title rename to "Data" → **Story 10.8**
- `AboutScreen` → **Story 10.8**
- `AppScaffold` cubit hoisting (already correct from 10.1)
- Achievements / Help menu entries → **future backlog**
- Version bump (`0.3.0+5` at **Epic 10 close**, not per sub-story)

This is a **presentation-layer menu list** change only — no repository, collector, or schema changes.

### Mockup alignment (Baptiste 2026-06-15)

The attached **Menu-light** mockup confirms:

| Element | Mockup | Implementation (10.2) |
|---------|--------|------------------------|
| Screen title | **My Data** (mockup) | **Menu** — product decision (aligns with MENU tab); mockup title superseded |
| Section 1 headline | **Informations** | ✅ |
| Section 1 rows | Profile, Data, **Achievements** | Profile, Data only — **Achievements excluded** |
| Section 2 headline | **Other** | ✅ |
| Section 2 rows | Settings, **Help**, About | Settings, About only — **Help excluded** |
| Row chevron | `>` right-aligned | `PhosphorIconsRegular.caretRight` |
| Cards | White elevated, rounded | Reuse `SectionCard` → `ElevatedCard` |
| Bottom nav | MENU active (squircle + list Fill icon) | Already done in 10.1 — no change |

**Naming (prevent regressions):** The **menu hub** screen title is **Menu**. The **Data sovereignty screen** (`MyDataScreen`) title remains **My Data** until Story 10.8 renames it to **Data**. Do **not** rename `MyDataScreen._kScreenTitle` in 10.2.

### Business context

Post-beta UX tranche (sprint-change-proposal 2026-06-15 §4.2): four-tab nav replaced by three tabs; secondary destinations live behind a **Menu** hub full-screen list. Story 10.2 delivers the hub list UI; 10.3 wires push navigation; 10.4–10.8 reshape destination screens.

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 10.2 changes | Must preserve |
|------|---------------|-------------------|---------------|
| `lib/presentation/screens/menu_hub_screen.dart` | Stub: title "Menu", no cards/rows | Full list UI, title **Menu**, two `SectionCard`s, four `MenuNavRow`s | Stateless widget; no cubit; stays in `IndexedStack` index 2 |
| `lib/presentation/screens/app_scaffold.dart` | `const MenuHubScreen()` at index 2 | **No change** unless 10.3 prep needs callback injection (defer) | Cubit hoisting, tab indices, ingestion callbacks |
| `lib/presentation/screens/my_data_screen.dart` | Sovereignty screen, title "My Data" | **Untouched** | Full Epic 4 sovereignty behavior |
| `lib/presentation/screens/profile_screen.dart` | Profile + appearance, title "My Profile" | **Untouched** | Reached via menu in 10.3 |
| `lib/presentation/widgets/section_card.dart` | Headline + child in `ElevatedCard` | **Reuse as-is** | Shared across screens |
| `lib/presentation/widgets/profile_info_row.dart` | Label + value + chevron (editor row) | **Pattern reference only** — menu rows are label-only |
| `test/presentation/screens/app_scaffold_test.dart` | MENU tap → expects `find.text('Menu')` | Assert **Menu** title + row assertions | 3-tab nav, pill token test |
| `test/widget_test.dart` | Same "Menu" expectation | Same **Menu** title + key rows | Onboarding still hides nav |

### Target menu hub structure

```
Menu                             ← screenTitleFor (gray caption)

┌─ Informations ─────────────────┐
│  Profile                    >  │
│  Data                       >  │
└────────────────────────────────┘

┌─ Other ────────────────────────┐
│  Settings                   >  │
│  About                      >  │
└────────────────────────────────┘
```

Optional enum for 10.3 handoff (recommended, keep in `menu_hub_screen.dart`):

```dart
enum MenuHubDestination { profile, data, settings, about }
```

10.2: `_onDestinationSelected` is empty. 10.3: maps to `Navigator.push` routes.

### Architecture compliance

- **D-10 / Phase 0 nav:** Still `AppScaffold` + local tab index — **no GoRouter** [Source: `architecture.md`]
- **Presentation-only:** No repository, collector, or schema changes
- **Phosphor chevrons:** `PhosphorIconsRegular.caretRight` — same as Profile rows [Source: Story 5.11]
- **Review-before-commit:** One commit per sub-task; stop for Baptiste approval [Source: `docs/project-context.md`]

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `phosphoricons_flutter` | ^1.0.0 | Row chevron `caretRight` |
| Flutter SDK | ^3.12.0 | Project baseline |

No new dependencies required.

### File structure requirements

```
lib/presentation/widgets/menu_nav_row.dart          # NEW — navigation list row
lib/presentation/screens/menu_hub_screen.dart       # UPDATE — stub → full list
test/presentation/screens/menu_hub_screen_test.dart # NEW
test/presentation/screens/app_scaffold_test.dart    # UPDATE — title + rows
test/widget_test.dart                               # UPDATE — title
```

Do **not** create `settings_screen.dart`, `about_screen.dart`, or modify `MyDataScreen` / `ProfileScreen` in this story.

### Testing requirements

- New dedicated `menu_hub_screen_test.dart` — isolated widget tests (faster than full scaffold)
- Nav smoke: MENU tab → **Menu** title; Profile/Data/Settings/About visible; sovereignty content absent
- Assert Achievements and Help **not** found
- Row tap smoke: no exception (onTap no-op)
- Keep existing 3-tab nav and pill token tests green
- Run full `flutter test` before story close

### Previous story intelligence (Story 10.1)

Story 10.1 established:
- `MenuHubScreen` stub at `IndexedStack` index 2
- Title placeholder was "Menu" — **kept as "Menu"** (product decision; aligns with MENU tab label)
- `MyDataCubit` / `ProfileCubit` remain in `AppScaffold` but off-tab-stack
- Code review note: ProfileCubit refresh on push **deferred to 10.3**
- Pill nav shrink-wrap + centered layout; `list` Regular/Fill for MENU tab

Follow 10.1 patterns: strict scope table, sub-task commits with review gates, extend existing widgets rather than reinvent.

### Git intelligence

Most recent nav commit: `20f71bd feat(nav): three-tab bottom bar with Menu hub stub (Story 10.1)`.

Files touched in 10.1 relevant to 10.2:
- `menu_hub_screen.dart` — expand stub
- `app_scaffold_test.dart`, `widget_test.dart` — update expectations

Reuse scroll-shell pattern from `my_data_screen.dart` and `profile_screen.dart` for consistent padding.

### Latest tech information

- `phosphoricons_flutter` 1.0.0: `PhosphorIconsRegular.caretRight` — verified in `profile_info_row.dart`
- No Flutter/Dart API changes required
- `SectionCard` + `ElevatedCard` already handle theme/accent via `context.astraColors`

### Project context reference

- Version bump at Epic 10 close only: `0.3.0+5` [Source: `.cursor/rules/app-versioning.mdc`, sprint-change-proposal 2026-06-15]
- Menu hub title **Menu** aligns with bottom-nav MENU tab; sovereignty screen stays **My Data** until 10.8
- Achievements / Help explicitly deferred [Source: sprint-change-proposal §Out of sprint, epics.md backlog table]

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 10, Story 10.2]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` §4.2 Navigation]
- [Source: `_bmad-output/implementation-artifacts/stories/10-1-three-tab-bottom-navigation.md`]
- [Source: `lib/presentation/screens/menu_hub_screen.dart`]
- [Source: `lib/presentation/widgets/section_card.dart`]
- [Source: `lib/presentation/widgets/profile_info_row.dart` — chevron/semantics pattern]
- [Source: Mockup: `assets/.../Menu-light-*.png`]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Semantics test initially used `find.bySemanticsLabel('Menu')` — matched both Semantics wrapper and Text; fixed with descendant Semantics predicate (same pattern as `my_data_screen_test.dart`).

### Completion Notes List

- **Sub-task A:** Added `MenuNavRow` — label-only navigation row with `PhosphorIconsRegular.caretRight`, `InkWell`, and `Semantics(button: true)`.
- **Sub-task B:** Replaced `MenuHubScreen` stub with full scroll layout: title **Menu**, two `SectionCard`s (Informations / Other), four rows, `MenuHubDestination` enum + no-op `_onDestinationSelected` for Story 10.3 handoff. No cubit or sovereignty imports.
- **Sub-task C:** Added `menu_hub_screen_test.dart` (5 tests); updated nav smoke tests in `app_scaffold_test.dart` and `widget_test.dart`. `flutter analyze` — no new issues; `flutter test` — all pass.

### File List

- `lib/presentation/widgets/menu_nav_row.dart` (new)
- `lib/presentation/screens/menu_hub_screen.dart` (updated)
- `test/presentation/screens/menu_hub_screen_test.dart` (new)
- `test/presentation/screens/app_scaffold_test.dart` (updated)
- `test/widget_test.dart` (updated)

## Change Log

- 2026-06-15: Story 10.2 — Menu hub full-screen list UI (`MenuNavRow`, `MenuHubScreen` layout, widget + nav smoke tests).
- 2026-06-15: Code review — title locked to **Menu** (mockup "My Data" superseded); `MenuNavRow` horizontal padding intentional; no extra semantics tests (deferred test pass).

### Review Findings

- [x] [Review][Decision] Screen title **Menu** vs spec **My Data** — Baptiste confirmed **Menu**; spec updated (mockup title superseded).
- [x] [Review][Dismiss] `MenuNavRow` horizontal padding — intentional per Baptiste; differs from profile rows by design.
- [x] [Review][Defer] Row semantics / chevron / theme-variant tests — not added; broader test reduction pass planned later.
