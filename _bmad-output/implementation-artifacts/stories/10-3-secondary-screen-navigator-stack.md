# Story 10.3: Secondary Screen Navigator Stack

Status: done

<!-- User mockups attached 2026-06-15 (light only): Profil-light, Data-light, Settings-light, About-light. Dark theme: no mockup-specific behavior — reuse existing `context.astraColors` / theme tokens like all other screens. Header pattern: inline back arrow + gray title (same row, left-aligned). Body content refactors deferred to Stories 10.4–10.8. -->

## Story

As a **user**,
I want back navigation from Profile, Data, Settings, and About,
So that I return to the menu without losing my tab context.

## Acceptance Criteria

1. **Given** the **MENU** tab is selected and the menu hub is visible  
   **When** the user taps **Profile**, **Data**, **Settings**, or **About**  
   **Then** the target screen pushes onto a **nested `Navigator`** stack inside the Menu tab  
   **And** the bottom nav pill remains visible (same as tab screens today)  
   **And** popping returns to the menu hub with **MENU** still selected (`_selectedIndex == 2`)

2. **Given** a pushed secondary screen (mockups: Profil-light, Data-light, Settings-light, About-light)  
   **When** the screen renders (light or dark theme, any accent preset)  
   **Then** a shared header row shows: **`PhosphorIconsRegular.arrowLeft`** back control + title in **`AstraTypography.screenTitleFor`** (gray caption style)  
   **And** arrow and title are **inline on one row**, left-aligned (not a Material `AppBar`)  
   **And** back invokes `Navigator.of(context).pop()` on the **Menu tab nested navigator**  
   **And** header titles match mockups exactly:

   | Destination | Header title |
   |-------------|--------------|
   | Profile | **Profile** |
   | Data | **Data** |
   | Settings | **Settings** |
   | About | **About** |

3. **Given** Profile or Data is pushed  
   **When** the route builds  
   **Then** existing `ProfileScreen` / `MyDataScreen` body content is shown **below** the shared header  
   **And** the screen's **inline** `screenTitleFor` text is **hidden** (no duplicate title — header is the title)  
   **And** `BlocProvider.value` supplies `ProfileCubit` / `MyDataCubit` from `AppScaffold` (cubits are **not** recreated per push)  
   **And** `ThemeCubit` remains available from app root (no re-wrap needed)

4. **Given** Profile row tap  
   **When** navigation starts  
   **Then** `ProfileCubit.refresh()` is awaited (or fire-and-forget with in-flight guard — cubit already dedupes) before/at push  
   **And** opening Data triggers `MyDataCubit.refresh()` similarly

5. **Given** Settings or About row tap  
   **When** navigation starts  
   **Then** a **minimal stub screen** pushes (header + placeholder body only)  
   **And** stubs do **not** duplicate Settings/About card content from mockups — full layout is Stories **10.5** (Settings) and **10.8** (About)

6. **Given** user is on Steps or Trends tab  
   **When** they switch to MENU  
   **Then** existing tab-switch refresh rules in `_onDestinationSelected` are unchanged  
   **And** cubits in `AppScaffold` are **not** disposed when pushing/popping secondary routes

7. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** nav smoke tests cover **Menu → Profile** and **Menu → Data** (tap row → header title + back → pop → Menu hub visible)  
   **And** Settings/About push smoke (tap → header title visible → pop) is included

**Mockup refs:** `Profil-light`, `Data-light`, `Settings-light`, `About-light` (light only; dark follows existing token pattern).

**Depends on:** Stories 10.1, 10.2 (done). **Enables:** Stories 10.4–10.8.

## Tasks / Subtasks

