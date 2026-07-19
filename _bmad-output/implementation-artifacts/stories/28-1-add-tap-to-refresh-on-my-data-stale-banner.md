# Story 28.1: Add Tap-to-Refresh on My Data Stale Banner

Status: review

<!-- Post-audit Epic 28 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 28-1 · diagnostic-gestion-etat-erreur.md §4 (stale — My Data sans onTap) -->
<!-- Prerequisite: Epic 27 done (boot polish); no dependency on 28-2 or 28-3 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want to tap the stale-data banner on My Data to trigger a refresh,
So that stale recovery matches Today's compact stale banner behaviour.

## Acceptance Criteria

1. **Given** `MyDataCubit` state has `isStale == true` (`backgroundStatus == BackgroundCollectionStatus.stale`)
   **When** the `StatusBanner` with `StatusBannerVariant.staleFull` renders
   **Then** the banner is tappable and calls `MyDataCubit.refresh(silent: false)` on tap
   **And** semantics expose it as an actionable control (`Semantics.button: true` via existing `StatusBanner` `onTap` path)

2. **Given** user taps the stale banner
   **When** refresh runs
   **Then** section loading indicators appear per existing My Data loading pattern (`MyDataStatus.loading` → `_SectionLoadingIndicator` in each `SectionCard`)
   **And** banner hides during loading (same contract as Today: `todayStaleBannerVisible` excludes `TodayStatus.loading`)
   **And** banner hides or reappears when refresh completes depending on derived `backgroundStatus`

3. **Given** Today stale banner (`_StaleBannerSlot`)
   **When** this story ships
   **Then** Today behaviour is unchanged — parity only on My Data

4. **Given** widget tests for `MyDataScreen`
   **When** this story ships
   **Then** stale-banner tap test added (mirror `today_screen_selector_test.dart` stale tap pattern)
   **And** `flutter test test/presentation/screens/my_data_screen_test.dart --exclude-tags slow` passes
   **And** `flutter test --exclude-tags slow` passes

**Covers:** My-Data-stale-tap (epics-post-audit inventory) · diagnostic-gestion-etat-erreur.md §4

**Depends on:** Epic 27 closed. First story in Epic 28 (UX Coherence).

**Out of scope:** Today permission unification (28-2), Settings profile gate (28-3), unified `AppFailure` model (AUD-22/23 deferred), `StatusBanner` widget API changes, version bump (Epic 28 close → minor+1, patch=0, build+1).

## Tasks / Subtasks

