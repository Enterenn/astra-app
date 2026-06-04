# Story 5.10: Data Screen — Sovereignty Layout

Status: done

<!-- Sprint Change Proposal 2026-06-04: Data tab owns sovereignty only; goal/theme/profile move to Today/Profil. -->

## Story

As a **user**,
I want data sovereignty controls grouped on the Data tab,
so that background health, footprint, and CSV actions are easy to find.

## Acceptance Criteria

1. **Given** the **DATA** tab is selected  
   **When** the screen renders in light or dark theme with any accent preset (Story 5.8)  
   **Then** the screen **title** reads **My Data** once at the top (body copy — not shortened to "Data")  
   **And** only three `SectionCard` sections exist, in order: **Background** → **Footprint** → **Your data**  
   **And** content scrolls above the floating nav without clipping (bottom padding ≥ `kBottomNavBottomOffset` + `kBottomNavBarHeight` + `kSpaceMd`, same pattern as Story 5.9)

2. **Given** the Data screen after this story  
   **When** inspected  
   **Then** these legacy My Data sections/widgets are **absent**:  
   - `ProfileInitialsBadge` (profile header)  
   - **Daily goal** / `GoalEditorRow`  
   - **Appearance** / `ThemeSelector`  
   - **Profile** / `DisplayNameEditorRow`  
   **And** goal editing remains on **Today → Set goal** (Story 5.9); theme/display name migrate to **Profil** in Story 5.11

3. **Given** stale threshold exceeded (12h Android / 4h iOS)  
   **When** Data tab renders  
   **Then** full `StatusBanner` stale variant appears above cards (unchanged Epic 4.2 / UX-DR8)  
   **And** Today compact stale banner still links to Data tab (no regression)

4. **Given** export, import, or purge flows  
   **When** exercised from **Your data**  
   **Then** behavior is unchanged from Epic 4 Stories 4.3–4.5 (FR-19–21, FR-30):  
   - Export → cache file → share sheet → "Export saved" snackbar  
   - Import → picker → validate → confirm if existing data → "Import complete" snackbar  
   - Purge → export nudge dialog → footprint zeros; prefs survive per FR-20  
   **And** in-flight mutual exclusion on data actions preserved (`isExporting` / `isImporting` / `isPurging`)

5. **Given** error states (export/import/purge)  
   **When** Data tab renders  
   **Then** `StatusBanner` error variants with retry still appear above cards (unchanged)

6. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no regressions; `my_data_screen_test.dart` updated to assert three-section layout and absence of removed widgets; sovereignty flow tests still pass

**Depends on:** Stories 5.8 (done), 5.7 (done), 5.9 (done — Set goal on Today).  
**Prerequisite for:** Story 5.11 (Profil absorbs removed sections).  
**Out of scope:** Profil screen UI, `ProfileCubit`, height/weight rows, accent bi-tone selector, cubit rename to `DataCubit` → **5.11** / later.

---

## Tasks / Subtasks

