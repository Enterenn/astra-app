# Story 10.8: Data and About Screens

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want Data sovereignty and About info reachable from Menu,
So that secondary tasks stay organized.

## Acceptance Criteria

1. **Given** Menu → Data (nested push; header title **Data** via `SecondaryScreenShell` — Story 10.3)  
   **When** the screen body renders (light or dark theme, any accent preset)  
   **Then** exactly **three** `SectionCard` sections appear in order: **Background** → **Footprint** → **Your data**  
   **And** inline screen title is **hidden** (`showInlineTitle: false`) — header owns the title  
   **And** section headlines match mockup copy exactly (not Story 5.10 "Storage on this device" / "Backup & restore")

2. **Given** Menu → Data with `MyDataCubit` in ready state  
   **When** Background section renders  
   **Then** `BackgroundStatusCard` shows status dot + copy for `healthy`, `stale`, `iosBackfill`, and `permissionDenied` (FR-5, UX-DR12)  
   **And** healthy copy includes relative last sync from `lastIngestionUtc` via `formatRelativeTime`  
   **And** permission-denied state offers settings affordance (`openAppSettings` via `permission_handler`)

3. **Given** stale threshold exceeded (12h Android / 4h iOS per `isStaleData`)  
   **When** Data screen renders  
   **Then** full `StatusBanner(staleFull, isIos: …)` appears **above** the Background card (restores Epic 10 / UX §2.5 — supersedes Story 5.10 "no stale on Data")  
   **And** Today compact stale banner behavior is unchanged (no regression)

4. **Given** Menu → Data with samples in SQLite  
   **When** Footprint section renders  
   **Then** `FootprintKpiRow` shows **sample count**, **database size**, and **last optimized** relative time (FR-13, UX §2.5)  
   **And** uses `formatStepCount`, `formatFileSize`, `formatRelativeTime`  
   **And** null `lastOptimizedUtc` shows honest fallback (e.g. **not optimized yet**)  
   **And** `MyDataCubit.refresh()` loads `lastOptimizedUtc` from `userPreferences.getLastDatabaseOptimizedAt()` (currently **not** fetched — must restore)

5. **Given** Menu → Data  
   **When** Your data section renders  
   **Then** actions appear in order: **Export CSV**, **Import CSV**, **Delete all local data** (danger text)  
   **And** export/import/purge flows, snackbars, error banners, and in-flight mutual exclusion are **unchanged** from Epic 4 (FR-19–21, FR-30)  
   **And** purge confirmation + export nudge dialog behavior unchanged

6. **Given** purge executed from Data screen  
   **When** complete  
   **Then** footprint zeros; `timeseries_samples` cleared; non-health prefs preserved per FR-20 (`daily_step_goal`, `theme_mode`, `accent_preset`, profile fields, units, onboarding, permissions)  
   **And** `daily_goal_effective` table **survives** purge (`StepRepository.purge()` does not delete it — verify, do not change purge SQL)

7. **Given** Menu → About  
   **When** screen renders  
   **Then** centered body shows: app **icon placeholder**, title **Astra Health**, line **Version: {versionName}** from `package_info_plus` (matches `pubspec.yaml` `version` before `+`)  
   **And** no build number in user-facing copy unless mockup requires it (Epic AC: `{versionName}` only)  
   **And** version reads built manifest — no hard-coded version string

8. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** `my_data_screen_test.dart` asserts three-card layout + Background card + footprint KPIs  
   **And** `about_screen_test.dart` (new) asserts Astra Health + version line  
   **And** `app_scaffold_test.dart` Menu → Data smoke updated for **Background** / **Your data** headlines (replaces Storage/Backup assertions)  
   **And** `app_scaffold_test.dart` Menu → About smoke asserts body content (replaces stub-only check)

**Depends on:** Stories 10.3 (done), 10.4 (done), 10.5 (done). **Enables:** Epic 10 close (version bump `0.3.0+5` — **not** in this story).

**Mockup ref:** `Data-light`, `About-light` (2026-06-15).

## Tasks / Subtasks