- [x] **Sub-task A — `SecondaryScreenHeader` widget** (AC: #2)
  - [x] Add `lib/presentation/widgets/secondary_screen_header.dart`
  - [x] Row: `IconButton` (`arrowLeft`, `colors.textPrimary`, tooltip `Back`) + `Text(title, style: screenTitleFor)` with small gap — mirror mockup inline layout (not onboarding's arrow-only row)
  - [x] `Semantics`: header label includes title; back button labeled "Back"
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Nested Menu tab `Navigator` + route shell** (AC: #1, #2)
  - [x] Extract `_MenuTabNavigator` (or equivalent) in `app_scaffold.dart` — wrap Menu tab `IndexedStack` child in `Navigator` with `MenuHubScreen` as initial route
  - [x] Add `SecondaryScreenShell` widget (same file or `secondary_screen_shell.dart`): `ColoredBox(bgBase)` + `SafeArea(bottom: false)` + header + `Expanded`/`Flexible` child scroll area
  - [x] Preserve bottom-nav clearance padding on shell body (`kBottomNavBottomOffset + kBottomNavBarHeight + kSpaceMd`)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Wire menu pushes + cubit refresh** (AC: #3, #4, #6)
  - [x] Implement `_onMenuDestinationSelected(MenuHubDestination)` in scaffold (or pass callback into `MenuHubScreen`)
  - [x] Profile route: `SecondaryScreenShell(title: 'Profile', child: ProfileScreen(showInlineTitle: false))` + `BlocProvider.value(value: _profileCubit)` — refresh before push
  - [x] Data route: `SecondaryScreenShell(title: 'Data', child: MyDataScreen(showInlineTitle: false))` + `BlocProvider.value(value: _myDataCubit)` — refresh before push
  - [x] Add `showInlineTitle` param (default `true`) to `ProfileScreen` and `MyDataScreen`; when `false`, skip the top `Text(screenTitleFor)` only — **do not** rename `_kScreenTitle` constants yet (10.4 / 10.8)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Settings + About stubs** (AC: #5)
  - [x] Add `lib/presentation/screens/settings_screen.dart` — stub: shell header "Settings" + minimal placeholder (e.g. centered `Text('Settings', style: body)` or empty `SizedBox` — **no** Units/Notifications/Theme cards)
  - [x] Add `lib/presentation/screens/about_screen.dart` — stub: shell header "About" + minimal placeholder — **no** icon/version layout (Story 10.8)
  - [x] Wire Menu → Settings / About pushes
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Tests** (AC: #7)
  - [x] Update `test/presentation/screens/app_scaffold_test.dart`: Menu → Profile (header "Profile", back arrow, Profile content e.g. "Informations"); pop → Menu hub; Menu → Data (header "Data", sovereignty content e.g. "Storage on this device" or footprint labels)
  - [x] Add `test/presentation/widgets/secondary_screen_header_test.dart` (back tap calls pop; title renders)
  - [x] Update `test/presentation/screens/menu_hub_screen_test.dart`: if navigation moves to scaffold, keep isolated no-op tests OR pump with callback mock
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope (10.3):**
- Nested `Navigator` on Menu tab (index 2)
- Shared secondary header (back arrow + mockup titles)
- `Navigator.push` / `pop` from menu rows
- Wire `ProfileScreen` + `MyDataScreen` with cubit providers + refresh-on-push
- Minimal `SettingsScreen` + `AboutScreen` stubs
- `showInlineTitle: false` to avoid duplicate titles under header
- Nav smoke tests Menu → Profile, Menu → Data (+ Settings/About push/pop)

**Out of scope — do not touch:**
- Profile slim layout (remove Notifications/Appearance) → **Story 10.4**
- Settings content (Units, Notifications, Theme) → **Story 10.5–10.6**
- Unit formatters → **Story 10.7**
- Data sovereignty layout polish, rename `_kScreenTitle` to "Data" → **Story 10.8**
- About icon + version layout → **Story 10.8**
- Steps/Trends screen content, cubit logic beyond refresh-on-push
- Version bump (`0.3.0+5` at **Epic 10 close**, not per sub-story)
- GoRouter

This is a **presentation-layer navigation** change only — no repository, collector, or schema changes.

### Mockup alignment (Baptiste 2026-06-15, light only)

| Element | All four mockups | Implementation (10.3) |
|---------|------------------|------------------------|
| Header layout | Back arrow + title, same row, left | `SecondaryScreenHeader` |
| Title style | Medium gray sans-serif | `AstraTypography.screenTitleFor` |
| Back icon | Thin left arrow | `PhosphorIconsRegular.arrowLeft` |
| Profile title | **Profile** | Header title; hide inline "My Profile" |
| Data title | **Data** | Header title; hide inline "My Data" |
| Settings title | **Settings** | Header on stub |
| About title | **About** | Header on stub |
| Dark theme | *(no mockup)* | Existing `AstraColors` / `ThemeCubit` — same tokens as Menu hub |
| Bottom nav | Not shown in mockups | **Keep visible** — nested navigator stays inside `AppScaffold` body above `AppBottomNav` |
| Profile body | Informations card only | Full current `ProfileScreen` body (10.4 trims) |
| Data body | Background / Footprint / Your data | Full current `MyDataScreen` body (10.8 polishes title rename) |
| Settings body | Units + Notifications + Theme | **Stub only** in 10.3 |
| About body | Icon + Astra Health + Version | **Stub only** in 10.3 |

### Business context

Post-beta UX tranche (sprint-change-proposal 2026-06-15 §4.2): secondary destinations push from Menu hub. Stories 10.1–10.2 delivered tab shell + list UI with no-op taps. Story 10.3 is the navigation glue enabling 10.4–10.8 content refactors.

### Target navigation architecture

```
AppScaffold (Scaffold)
├── IndexedStack
│   ├── [0] TodayScreen + TodayCubit
│   ├── [1] HistoryScreen + HistoryCubit
│   └── [2] Navigator  ← NEW nested stack
│         ├── /  → MenuHubScreen
│         ├── push → SecondaryScreenShell + ProfileScreen (ProfileCubit)
│         ├── push → SecondaryScreenShell + MyDataScreen (MyDataCubit)
│         ├── push → SettingsScreen (stub)
│         └── push → AboutScreen (stub)
├── AppBottomNav (always visible)
└── Cubits hoisted here: Today, History, MyData, Profile (unchanged)
```

**Why nested Navigator:** Root `Navigator.push` from `MenuHubScreen` would cover the bottom nav. Nested navigator keeps the pill visible and preserves MENU tab selection on pop.

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 10.3 changes | Must preserve |
|------|---------------|-------------------|---------------|
| `app_scaffold.dart` | `const MenuHubScreen()` at index 2 | Wrap in nested `Navigator`; menu destination handler; push routes with cubit providers | Cubit hoisting, `_onIngestionComplete`, tab refresh rules, debug FAB on Trends |
| `menu_hub_screen.dart` | `MenuHubDestination` enum; no-op `_onDestinationSelected` | Wire `onTap` → push (via callback or inherited navigator) | Four rows, section layout, title **Menu** |
| `profile_screen.dart` | Title "My Profile" inline; full Profile+Appearance | Add `showInlineTitle`; push target only — **no** layout split | All editors, cubit wiring, persistence |
| `my_data_screen.dart` | Title "My Data" inline; sovereignty layout | Add `showInlineTitle`; push target only | Export/import/purge, `MyDataCubit` listeners |
| `settings_screen.dart` | **Does not exist** | NEW stub | — |
| `about_screen.dart` | **Does not exist** | NEW stub | — |
| `app_scaffold_test.dart` | MENU tab list assertions; no push tests | Add Menu → Profile/Data navigation smoke | 3-tab nav, pill token test |
| `menu_hub_screen_test.dart` | Isolated no-op tap tests | Keep or adjust if API changes | Row/section assertions |

### SecondaryScreenHeader target structure

```
┌─────────────────────────────────────┐
│  ←  Profile                         │  ← arrowLeft + screenTitleFor (gray)
├─────────────────────────────────────┤
│  [existing screen body scroll]      │
│                                     │
└─────────────────────────────────────┘
        [ floating bottom nav pill ]
```

Reference onboarding back control (`onboarding_display_name_page.dart`) for `IconButton` + `arrowLeft` sizing, but **add title text beside arrow** per mockup (onboarding has progress indicator instead).

### Architecture compliance

- **D-10 / Phase 0 nav:** `AppScaffold` + local tab index — **no GoRouter** [Source: `architecture.md`]
- **Presentation-only:** No repository, collector, or schema changes
- **Phosphor back icon:** `PhosphorIconsRegular.arrowLeft` [Source: onboarding pages]
- **Review-before-commit:** One commit per sub-task; stop for Baptiste approval [Source: `docs/project-context.md`]

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `phosphoricons_flutter` | ^1.0.0 | `arrowLeft` back icon |
| `flutter_bloc` | existing | `BlocProvider.value` for pushed routes |
| Flutter SDK | ^3.12.0 | Nested `Navigator`, `MaterialPageRoute` |

No new dependencies.

### File structure requirements

```
lib/presentation/widgets/secondary_screen_header.dart   # NEW
lib/presentation/widgets/secondary_screen_shell.dart    # NEW (or co-locate with header)
lib/presentation/screens/settings_screen.dart           # NEW — stub
lib/presentation/screens/about_screen.dart              # NEW — stub
lib/presentation/screens/app_scaffold.dart              # UPDATE — nested Navigator + pushes
lib/presentation/screens/menu_hub_screen.dart           # UPDATE — wire navigation
lib/presentation/screens/profile_screen.dart            # UPDATE — showInlineTitle param
lib/presentation/screens/my_data_screen.dart            # UPDATE — showInlineTitle param
test/presentation/widgets/secondary_screen_header_test.dart  # NEW
test/presentation/screens/app_scaffold_test.dart        # UPDATE — push smoke
test/presentation/screens/menu_hub_screen_test.dart       # UPDATE if needed
```

### Testing requirements

- **Menu → Profile:** tap Profile row → find header "Profile" + `arrowLeft` → find "Informations" (existing body) → tap back → Menu hub + four rows visible
- **Menu → Data:** tap Data row → header "Data" → sovereignty strings present ("Storage on this device" or export controls) → back → Menu hub
- **Menu → Settings / About:** header titles visible; pop returns to hub
- Assert MENU tab still active after pop (`PhosphorIconsFill.list` or selected semantics)
- Assert inline "My Profile" / "My Data" **absent** on pushed routes (header replaces them)
- Do **not** assert Settings Units/About version content (stubs)
- Run full `flutter test` before story close

### Previous story intelligence (Story 10.2)

Story 10.2 established:
- `MenuHubDestination` enum + four `MenuNavRow`s with no-op handler
- Title **Menu** (not mockup's "My Data")
- `MenuNavRow` horizontal padding intentional
- Code review: ProfileCubit refresh on push **deferred to 10.3** ← implement now
- Sub-task commit + review gate pattern — follow same rhythm

### Previous story intelligence (Story 10.1)

Story 10.1 established:
- `MyDataCubit` / `ProfileCubit` hoisted in `AppScaffold`, off-tab-stack
- Tab refresh: returning to Steps refreshes Today; opening Trends refreshes History
- No MENU-tab refresh hook needed unless product asks — **do not add** without AC

### Git intelligence

Recent nav commits:
- `0b868e4` — Menu hub list + `MenuNavRow` (10.2)
- `20f71bd` — Three-tab bar + menu stub (10.1)

Follow patterns: strict scope table, sub-task commits with review gates, extend existing widgets.

### Latest tech information

- Nested `Navigator` in `IndexedStack` child: standard Flutter pattern; use `MaterialPageRoute` for push/pop
- `ProfileCubit.refresh()` and `MyDataCubit.refresh()` exist with in-flight dedup — safe to call before push
- `phosphoricons_flutter` 1.0.0: `PhosphorIconsRegular.arrowLeft` — verified in onboarding

### Project context reference

- Version bump at Epic 10 close only: `0.3.0+5` [Source: `.cursor/rules/app-versioning.mdc`]
- Mockup assets (light): `assets/c__Users_Baptiste_..._Profil-light-*.png`, `Data-light-*.png`, `Settings-light-*.png`, `About-light-*.png`
- Dark theme: no mockup-specific rules — use `context.astraColors` like all screens

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 10, Story 10.3]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` §4.2 Navigation]
- [Source: `_bmad-output/implementation-artifacts/stories/10-2-menu-hub-full-screen-list.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/10-1-three-tab-bottom-navigation.md`]
- [Source: `lib/presentation/screens/app_scaffold.dart`]
- [Source: `lib/presentation/screens/menu_hub_screen.dart`]
- [Source: `lib/presentation/onboarding/onboarding_display_name_page.dart` — arrowLeft pattern]
- [Source: Mockups: Profil-light, Data-light, Settings-light, About-light (2026-06-15)]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Sub-task A committed: `1d63c49`
- Sub-tasks B–D committed: `1843f30`
- Sub-task E committed: `01b1a87`

### Completion Notes List

- Added `SecondaryScreenHeader` (arrowLeft + gray `screenTitleFor` title, inline row).
- Menu tab wrapped in nested `Navigator` via `_menuNavigatorKey`; bottom nav stays visible on push.
- `SecondaryScreenShell` provides shared header + expanded body; Profile/Data screens keep their own scroll bottom clearance via `showInlineTitle: false`.
- `_onMenuDestinationSelected` pushes Profile/Data with `BlocProvider.value` + cubit refresh; Settings/About are minimal stubs.
- Nav smoke tests: Menu → Profile/Data/Settings/About push + pop; full `flutter test` green.

### File List

- `lib/presentation/widgets/secondary_screen_header.dart` (new)
- `lib/presentation/widgets/secondary_screen_shell.dart` (new)
- `lib/presentation/screens/settings_screen.dart` (new)
- `lib/presentation/screens/about_screen.dart` (new)
- `lib/presentation/screens/app_scaffold.dart` (updated)
- `lib/presentation/screens/menu_hub_screen.dart` (updated)
- `lib/presentation/screens/profile_screen.dart` (updated)
- `lib/presentation/screens/my_data_screen.dart` (updated)
- `test/presentation/widgets/secondary_screen_header_test.dart` (new)
- `test/presentation/screens/app_scaffold_test.dart` (updated)
- `test/presentation/screens/menu_hub_screen_test.dart` (updated)

## Change Log

- 2026-06-15: Story 10.3 created — secondary Navigator stack, mockup-aligned headers (light; dark via existing tokens), Settings/About stubs, push wiring for Profile/Data.
- 2026-06-15: Story 10.3 implemented — nested Menu Navigator, secondary headers/shell, push wiring, stubs, nav smoke tests.
- 2026-06-15: Code review fixes — skip inner SafeArea when embedded, semantics delegated to header, duplicate-push guard, header overflow.

### Review Findings

Addressed in final pass:
- Double `SafeArea` on pushed Profile/Data (`showInlineTitle: false` skips inner inset).
- Screen semantics mismatch (embedded mode omits duplicate screen label; header owns a11y).
- Duplicate route stack on double-tap (`_menuStackTopDestination` guard).
- Header title overflow at large text (`Expanded` on title `Text`).
- Magic `-12` padding → `AstraSpacing.kIconButtonHorizontalInset`.
