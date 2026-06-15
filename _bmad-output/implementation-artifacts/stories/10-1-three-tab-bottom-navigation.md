# Story 10.1: Three-Tab Bottom Navigation

Status: done

<!-- User mockup attached 2026-06-15: Steps screen with 3-tab navbar (STEPS · TRENDS · MENU), Phosphor icons. Nav-only story — screen layout changes are Epic 11. -->

## Story

As a **user**,
I want a simpler bottom bar with Steps, Trends, and Menu,
So that primary actions stay visible and secondary screens don't clutter the bar.

## Acceptance Criteria

1. **Given** onboarding-complete user on main shell  
   **When** bottom navigation renders  
   **Then** exactly **three** tabs display: **STEPS**, **TRENDS**, **MENU**  
   **And** floating pill styling is preserved (72px bar, squircle active tab, safe area, accent fill — Story 5.7 tokens unchanged)  
   **And** **DATA** and **PROFILE** tabs are removed from `AppBottomNav`

2. **Given** tab labels and icons (Phosphor, mockup `Today-light`)  
   **When** compared to mockup  
   **Then** **STEPS** replaces **TODAY** (same sneaker metaphor: `sneakerMove` Regular/Fill)  
   **And** **TRENDS** is unchanged (`chartBar` Regular/Fill)  
   **And** **MENU** uses a list/hamburger icon (`list` Regular/Fill — three horizontal lines per mockup)  
   **And** inactive tab = Regular glyph; active tab = matching Fill glyph (Story 5.7 pattern)

3. **Given** `AppScaffold` `IndexedStack`  
   **When** refactored for 3 primary tabs  
   **Then** index **0** = Steps surface (`TodayScreen` — content unchanged this story)  
   **And** index **1** = Trends surface (`HistoryScreen` — unchanged)  
   **And** index **2** = Menu hub **stub** (minimal placeholder until Story 10.2)  
   **And** `MyDataScreen` and `ProfileScreen` are **removed from IndexedStack** (not bottom tabs)

4. **Given** cubit lifecycle in `AppScaffold`  
   **When** DATA/PROFILE leave the tab bar  
   **Then** `MyDataCubit` and `ProfileCubit` **remain instantiated** in `AppScaffold` (do **not** dispose)  
   **And** `_onIngestionComplete`, `postGoalUpdate`, and `postImportRefresh` / `postPurgeRefresh` callbacks still refresh `_myDataCubit` where they do today  
   **And** tab-switch refresh hooks: Steps (index 0) and Trends (index 1) behavior unchanged; remove `openingData` / `openingProfile` tab-switch refreshes

5. **Given** debug chart benchmark FAB  
   **When** Trends tab selected (`_selectedIndex == 1`)  
   **Then** `ChartBenchmarkDevFab` still shows in `kDebugMode` only

6. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** navigation tests updated for 3 tabs (no TODAY/DATA/PROFILE labels in nav)

**Mockup ref:** `assets/c__Users_Baptiste_..._Today-light-*.png` — navbar shows STEPS (active squircle) · TRENDS · MENU on accent pill; Phosphor shoe, chart, list icons.

**Depends on:** Epics 1–9 done. **Enables:** Stories 10.2–10.8, Epic 11 (Steps layout).

## Tasks / Subtasks