- [x] **Sub-task A — Recreate `BackgroundStatusCard`** (AC: #2, #3)
  - [x] Add `lib/presentation/widgets/background_status_card.dart` — restore from git `b2d8053` as baseline; adapt to current tokens
  - [x] Props: `BackgroundCollectionStatus status`, `DateTime? lastIngestionUtc`, `DateTime nowUtc`, optional `onOpenSettings`
  - [x] Copy per UX §2.5 / Story 4.2 (healthy / stale card line / ios backfill / permission off)
  - [x] OEM battery hint optional — `BackgroundHealthCapabilityEvaluator` was removed in 5.11; **skip OEM hint** unless evaluator is re-wired (out of scope)
  - [x] Add `test/presentation/widgets/background_status_card_test.dart` — one test per status variant
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Restore full `FootprintKpiRow` + cubit `lastOptimized` fetch** (AC: #4)
  - [x] Extend `FootprintKpiRow` to accept `sampleCount`, `lastOptimizedUtc`, `nowUtc` (restore from git `67155df` pattern)
  - [x] In `MyDataCubit._refreshImpl`, add parallel fetch: `userPreferences.getLastDatabaseOptimizedAt()` and pass to `_emitReadySnapshot`
  - [x] Wire `MyDataScreen` to pass `state.sampleCount`, `state.lastOptimizedUtc`, `clock.nowUtc()` into row
  - [x] Update `footprint_kpi_row_test.dart` if exists, or add widget test
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Data screen three-card layout** (AC: #1, #3, #5)
  - [x] Refactor `my_data_screen.dart`:
    - Order: optional error banners → optional `staleFull` banner → **Background** card → **Footprint** card → **Your data** card
    - Remove `_kStorageIntro` and "Storage on this device" / "Backup & restore" headlines
    - Set `DataPurgeButton` label to **Delete all local data** (update default in widget or call site)
  - [x] Keep `showInlineTitle` param; embedded Menu mode stays `false` (header = **Data**)
  - [x] Preserve all `BlocListener` snackbar wiring and sovereignty action handlers
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — About screen body** (AC: #7)
  - [x] Replace `AboutScreen` stub body with centered column: icon placeholder + **Astra Health** + async version line
  - [x] Reuse `package_info_plus` pattern from pre-10.4 Profile footer (git `729ebf0^`) but format as **`Version: ${info.version}`** per Epic 10.8 AC
  - [x] Icon placeholder: rounded square (~72dp) using `colors.accentPrimary` or `bgElevated` + Phosphor icon (e.g. `footprints` or `heartbeat`) — **no new PNG assets**
  - [x] Scroll + bottom nav clearance if content could clip on small screens
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Tests + verify** (AC: #8)
  - [x] Update `my_data_screen_test.dart`: three headlines; Background section; footprint sample count; absent ThemeSelector/GoalEditor
  - [x] Create `about_screen_test.dart`: pump About with mocked/fake `PackageInfo` or `FutureBuilder` settled state
  - [x] Update `app_scaffold_test.dart` Data + About smoke tests
  - [x] Run full `flutter test` + `flutter analyze`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**This story closes Epic 10 presentation surfaces.** It **restores** the Data mockup layout from sprint-change-proposal / Epic 10, reversing the interim Story 5.10 two-card simplification.

| Area | In scope (10.8) | Out of scope |
|------|-----------------|--------------|
| Data layout | 3 cards: Background / Footprint / Your data | Cubit rename to `DataCubit` |
| Widgets | Recreate `BackgroundStatusCard`; restore `FootprintKpiRow` | Re-add `BackgroundHealthCapabilityEvaluator` / OEM hints |
| About | Icon placeholder + Astra Health + version | OSS licenses screen, privacy links |
| Navigation | Already wired in 10.3 — verify only | GoRouter, tab changes |
| Units | N/A | Settings/Profile unit work (10.6–10.7 done) |
| Version bump | Document epic close target | `pubspec.yaml` bump (`0.3.0+5` at **epic close**, not per story) |
| Purge SQL | Verify behavior unchanged | Schema / repository purge changes |
| Today stale CTA copy | Optional: "see My Data" → "see Data in Menu" — only if trivial | Today screen layout |

**Already done (do not redo):**
- Menu → Data push with `SecondaryScreenShell(title: 'Data')` + `MyDataCubit` provider + refresh (`app_scaffold.dart`)
- Export/import/purge cubit logic, CSV codec, confirm dialogs
- `showInlineTitle: false` on embedded Data route

### Layout reversal context (critical)

Story **5.10** intentionally removed `BackgroundStatusCard` and stale banner from Data (UX pivot 2026-06-04). Story **5.11** deleted `background_status_card.dart` entirely. **Epic 10 Story 10.8** re-aligns with **2026-06-15 mockups** and Epic 10 AC — dev must **not** treat 5.10 as the target layout.

**Target layout (top → bottom):**

1. Optional export/import/purge **error** `StatusBanner`s (unchanged)
2. When `state.isStale` → `StatusBanner(staleFull, isIos: state.isIos)`
3. `SectionCard(headline: 'Background')` → `BackgroundStatusCard`
4. `SectionCard(headline: 'Footprint')` → `FootprintKpiRow`
5. `SectionCard(headline: 'Your data')` → Export + Import + Purge buttons

### Section copy locks (exact strings)

| Element | Copy |
|---------|------|
| Menu row | **Data** (unchanged) |
| Secondary header | **Data** (`SecondaryScreenShell` — do not change) |
| Card 1 headline | **Background** |
| Card 2 headline | **Footprint** |
| Card 3 headline | **Your data** |
| Export | **Export CSV** |
| Import | **Import CSV** |
| Purge button | **Delete all local data** |
| About title | **Astra Health** |
| About version | **Version: {versionName}** (e.g. `Version: 0.2.2`) |

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 10.8 changes | Must preserve |
|------|---------------|---------------------|---------------|
| `my_data_screen.dart` | 2 cards: Storage + Backup; no Background; no stale banner; simplified footprint | 3-card mockup layout; stale banner; wire BackgroundStatusCard | All `BlocListener`s, export/import/purge wiring, `showInlineTitle` API |
| `footprint_kpi_row.dart` | File size only (`fileSizeBytes`) | Restore sample count + last optimized | `formatFileSize` usage |
| `background_status_card.dart` | **Deleted** (5.11) | **Recreate** | — |
| `my_data_cubit.dart` | Refresh fetches footprint + ingestion + permission; **missing** `lastOptimizedUtc` fetch | Add `getLastDatabaseOptimizedAt()` to parallel fetch | Export/import/purge, `_deriveBackgroundStatus`, in-flight guards |
| `my_data_state.dart` | Has `sampleCount`, `lastOptimizedUtc`, `backgroundStatus`, `lastIngestionUtc` | No schema change — wire UI | Sovereignty flags |
| `about_screen.dart` | Stub: shell + `SizedBox.shrink()` | Full centered About body | Keep `SecondaryScreenShell(title: 'About')` |
| `app_scaffold.dart` | Data route: shell + `MyDataScreen(showInlineTitle: false)` | **Verify only** | Cubit providers, refresh-on-push |
| `data_purge_button.dart` | Default label `Erase all step history` | Update default or override to **Delete all local data** | Danger styling, semantics |
| `status_banner.dart` | Has `staleFull`, platform-aware copy | **Use** on Data when stale | Today `staleCompact` unchanged |

### BackgroundStatusCard reference implementation

Restore from git commit `b2d8053` (`lib/presentation/widgets/background_status_card.dart`). Key behavior:

```dart
// Healthy
'Background collection active · Last sync $lastSync'

// Permission denied — show TextButton → onOpenSettings (permission_handler openAppSettings)
'Activity permission off'
```

Pass `nowUtc: context.read<MyDataCubit>().clock.nowUtc()` or inject `TimeProvider` from cubit via screen — prefer reading from cubit's public `clock` field if available, else pass from screen using same clock the cubit uses.

For `onOpenSettings`: use `permission_handler` `openAppSettings()` — already a project dependency.

### FootprintKpiRow reference

Restore multi-KPI layout from git `67155df`. Minimum props:

```dart
FootprintKpiRow(
  sampleCount: state.sampleCount,
  fileSizeBytes: state.fileSizeBytes,
  lastOptimizedUtc: state.lastOptimizedUtc,
  nowUtc: cubit.clock.nowUtc(), // or equivalent
)
```

### About screen pattern

Epic AC differs from old Profile footer (`ASTRA v0.2.2 (5)`). Use:

```dart
FutureBuilder<PackageInfo>(
  future: PackageInfo.fromPlatform(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const SizedBox.shrink(); // or small spinner
    return Text('Version: ${snapshot.data!.version}', ...);
  },
)
```

`package_info_plus: ^10.1.0` already in `pubspec.yaml` — no new dependency.

### Architecture compliance

- **Presentation-only** — no schema, collector, or CSV logic changes [Source: Epic 10 intro]
- **Single writer / purge** — do not modify `StepRepository.purge()` transaction scope [Source: `architecture.md` D-24]
- **Goal history survives purge** — `daily_goal_effective` not in purge DELETE list [Source: Story 8.1 dev notes]
- **FR-20 prefs** — purge preserves theme, profile, units, onboarding [Source: `prd.md` §4.7]
- **D-10 nav** — no GoRouter; nested Menu navigator unchanged [Source: Story 10.3]
- **Review-before-commit** — one commit per sub-task [Source: `docs/project-context.md`]

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `package_info_plus` | ^10.1.0 | About version line |
| `permission_handler` | ^12.0.1 | Background permission → settings |
| `phosphoricons_flutter` | ^1.0.0 | About icon placeholder (optional) |
| Flutter SDK | ^3.12.0 | Layout + `FutureBuilder` |

No new dependencies.

### File structure requirements

```
lib/presentation/widgets/background_status_card.dart          # NEW (recreate)
lib/presentation/widgets/footprint_kpi_row.dart                 # UPDATE — restore KPIs
lib/presentation/screens/my_data_screen.dart                    # UPDATE — 3-card layout
lib/presentation/screens/about_screen.dart                      # UPDATE — full body
lib/presentation/cubits/my_data_cubit.dart                      # UPDATE — lastOptimized fetch
lib/presentation/widgets/data_purge_button.dart                 # UPDATE — label (optional default)
test/presentation/widgets/background_status_card_test.dart      # NEW
test/presentation/widgets/footprint_kpi_row_test.dart           # NEW or UPDATE
test/presentation/screens/my_data_screen_test.dart              # UPDATE
test/presentation/screens/about_screen_test.dart              # NEW
test/presentation/screens/app_scaffold_test.dart                # UPDATE — Data/About smoke
```

**Do not create or modify:**
- `StepRepository.purge()` SQL (unless test proves regression — then fix minimally)
- Settings / Profile screens
- `display_unit_formatter.dart` (10.7 done)
- Version in `pubspec.yaml` (epic close)

### Testing requirements

**`my_data_screen_test.dart`:**
- Finds headlines **Background**, **Footprint**, **Your data**
- Does **not** find "Storage on this device", "Backup & restore", `ThemeSelector`, `GoalEditorRow`
- Footprint shows formatted sample count when seeded
- Stale state shows `StatusBanner` stale copy (seed `BackgroundCollectionStatus.stale`)

**`background_status_card_test.dart`:**
- Each `BackgroundCollectionStatus` renders expected primary copy
- Permission denied tap invokes settings callback

**`about_screen_test.dart`:**
- Finds **Astra Health**
- Version line matches mocked `PackageInfo.version`

**`app_scaffold_test.dart`:**
- Menu → Data: header **Data**, body **Background** (not Storage)
- Menu → About: **Astra Health** visible (not empty stub)

**Regression:** full `flutter test`; sovereignty flow tests in `my_data_screen_test.dart` export/import/purge groups stay green.

### Previous story intelligence (Story 10.7)

- Display formatters complete; **no unit work** on Data/About screens
- Sub-task commit + review gate pattern established
- 695 tests baseline — maintain green count

### Previous story intelligence (Story 10.5)

- Version footer **intentionally removed** from Profile/Settings — **About owns version** in 10.8
- Do not re-add `ASTRA v…` footer to Profile or Settings

### Previous story intelligence (Story 10.3)

- Data header title is **Data**; inline **My Data** hidden when embedded
- `MyDataScreen._kScreenTitle` constant may remain `'My Data'` for semantics/tests with `showInlineTitle: true` — embedded path uses header only
- About was stub-only; 10.8 replaces stub body **inside** existing `SecondaryScreenShell`

### Previous story intelligence (Stories 4.2 / 5.10)

- Story 4.2 built full Background + Footprint widgets; 5.10 simplified then 5.11 deleted Background widget
- Use 4.2 + git history as reconstruction source, Epic 10 AC as authority over 5.10 AC

### Git intelligence

Recent commits (10.7):
- `c7d6521` — imperial editor validation close
- `43671fa` — Story 10.7 test + close
- Pattern: minimal diffs, extend existing tests, review gates per sub-task

Relevant historical commits for reconstruction:
- `b2d8053` — `BackgroundStatusCard` added
- `67155df` — full `FootprintKpiRow`
- `898a3a6` / `28bb8ef` — simplification + deletion (what 10.8 reverses)

### Latest tech information

- **`package_info_plus` 10.x** — `PackageInfo.fromPlatform()` async; reads `version` / `buildNumber` from built manifest; no network [Source: `docs/DEPENDENCIES.md`]
- **Flutter 3.12+** — `FutureBuilder` for About version; no `intl` for relative time (use existing formatters)
- **Epic 10 close verification** — after 10.8 done: bump `pubspec.yaml` to `0.3.0+5`, README status row, BETA checklist units toggle [Source: sprint-change-proposal §Versioning]

### Project context reference

- Version bump at **Epic 10 close** only: `0.3.0+5` [Source: `.cursor/rules/app-versioning.mdc`]
- About `package_info_plus` must match release APK `aapt dump badging` [Source: sprint-change-proposal-2026-06-15 §Versioning]
- Review-before-commit mandatory [Source: `docs/project-context.md`]

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 10, Story 10.8]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` §4.2, §Versioning]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` §2.5, §3.5]
- [Source: `_bmad-output/implementation-artifacts/stories/10-3-secondary-screen-navigator-stack.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/4-2-my-data-footprint-and-background-status.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/5-10-data-screen-sovereignty-layout.md` — **superseded for layout by 10.8**]
- [Source: `_bmad-output/implementation-artifacts/stories/8-1-daily-goal-history-schema-and-repository.md` — purge preserves `daily_goal_effective`]
- [Source: `lib/presentation/screens/my_data_screen.dart`]
- [Source: `lib/presentation/screens/about_screen.dart`]
- [Source: `lib/presentation/cubits/my_data_cubit.dart`]
- [Source: `lib/data/repositories/step_repository.dart` — `purge()`]
- [Source: git `b2d8053` — `background_status_card.dart`]
- [Source: git `67155df` — `footprint_kpi_row.dart`]
- [Source: git `729ebf0^` — Profile `_ProfileVersionFooter` pattern]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Restored `BackgroundStatusCard` from git `b2d8053` without OEM `capabilities` prop (out of scope per story).
- `FootprintKpiRow` relative-time KPI uses `inDays` once elapsed ≥ 24h — test expects `1 day ago` not `28 hours ago`.
- `app_scaffold_test` mocks `package_info_plus` MethodChannel for About navigation smoke.

### Completion Notes List

- ✅ Sub-task A: `BackgroundStatusCard` recreated with four status variants + permission settings affordance; 4 widget tests.
- ✅ Sub-task B: `FootprintKpiRow` restored (sample count, DB size, last optimized); `MyDataCubit` fetches `lastOptimizedUtc`; 3 widget tests updated.
- ✅ Sub-task C: `MyDataScreen` three-card layout (Background → Footprint → Your data); stale full banner restored; purge label **Delete all local data**.
- ✅ Sub-task D: `AboutScreen` centered body with Phosphor icon placeholder, **Astra Health**, `Version: {versionName}` via `package_info_plus`.
- ✅ Sub-task E: Screen + scaffold tests updated; `about_screen_test.dart` added; **710 tests green**, `flutter analyze` no new issues in changed files.

### File List

- `lib/presentation/widgets/background_status_card.dart` (new)
- `lib/presentation/widgets/footprint_kpi_row.dart` (updated)
- `lib/presentation/screens/my_data_screen.dart` (updated)
- `lib/presentation/screens/about_screen.dart` (updated)
- `lib/presentation/cubits/my_data_cubit.dart` (updated)
- `lib/presentation/widgets/data_purge_button.dart` (updated)
- `test/presentation/widgets/background_status_card_test.dart` (new)
- `test/presentation/widgets/footprint_kpi_row_test.dart` (updated)
- `test/presentation/screens/my_data_screen_test.dart` (updated)
- `test/presentation/screens/about_screen_test.dart` (new)
- `test/presentation/screens/app_scaffold_test.dart` (updated)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (updated)

## Change Log

- 2026-06-16: Story 10.8 created — restores Epic 10 Data mockup (Background/Footprint/Your data), recreates deleted BackgroundStatusCard, full About with package_info; reverses 5.10 interim layout; ready for dev.
- 2026-06-16: Story 10.8 implemented — three-card Data layout, BackgroundStatusCard, FootprintKpiRow KPIs, About screen body, tests; status → review.
- 2026-06-16: Code review fixes — `lastOptimizedUtc` clears after purge; About `PackageInfo` cache; Epic 10 close `0.3.0+5`.