- [x] **A — Strip non-sovereignty UI** (AC: #2)
  - [x] Remove from `my_data_screen.dart`: `ProfileInitialsBadge`, Daily goal card, Appearance card, Profile card
  - [x] Remove dead code: `_profileSectionKey`, `_scrollToProfileSection`, `_openDisplayNameEditor`, `ThemeCubit` import/listener usage on this screen
  - [x] Remove unused imports (`goal_editor_*`, `display_name_*`, `profile_initials_badge`, `theme_selector`, `theme_cubit`)
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **B — Figma shell alignment** (AC: #1, #3, #5)
  - [x] Match Today scroll shell from Story 5.9: `SingleChildScrollView` + horizontal padding + bottom nav clearance
  - [x] Title row **My Data** at top (mirror Today title placement; use `AstraTypography.captionFor` if matching Today mockup hierarchy, or `AstraTypography.title` per UX §1.3 — pick one and document in Dev Agent Record)
  - [x] Keep stale/error banners between title and first card (current order preserved)
  - [x] Verify three `SectionCard` gaps use `kSpaceMd`
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **C — Cubit / scaffold hygiene (minimal)** (AC: #4)
  - [x] Confirm `MyDataCubit` sovereignty methods unchanged (`exportAndShare`, `pickAndImport`, `confirmAndPurge`, `refresh`)
  - [x] **Do not** remove `updateDailyStepGoal` / `updateDisplayName` from cubit yet — Profile will call them in 5.11; optional: stop loading `displayName`/`dailyStepGoal` in `refresh()` if unused on Data screen (document if done)
  - [x] Verify `AppScaffold` `postGoalUpdate` / `postDisplayNameUpdate` hooks remain wired for cross-tab refresh
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **D — Tests** (AC: #6)
  - [x] Update `test/presentation/screens/my_data_screen_test.dart`:
    - Assert finds **Background**, **Footprint**, **Your data** section headlines
    - Assert finds **no** `GoalEditorRow`, `ThemeSelector`, `DisplayNameEditorRow`, `ProfileInitialsBadge`
    - Remove or rewrite tests for removed sections (goal row, appearance order, profile badge scroll, display-name row)
    - Keep export/import/purge/stale/error tests intact
  - [x] Smoke: `app_scaffold_test.dart` Data tab still renders `MyDataScreen`
  - [x] Full `flutter test` + `flutter analyze`
  - [x] **Stop → review brief → Baptiste OK → commit**

---

## Dev Notes

### Product intent (why this story)

Epic 4 built a monolithic **My Data** screen (footprint + background + CSV + goal + theme + display name). Sprint Change Proposal (2026-06-04) splits responsibilities across four tabs:

| Former My Data section | New home |
|------------------------|----------|
| Background, Footprint, Your data | **DATA tab** (this story) |
| Daily goal | **Today → Set goal** (Story 5.9, done) |
| Appearance (theme) | **Profil → Appearance** (Story 5.11) |
| Display name / profile badge | **Profil → Informations** (Story 5.11) |

This story is **presentation-only**: no schema, ingestion, or CSV logic changes.

### Visual reference

No Data mockup PNG is checked into `assets/` yet. Authoritative layout spec:

- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` §2.5 Data Surface]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md` §5.7 Data screen]
- Shell pattern: mirror Story 5.9 Today scroll + card spacing

**Target layout (top → bottom):**

1. Title **My Data** (not inside a card)
2. Optional stale / error `StatusBanner`(s)
3. `SectionCard` **Background** → `BackgroundStatusCard`
4. `SectionCard` **Footprint** → `FootprintKpiRow`
5. `SectionCard` **Your data** → `DataExportButton` + `DataImportButton` + `DataPurgeButton`

### Architecture compliance

- **Presentation only** — reuse existing widgets; no new dependencies
- **Tokens:** `context.astraColors.*` only (Story 5.8, V-2)
- **Single writer / CSV flows:** do not touch `StepRepository`, `TimeseriesCsvCodec`, or purge/import paths
- **Cubit boundary:** `MyDataCubit` stays the Data tab state owner until optional `DataCubit` rename in a later story
- **File naming:** keep `my_data_screen.dart` / class `MyDataScreen` — epics say `DataScreen` conceptually; avoid rename churn in 5.10
- **Review-before-commit:** one commit per sub-task A–D ([Source: `docs/project-context.md`])

### Current code state (READ before editing)

| File | Today | Change in 5.10 | Preserve |
|------|-------|----------------|----------|
| `lib/presentation/screens/my_data_screen.dart` | 7 sections + profile badge | Remove 4 sections + badge; align scroll padding | BlocListeners (export/import/purge snackbars), stale/error banners, three sovereignty cards, all cubit action wiring |
| `lib/presentation/cubits/my_data_cubit.dart` | Loads goal + displayName | Optional slim `refresh()` | Export/import/purge, footprint, background status |
| `lib/presentation/cubits/my_data_state.dart` | Has `dailyStepGoal`, `displayName` | No change required | Sovereignty fields |
| `lib/presentation/screens/app_scaffold.dart` | Index 2 = `MyDataScreen` | No change | Tab index 2 = Data; `_navigateToMyData()` for Today stale link |
| `lib/presentation/widgets/background_status_card.dart` | Used | Unchanged | — |
| `lib/presentation/widgets/footprint_kpi_row.dart` | Used | Unchanged | — |
| `lib/presentation/widgets/data_*_button.dart` | Used | Unchanged | Accent outline export, secondary import, danger purge |
| `lib/presentation/screens/profile_screen.dart` | Placeholder | **Do not implement** | Story 5.11 |
| `test/presentation/screens/my_data_screen_test.dart` | Tests removed sections | Rewrite layout tests | Export/import/purge/stale groups |

### Section copy locks (exact strings)

| Element | Copy |
|---------|------|
| Tab label (nav) | **DATA** (Story 5.7 — do not change) |
| Screen title | **My Data** |
| Card 1 headline | **Background** |
| Card 2 headline | **Footprint** |
| Card 3 headline | **Your data** |
| Export button | **Export CSV** |
| Purge semantics | **Delete all local health data** (existing `DataPurgeButton`) |

### What NOT to break

- **Today stale compact banner** → navigates to Data tab (`TodayScreen.onNavigateToMyData`)
- **Post-import/purge refresh** in `AppScaffold` (`postImportRefresh`, `postPurgeRefresh`) — refreshes Today/History/MyData cubits
- **Goal updates from Today Set goal** — uses `TodayCubit.updateDailyStepGoal`; `postGoalUpdate` refreshes History + optionally MyData metadata
- **Theme changes** — still work via `ThemeCubit` globally; only the Data-tab UI entry point is removed here (Profil gets it in 5.11)
- **Purge preference survival** — `daily_step_goal`, `theme_mode`, `display_name`, `accent_preset`, onboarding flags must still survive purge (FR-20)

### Testing requirements

| Area | Minimum tests |
|------|----------------|
| Layout | Title **My Data**; exactly 3 section headlines; no removed widgets |
| Sovereignty | Existing export/import/purge/stale/error tests pass unchanged or with fixture tweaks only |
| Scaffold | Data tab index 2 renders screen (smoke in `app_scaffold_test.dart`) |
| Regression | Full `flutter test` |

### Previous story intelligence (5.9)

- Today uses scroll + bottom nav padding formula — **reuse on Data screen**
- Set goal on Today is live; **removing goal row from Data is safe**
- `displayName` still loaded in `TodayCubit` / `MyDataCubit` but unused on those screens until 5.11 — optional cleanup in 5.10 cubit refresh
- Widget test pattern: `_SeededMyDataCubit` emits fixed state — no async DB in widget tests

### Previous story intelligence (5.8)

- All buttons/banners use preset-aware `accentPrimary`, `statusOk`, `statusStale`, etc.
- Data export outline border uses `accentPrimary` — verify still correct after layout trim

### Previous story intelligence (5.7)

- Data tab = index **2**; Profil = index **3**
- Floating nav requires bottom scroll inset on all tab screens

### Git intelligence

Recent commits (Story 5.9): Today Figma layout, `ActivityStatsRow`, `WeekProgressRow`, goal ring copy, review polish. Pattern: focused commits per sub-task, widget tests colocated under `test/presentation/`, semantic colors only.

### Project context reference

- [Source: `docs/project-context.md`] — review-before-commit per sub-task
- [Source: `_bmad-output/planning-artifacts/epics.md` § Story 5.10]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` §2.5]
- [Source: `_bmad-output/planning-artifacts/architecture.md` § Frontend Architecture]
- [Source: `_bmad-output/implementation-artifacts/stories/5-9-today-figma-layout-no-greeting.md`] — scroll shell pattern
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md`] — Epic 4 split rationale

---

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

- Title typography: chose `AstraTypography.captionFor(colors)` to mirror Today screen (Story 5.9) hierarchy, not `AstraTypography.title`.
- `_MyDataScreenBody` simplified from `StatefulWidget` to `StatelessWidget` after removing profile scroll/edit state.
- `MyDataCubit.refresh()` slimmed for Data tab (footprint + stale only); goal/displayName kept on cubit for Story 5.11.
- FGS in-process collection reuses UI `BackgroundCollector` (fixes `database_closed` during CSV import after file picker).
- CSV export: `FilePicker.saveFile` first, share sheet fallback if save cancelled.

### Completion Notes List

- ✅ Data tab: two cards — Storage on this device + Backup & restore (Step tracking removed after UX review)
- ✅ Removed ProfileInitialsBadge, Daily goal, Appearance, Profile; goal/theme/name live on Today/Profil
- ✅ Storage intro in card; footprint shows file size only (`on your phone`)
- ✅ Scroll shell aligned with Today; stale/error banners above cards; CSV export/import/purge unchanged
- ✅ `MyDataCubit` / `AppScaffold` hooks unchanged for Story 5.11
- ✅ Tests updated; full suite green
- ✅ Post-review: export in-flight mutex, import/purge success ack, removed dead `clock` on screen
- ✅ Import/export CSV verified on Android emulator

### File List

- `lib/core/di/app_dependencies.dart`
- `lib/presentation/cubits/my_data_cubit.dart`
- `lib/presentation/screens/app_scaffold.dart`
- `lib/presentation/screens/my_data_screen.dart`
- `lib/presentation/widgets/background_status_card.dart`
- `lib/presentation/widgets/footprint_kpi_row.dart`
- `lib/presentation/widgets/data_import_button.dart`
- `lib/presentation/widgets/data_purge_button.dart`
- `test/presentation/cubits/my_data_cubit_export_test.dart`
- `test/presentation/cubits/my_data_cubit_goal_test.dart`
- `test/presentation/cubits/my_data_cubit_test.dart`
- `test/presentation/screens/my_data_screen_test.dart`
- `test/presentation/screens/app_scaffold_test.dart`
- `test/presentation/widgets/background_status_card_test.dart`
- `test/presentation/widgets/footprint_kpi_row_test.dart`
- `test/widget_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/stories/5-10-data-screen-sovereignty-layout.md`

### Change Log

- 2026-06-04: Story 5.10 — sovereignty-only Data screen; UX copy and layout polish with Baptiste
- 2026-06-05: CSV import DB lifecycle fix, save-to-device export, code-review cubit hardening; story done

---

## Story completion status

- **Status:** done
- **Completion note:** Data tab sovereignty layout shipped; CSV import/export hardened on Android