- [x] **Sub-task A — `AppBottomNav` three-tab config** (AC: #1, #2)
  - [x] Update `_tabs` in `lib/presentation/widgets/app_bottom_nav.dart`:
    - Tab 0: label `STEPS`, icons `PhosphorIconsRegular.sneakerMove` / `PhosphorIconsFill.sneakerMove`
    - Tab 1: label `TRENDS`, icons unchanged
    - Tab 2: label `MENU`, icons `PhosphorIconsRegular.list` / `PhosphorIconsFill.list`
  - [x] Remove DATA and PROFILE entries
  - [x] Update file/class doc comment (was "Four-tab", now three-tab)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `AppScaffold` IndexedStack remap** (AC: #3, #4, #5)
  - [x] Add `lib/presentation/screens/menu_hub_screen.dart` — minimal stub: screen title placeholder (e.g. "Menu" or "My Data" per 10.2 prep), no list rows yet
  - [x] `_tabScreens`: `[TodayScreen, HistoryScreen, MenuHubScreen]` — drop MyData/Profile from stack
  - [x] `_onDestinationSelected`: keep `returningToToday` (index 0) + `openingTrends` (index 1); remove index 2/3 DATA/PROFILE branches
  - [x] Keep `_myDataCubit` / `_profileCubit` construction, disposal, and ingestion callbacks unchanged
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests** (AC: #6)
  - [x] `test/widget_test.dart`: rename test; expect `STEPS`/`TRENDS`/`MENU`; tap MENU (`PhosphorIconsRegular.list`) instead of database/user; remove DATA/PROFILE nav assertions
  - [x] `test/presentation/screens/app_scaffold_test.dart`: same label/icon updates; MENU stub smoke instead of My Data / Profile tab content
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope (10.1):**
- `AppBottomNav`: 3 tabs, new labels/icons
- `AppScaffold`: 3-tab `IndexedStack`, menu stub screen
- Navigation widget/smoke tests

**Out of scope — do not touch:**
- Menu hub list content (Profile, Data, Settings, About rows) → **Story 10.2**
- `Navigator.push` secondary stack → **Story 10.3**
- Today screen title rename ("Today's activity" → "Steps"), week-first card order, day picker, trophy X/7 → **Epic 11**
- Trends analytics cards/chart changes → **Epic 12**
- `MyDataScreen` / `ProfileScreen` layout or cubit logic
- Step ingestion, FGS, repositories, SQLite
- Version bump (`0.3.0+5` at **Epic 10 close**, not per nav story)
- UX spec / architecture doc updates (planning debt; code is source of truth for this tranche)

This is a **presentation-layer nav shell** change only.

### Mockup alignment (Baptiste 2026-06-15)

The attached **Steps** mockup confirms:
- Bottom bar: **3 elements** on floating accent pill
- **STEPS** active: white squircle, purple sneaker + label
- **TRENDS**: inactive chart icon + label on pill
- **MENU**: inactive list/hamburger icon + label on pill
- All icons **Phosphor** (already project standard since Story 5.6)

The mockup also shows future Epic 11 work (screen title "Steps", week card above ring). **Do not implement those in 10.1** — only the navbar change is in scope.

### Business context

Post-beta UX tranche (sprint-change-proposal 2026-06-15 §4.2): reduce tab clutter by moving Data, Profile, Settings, About behind a **Menu** hub. Story 10.1 is the first Epic 10 increment — nav shell only. Epic 10 versioning: **one moyen bump** when full epic closes (`0.3.0+5` projected).

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 10.1 changes | Must preserve |
|------|---------------|-------------------|---------------|
| `lib/presentation/widgets/app_bottom_nav.dart` | 4 tabs: TODAY/TRENDS/DATA/PROFILE; Phosphor Regular/Fill; floating pill 72px | 3 tabs: STEPS/TRENDS/MENU; `list` icon for Menu | Pill dimensions, squircle active state, SafeArea, semantics, `AstraPressable` |
| `lib/presentation/screens/app_scaffold.dart` | 4-tab IndexedStack; indices 0–3; tab-switch refresh for all four | 3-tab stack; menu stub at index 2 | Cubit hoisting, `_onIngestionComplete`, cross-cubit callbacks, debug FAB on Trends, `ChartBenchmarkDevFab` index 1 |
| `lib/presentation/screens/today_screen.dart` | Title "Today's activity"; ring/stats/week layout | **No change** | Full Today UX until Epic 11 |
| `lib/presentation/screens/history_screen.dart` | Trends chart screen | **No change** | Epic 3 content |
| `lib/presentation/screens/my_data_screen.dart` | Data sovereignty screen | **Not in tab stack**; screen file untouched | Reached via Menu in 10.2/10.3 |
| `lib/presentation/screens/profile_screen.dart` | Profile + appearance | **Not in tab stack**; screen file untouched | Reached via Menu in 10.2/10.3 |
| `test/widget_test.dart` | Asserts 4 tab labels; taps database/user icons | Update to 3-tab expectations | Onboarding still hides nav |
| `test/presentation/screens/app_scaffold_test.dart` | 4-tab switch smoke + pill token test | Update labels/icons; MENU stub | Pill height/color/radius assertions |

### Target tab map (after 10.1)

| Index | Nav label | Phosphor icons (inactive / active) | IndexedStack child | Cubit |
|-------|-----------|-------------------------------------|--------------------|-------|
| 0 | STEPS | `sneakerMove` / Fill | `TodayScreen` | `TodayCubit` |
| 1 | TRENDS | `chartBar` / Fill | `HistoryScreen` | `HistoryCubit` |
| 2 | MENU | `list` / Fill | `MenuHubScreen` (stub) | none (10.2 may add) |

**Secondary screens (not tabs):** `MyDataScreen`, `ProfileScreen` — cubits stay in `AppScaffold` until 10.3 wires `Navigator.push` from menu rows.

### Architecture compliance

- **D-10 / Phase 0 nav:** Still `AppScaffold` + local tab index — **no GoRouter** [Source: `architecture.md`]
- **Presentation-only:** No repository, collector, or schema changes
- **Phosphor:** `phosphoricons_flutter ^1.0.0` — do not add Material icons or new icon package [Source: Story 5.6]
- **Review-before-commit:** One commit per sub-task; stop for Baptiste approval [Source: `docs/project-context.md`]

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `phosphoricons_flutter` | ^1.0.0 | Tab icons Regular (inactive) + Fill (active) |
| `figma_squircle` | ^0.6.3 | Active tab squircle (unchanged) |
| Flutter SDK | ^3.12.0 | Project baseline |

Verify `PhosphorIconsRegular.list` and `PhosphorIconsFill.list` compile — standard Phosphor hamburger/list glyph. If absent in this package version, use closest list metaphor (`listBullets`) and note in Dev Agent Record.

### File structure requirements

```
lib/presentation/widgets/app_bottom_nav.dart          # UPDATE — 3 tabs
lib/presentation/screens/app_scaffold.dart            # UPDATE — 3-tab stack
lib/presentation/screens/menu_hub_screen.dart       # NEW — stub only
test/widget_test.dart                                 # UPDATE
test/presentation/screens/app_scaffold_test.dart      # UPDATE
```

Do **not** move `MyDataScreen` / `ProfileScreen` files or rename `TodayScreen` in this story.

### Testing requirements

- Update existing nav smoke tests — no new golden files required
- Assert nav shows exactly 3 labels: STEPS, TRENDS, MENU
- Assert DATA, PROFILE, TODAY absent from bottom nav
- Tap STEPS → Today content visible ("Steps" in ring, "Today's activity" title OK)
- Tap TRENDS → History/Trends content (7 days / 30 days)
- Tap MENU → stub screen visible (not My Data storage content)
- `AppBottomNav uses floating pill tokens` test — keep pill height/color assertions
- Run full `flutter test` before story close

### Previous story intelligence (Epic 9 — Story 9.1)

Epic 9 just closed at `0.2.2+4`/`+5` with Kotlin FGS notification tuning. **No nav overlap.** Pattern to follow: strict scope boundary table, sub-task commits with review gates, physical-device checks waived when not applicable.

Story 5.7 established all floating-nav tokens and Phosphor Regular/Fill selection pattern — **extend, do not rewrite** the pill widget.

### Git intelligence

Recent commits are Epic 9 FGS fixes and Epic 8 goal-history. Nav code untouched since Epic 5 (`5-7-four-tab-floating-navigation`). Reuse 5.7 patterns for squircle, spacing constants in `astra_spacing.dart`, and test structure in `app_scaffold_test.dart`.

### Latest tech information

- `phosphoricons_flutter` 1.0.0: icon naming is `PhosphorIconsRegular.*` / `PhosphorIconsFill.*` — same API as Stories 5.6–5.7
- No new dependencies required for 10.1
- IndexedStack keeps off-screen tabs mounted — Menu stub is cheap; Today/History cubits unchanged

### Project context reference

- Version bump at Epic 10 close only: `0.3.0+5` [Source: `.cursor/rules/app-versioning.mdc`, sprint-change-proposal 2026-06-15]
- Epic 10 supersedes Epic 5 four-tab nav (5.7) — intentional regression of tab count
- Menu hub title in 10.2 will read **My Data** (screen title, not nav label) — stub can use neutral "Menu" text for 10.1

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 10, Story 10.1]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` §4.2 Navigation]
- [Source: `_bmad-output/implementation-artifacts/stories/5-7-four-tab-floating-navigation.md` — pill tokens, Phosphor pattern]
- [Source: `lib/presentation/widgets/app_bottom_nav.dart`]
- [Source: `lib/presentation/screens/app_scaffold.dart`]
- [Source: Mockup: `assets/.../Today-light-*.png`]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Sub-task A: `AppBottomNav` reduced to 3 tabs (STEPS/TRENDS/MENU); TODAY→STEPS label rename; MENU uses `list` Regular/Fill icons; pill styling unchanged.
- Layout tweak (pre-review): pill shrink-wraps to content (3×52px items + 2×24px gaps + 24px horizontal padding); centered at bottom, no longer full-width.
- Sub-task B: `MenuHubScreen` stub added; `IndexedStack` remapped to [TodayScreen, HistoryScreen, MenuHubScreen]; MyData/Profile removed from tab stack but cubits retained with ingestion callbacks; tab-switch refresh for DATA/PROFILE removed; debug FAB still on Trends (index 1).
- Sub-task C: Nav smoke tests updated for 3-tab labels/icons; MENU tap shows stub title; `flutter test` all pass; `flutter analyze` no new issues (10 pre-existing info/warnings).
- Code review (2026-06-15): approved; added MENU active Fill icon assertion in nav smoke tests; ProfileCubit refresh on push deferred to Story 10.3.

### File List

- `lib/core/constants/astra_spacing.dart` (modified)
- `lib/presentation/widgets/app_bottom_nav.dart` (modified)
- `lib/presentation/screens/app_scaffold.dart` (modified)
- `lib/presentation/screens/menu_hub_screen.dart` (new)
- `test/widget_test.dart` (modified)
- `test/presentation/screens/app_scaffold_test.dart` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/stories/10-1-three-tab-bottom-navigation.md` (modified)

## Change Log

- 2026-06-15: Story 10.1 — three-tab bottom navigation (STEPS/TRENDS/MENU), MenuHubScreen stub, nav tests updated.