- [x] **Sub-task A — Wire stale banner tap** (AC: #1, #2, #3)
  - [x] Read fully: `lib/presentation/screens/my_data_screen.dart`, `lib/presentation/cubits/my_data_cubit.dart` (`refresh` / `_refreshImpl`), `lib/presentation/widgets/status_banner.dart`, `lib/presentation/screens/today_screen.dart` (`_StaleBannerSlot`)
  - [x] Add `onTap` to stale `StatusBanner` in `my_data_screen.dart`:

    ```dart
    onTap: () => unawaited(cubit.refresh(silent: false)),
    ```

    Match existing error-banner pattern on same screen (L135–164) and Today stale slot (L448–452).
  - [x] **Do not** change `MyDataCubit.refresh` unless tap fails AC — existing `silent: false` path already emits `MyDataState.loading()` and re-derives stale via `_deriveBackgroundStatus`.
  - [x] **Do not** touch `today_screen.dart` or `_StaleBannerSlot`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Tests** (AC: #4)
  - [x] Extend `test/presentation/screens/my_data_screen_test.dart`:
    - Add `_TrackingRefreshMyDataCubit` extending test harness — override `refresh({bool silent = true})` to increment call counter and record `silent` flag (do not use `_SeededMyDataCubit.refresh` that no-ops).
    - **New:** `stale banner tap invokes cubit refresh with silent false` — seed `_readyState(backgroundStatus: stale)`, tap `StatusBanner`, expect `refreshCalls == 1` and last `silent == false`.
    - **New:** `stale banner exposes actionable semantics` — `tester.ensureSemantics()`, seed stale state with `onTap`-enabled banner, `find.bySemanticsLabel` matching full Android stale copy (`No new steps in 12+ hours` substring).
    - Keep existing `stale state shows full stale banner above Background card` green.
  - [ ] Optional: extend `test/presentation/widgets/status_banner_test.dart` with `staleFull` onTap + semantics test (widget-level); screen test is minimum bar.
  - [x] Run `flutter test test/presentation/screens/my_data_screen_test.dart --exclude-tags slow`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `onTap` on My Data stale `StatusBanner` | Today permission messaging (28-2) |
| Non-silent refresh → section spinners | Settings profile loading gate (28-3) |
| Widget tests for tap + semantics | New l10n strings |
| Parity with Today stale tap contract | `StatusBanner` visual redesign |
| OK-commit sub-task gate | Version bump until Epic 28 close |

### Root cause (read before editing)

**Gap (diagnostic §4):** My Data full stale banner renders without `onTap`; Today compact banner already calls `TodayCubit.refresh(silent: false)` on tap [Source: `diagnostic-gestion-etat-erreur.md` L127–133].

**Current My Data stale block (missing onTap):**

```166:171:lib/presentation/screens/my_data_screen.dart
          if (state.isStale) ...[
            const SizedBox(height: AstraSpacing.kSpaceMd),
            StatusBanner(
              variant: StatusBannerVariant.staleFull,
              isIos: state.isIos,
            ),
          ],
```

**Today reference (preserve unchanged):**

```448:452:lib/presentation/screens/today_screen.dart
            StatusBanner(
              variant: StatusBannerVariant.staleCompact,
              onTap: () => unawaited(
                context.read<TodayCubit>().refresh(silent: false),
              ),
            ),
```

**Error banners on same screen already use `onTap` + `unawaited(cubit.*)`** — copy that pattern, not a new abstraction [Source: `my_data_screen.dart` L135–164].

### Refresh contract (MyDataCubit — likely no changes)

```505:528:lib/presentation/cubits/my_data_cubit.dart
  Future<void> refresh({bool silent = true}) async {
    // ... dedupe via _refreshInFlight ...
  }

  Future<void> _refreshImpl({required bool silent}) async {
    if (!silent &&
        state.status != MyDataStatus.loading &&
        !state.isExporting &&
        !state.isImporting &&
        !state.isPurging) {
      emit(const MyDataState.loading());
    }
```

- `silent: false` → `MyDataStatus.loading` → each `SectionCard` shows `_SectionLoadingIndicator` [Source: L176–201].
- `MyDataState.loading()` resets fields to defaults → `isStale` false during load → banner hidden (matches Today `todayStaleBannerVisible` excluding loading).
- On success: `_emitReadySnapshot` + `_deriveBackgroundStatus` recomputes stale from last ingestion.
- On failure: `_recoverFromRefreshFailure` re-emits ready snapshot — **no error banner** (existing contract; do not add one).
- Concurrent taps: `_refreshInFlight` dedupes — second tap awaits same future (acceptable).

### StatusBanner semantics (no widget changes expected)

When `onTap != null`, widget already sets `Semantics(button: true, onTap: onTap)` with full copy as label [Source: `status_banner.dart` L106–119]. staleFull Android copy: `l10n.bannerStaleFullAndroid`.

### Architecture compliance

- **Layering:** Presentation-only change in `my_data_screen.dart`; no repository/DI edits.
- **State management:** Reuse `MyDataCubit.refresh`; no new cubit methods unless AC #2 fails without them.
- **UX spec:** Full stale banner on My Data (UX-DR8, D-9); tap adds recovery affordance without changing copy [Source: `ux-design-specification.md` §2.5 stale states].
- **A11y:** Actionable stale banner must remain discoverable — rely on `StatusBanner` button semantics; no duplicate CTA elsewhere on My Data for stale.

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/screens/my_data_screen.dart` | **UPDATE** — add `onTap` on stale banner |
| `test/presentation/screens/my_data_screen_test.dart` | **UPDATE** — tap + semantics tests |
| `lib/presentation/cubits/my_data_cubit.dart` | **READ ONLY** — verify refresh contract |
| `lib/presentation/widgets/status_banner.dart` | **READ ONLY** — semantics already implemented |
| `lib/presentation/screens/today_screen.dart` | **DO NOT CHANGE** |
| `test/presentation/widgets/status_banner_test.dart` | **OPTIONAL** — staleFull onTap test |

### Testing requirements

- Default gate: `flutter test --exclude-tags slow`
- Targeted: `test/presentation/screens/my_data_screen_test.dart`
- Reference pattern: `today_screen_selector_test.dart` L724–757 (`stale banner tap invokes cubit refresh`)
- `_SeededMyDataCubit` overrides `refresh` to no-op — use separate tracking subclass for tap test
- OK-commit gate per `docs/project-context.md` — one commit per sub-task A/B

### Cross-story context (Epic 28)

| Story | Scope | Interaction |
|-------|-------|-------------|
| **28-1 (this)** | My Data stale tap | Independent — ship first |
| 28-2 (backlog) | Today permission unification | Explicitly leaves My Data `BackgroundStatusCard` unchanged |
| 28-3 (backlog) | Settings prefs vs profile gate | No overlap |

Epic 28 closes with version bump **minor+1, patch=0, build+1** (currently `0.11.4+29` → `0.12.0+30` at epic close only).

### Previous story intelligence

**27-4 (done):** Lazy HistoryCubit in `app_scaffold.dart`; test harness patterns (`_TrackingRefreshCubit`, seeded cubits); sub-task OK-commit gate; post-audit tracker in `sprint-status-post-audit.yaml`.

**22-3 / 22-4 (done):** Settings retry + SnackBar error feedback — unrelated to stale tap but confirms error UX stays on Settings/Profile, not My Data refresh failures.

**4-2 (done):** Established My Data full stale banner placement above Background card — this story adds interaction only.

### Git intelligence (recent patterns)

Recent commits (Epic 27 close):
- `1f555d4` — docs epic-27 close, version 0.11.4+29
- `3690563` / `3bfdab0` — lazy HistoryCubit + tests
- `f9b5ca3` — story 27-3 close

Follow: minimal single-line production fix, extend existing test file, no version bump until Epic 28 close.

### Latest tech notes

- **flutter_bloc ^9.x** — no package changes; `context.read<MyDataCubit>()` in callback is standard.
- **permission_handler** — unrelated; stale tap does not open settings.
- **StatusBanner** — `InkWell` ripple on tap when `onTap` set; staleFull already uses full padding — no layout change expected.

### Project context reference

- OK-commit gate: `docs/project-context.md` §Development Workflow
- Version bump deferred to Epic 28 close: `.cursor/rules/app-versioning.mdc` (minor+1)
- Test command: `flutter test --exclude-tags slow`
- Active sprint tracker: `sprint-status-post-audit.yaml` (not legacy `sprint-status.yaml` — Epics 1–13 complete)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` §Story 28-1, Epic 28]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-gestion-etat-erreur.md` §4 stale table]
- [Source: `lib/presentation/screens/my_data_screen.dart`]
- [Source: `lib/presentation/screens/today_screen.dart` — `_StaleBannerSlot`]
- [Source: `lib/presentation/cubits/my_data_cubit.dart` — `refresh` / `_refreshImpl`]
- [Source: `lib/presentation/widgets/status_banner.dart`]
- [Source: `test/presentation/screens/today_screen_selector_test.dart` — stale tap test]
- [Source: `test/presentation/screens/my_data_screen_test.dart` — existing stale layout test]
- [Source: `_bmad-output/implementation-artifacts/stories/27-4-lazy-instantiate-history-cubit-on-first-trends-tab.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- `onTap` sur bannière stale My Data → `MyDataCubit.refresh(silent: false)` ; parité Today
- Pas de changement cubit / `StatusBanner` / Today
- Tests : `_TrackingRefreshMyDataCubit`, tap + sémantique bouton (`bannerStaleFullAndroid`)
- `flutter test --exclude-tags slow` — vert

### File List

- `lib/presentation/screens/my_data_screen.dart`
- `test/presentation/screens/my_data_screen_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

### Change Log

- 2026-07-19: My Data stale banner tap-to-refresh (Story 28-1, Epic 28 UX coherence)
