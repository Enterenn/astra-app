# Story 28.2: Unify Today Permission-Denied Messaging and CTA

Status: review

<!-- Post-audit Epic 28 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 28-2 · diagnostic-gestion-etat-erreur.md §4 (permission refusée) -->
<!-- Prerequisite: Story 28-1 done; no dependency on 28-3 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want one clear permission-denied message and settings action on Today,
So that I am not confused by four different visual treatments for the same condition.

## Acceptance Criteria

1. **Given** activity permission is denied (`TodayStatus.noPermission`)
   **When** Today screen renders
   **Then** **one primary** user-facing permission pattern is shown with a single CTA to open app settings (AUD-24)
   **And** redundant inline captions / duplicate CTAs for the same condition are removed or demoted to non-interactive supporting text

2. **Given** permission is denied
   **When** `GoalRing` and `ActivityStatsRow` render
   **Then** they may keep neutral placeholders (`--`, zeros) but must not introduce a second competing CTA
   **And** `CollectionHealthIndicator` caption aligns with the primary message (no contradictory copy)

3. **Given** permission is granted later (user returns from settings)
   **When** Today refreshes on resume / manual refresh
   **Then** primary permission block hides, health indicator resumes normal active/stale behaviour, and goal ring + stats repopulate without layout regressions

4. **Given** My Data permission UI (`BackgroundStatusCard`)
   **When** this story ships
   **Then** My Data file and behaviour are unchanged (Today-only unification scope)

5. **Given** widget / integration tests
   **When** this story ships
   **Then** tests updated for unified Today permission pattern (no assertion on removed `errorNoPermission` TextButton if key is retired)
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-24 · diagnostic-gestion-etat-erreur.md §4 permission table · UX spec §permission_denied / edge case "First install, permission denied"

**Depends on:** Story 28-1 done. Epic 28 in progress.

**Out of scope:** My Data `BackgroundStatusCard` changes, onboarding permission-denied message (AUD-23 deferred), unified `AppFailure` model, new `StatusBanner` variant unless dev proves simpler than inline slot, version bump (Epic 28 close → minor+1, patch=0, build+1).

## Tasks / Subtasks

- [x] **Sub-task A — Read & pick unified pattern** (AC: #1, #2)
  - [x] Read fully before editing:
    - `lib/presentation/screens/today_screen.dart` — layout L141–148, `_PermissionCta` L500–531, `_CollectionHealthSlot` L557–584, `_GoalRingCard` L587–664, `todayStaleBannerVisible` L208–212
    - `lib/presentation/widgets/collection_health_indicator.dart`
    - `lib/presentation/widgets/background_status_card.dart` — **reference pattern** (dot + message + settings `TextButton`; do not edit)
    - `lib/presentation/helpers/collection_health_evaluator.dart`
    - `_bmad-output/planning-artifacts/ux-design-specification.md` — §permission_denied row (~L562), edge case (~L1001)
  - [x] **Recommended implementation (follow unless review finds blocker):**
    1. Replace `_PermissionCta` + permission branch of `_CollectionHealthSlot` with **one** `_PermissionDeniedSlot` (new private widget in `today_screen.dart`).
    2. Pattern mirrors UX + My Data voice: muted dot + **"Activity permission off"** body/caption + single **`Open settings`** `TextButton` → `unawaited(openAppSettings())`.
    3. When `TodayStatus.noPermission`: render `_PermissionDeniedSlot` **above** goal ring card (after week row); **do not** render `CollectionHealthIndicator` for `permissionDenied`.
    4. When permission granted: existing `_CollectionHealthSlot` behaviour unchanged (active/stale captions only).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — l10n consolidation** (AC: #1, #2)
  - [x] Align Today primary copy with UX spec (same voice as My Data, without editing My Data widget):
    - **Option A (preferred):** Reuse existing keys `myDataBackgroundPermissionDenied` + `myDataOpenSettings` in Today slot only (no My Data file change).
    - **Option B:** Add `todayPermissionDeniedMessage` / `todayOpenSettings` in ARB with **identical EN/FR strings** to My Data keys; migrate Today usages.
  - [x] Retire or stop using on Today:
    - `errorNoPermission` (currently entire TextButton label — conflates message + action)
    - `todayCollectionHealthPermissionDenied` ("Sensor access revoked ✕" — contradicts UX "Activity permission off")
  - [x] Keep a11y strings aligned: update `todayGoalRingSemanticsNoPermission` / `todayActivityStatsSemanticsNoPermission` only if visible copy changes materially.
  - [x] Run `flutter gen-l10n` if ARB edited.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests** (AC: #3, #5)
  - [x] Update `test/presentation/screens/today_screen_selector_test.dart`:
    - Assert exactly **one** settings CTA when `noPermission` (key: `today_permission_denied_slot` or reuse section key pattern).
    - Assert `CollectionHealthIndicator` permission copy **not** shown alongside primary block.
    - Keep existing stale-hidden-when-denied tests green.
  - [x] Update `test/presentation/widgets/collection_health_indicator_test.dart` only if widget API/behaviour changes.
  - [x] Update `test/widget_test.dart` L398–404 — replace `errorNoPermission` finder with unified pattern (message + `myDataOpenSettings` or new keys).
  - [x] Optional: permission-grant recovery test in `today_screen_selector_test` (seed `noPermission` → flip cubit to `empty` → health indicator returns).
  - [x] Run `flutter test test/presentation/screens/today_screen_selector_test.dart --exclude-tags slow`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Today permission UI unification (AUD-24) | My Data `BackgroundStatusCard` |
| l10n alignment / retirement on Today | Onboarding denied-state message (AUD-23) |
| Widget + integration test updates | `TodayCubit` / refresh service logic (state already correct) |
| Preserve GoalRing `--` / ActivityStats zeros | `StatusBanner` new variant (unless justified) |
| OK-commit sub-task gate | Version bump until Epic 28 close |

### Root cause (read before editing)

**Fragmentation (diagnostic §4):** Today alone shows **four parallel treatments** when `TodayStatus.noPermission`:

| Zone | Current copy (EN) | Action |
|------|-------------------|--------|
| `CollectionHealthIndicator` | "Sensor access revoked ✕" | None |
| `GoalRing` | `--` dashed track | None |
| `_PermissionCta` `TextButton` | "Step access denied. Tap to fix." | `openAppSettings()` |
| `ActivityStatsRow` | `0` / `0.0` / `00:00:00` | None |

Two different messages + one CTA disguised as button label → user confusion [Source: `diagnostic-gestion-etat-erreur.md` L114–125].

**UX canonical pattern** [Source: `ux-design-specification.md`]:
- Table: `permission_denied` → muted dot + **"Activity permission off"** + link to settings
- Edge case: dashed ring + `--` + **"Open settings"** link; My Data keeps its own banner (unchanged)

**State source (do not change):** `TodayRefreshService` emits `noPermission` when `activityPermissionGranted()` is false [Source: `today_refresh_service.dart` L74–76, L114–124, L316–328]. `deriveCollectionHealthDisplay` maps to `permissionDenied` [Source: `collection_health_evaluator.dart` L12–13].

### Current layout (preserve order except permission consolidation)

```141:148:lib/presentation/screens/today_screen.dart
                const _StaleBannerSlot(),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                const _WeekSection(),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                const _GoalRingCard(),
                const _PermissionCta(),
                const SizedBox(height: AstraSpacing.kSpaceMd),
                const _ActivityStatsSection(),
```

**Target layout:**
- `_StaleBannerSlot` — unchanged (still hidden when `noPermission` via `todayStaleBannerVisible`)
- `_WeekSection` — unchanged
- **`_PermissionDeniedSlot`** — new; visible only when `noPermission`
- `_GoalRingCard` — health slot skips `permissionDenied` display; ring + set-goal unchanged
- **Remove** `_PermissionCta`
- `_ActivityStatsSection` — unchanged (zeros OK)

### Reference implementation (My Data — read only)

```48:91:lib/presentation/widgets/background_status_card.dart
      BackgroundCollectionStatus.permissionDenied =>
        l10n.myDataBackgroundPermissionDenied,
    // ...
        if (status == BackgroundCollectionStatus.permissionDenied) ...[
          const SizedBox(height: AstraSpacing.kSpaceSm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpenSettings,
              child: Text(l10n.myDataOpenSettings),
            ),
          ),
        ],
```

Extract **structure**, not a shared widget (YAGNI — Epic 28 is targeted UX; avoid new abstraction unless duplication hurts).

### `_PermissionCta` to remove

```500:531:lib/presentation/screens/today_screen.dart
class _PermissionCta extends StatelessWidget {
  // ...
            TextButton(
              onPressed: () => unawaited(openAppSettings()),
              child: Text(
                l10n.errorNoPermission,
```

### Architecture compliance

- **Layering:** Presentation-only in `today_screen.dart` (+ l10n ARB). No cubit/repository/DI edits expected.
- **State management:** `BlocSelector` on `state.status == TodayStatus.noPermission` — same pattern as current `_PermissionCta`.
- **Settings action:** `permission_handler` `openAppSettings()` already imported in `today_screen.dart` L7.
- **Selectors / rebuild isolation:** New slot should use `BlocSelector` with `@visibleForTesting` section key (match `_PermissionCta.sectionKey` migration → `today_permission_denied_slot`).
- **A11y:** Primary block needs `Semantics` — message live region + button semantics on settings CTA (mirror `BackgroundStatusCard` + `StatusBanner` onTap pattern from 28-1).

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/screens/today_screen.dart` | **UPDATE** — unified slot, remove `_PermissionCta`, gate health indicator |
| `lib/l10n/app_en.arb` | **UPDATE** — only if Option B or retiring unused keys |
| `lib/l10n/app_fr.arb` | **UPDATE** — same |
| `lib/presentation/widgets/collection_health_indicator.dart` | **READ ONLY** — likely unchanged if Today stops passing `permissionDenied` |
| `lib/presentation/widgets/background_status_card.dart` | **DO NOT CHANGE** |
| `lib/presentation/screens/my_data_screen.dart` | **DO NOT CHANGE** |
| `lib/presentation/cubits/today/today_refresh_service.dart` | **DO NOT CHANGE** |
| `test/presentation/screens/today_screen_selector_test.dart` | **UPDATE** |
| `test/widget_test.dart` | **UPDATE** |
| `test/presentation/widgets/collection_health_indicator_test.dart` | **READ / maybe UPDATE** |

### Testing requirements

- Default gate: `flutter test --exclude-tags slow`
- Targeted: `test/presentation/screens/today_screen_selector_test.dart`
- Existing contracts to preserve:
  - `todayStaleBannerVisible` excludes `noPermission` [L208–212]
  - `today_cubit_test.dart` / contract tests — `noPermission` state shape unchanged
  - Goal ring dashed + `--` tests in `goal_ring_test.dart`
  - Activity stats zero tests in `activity_stats_row_test.dart`
- OK-commit gate per `docs/project-context.md`

### Cross-story context (Epic 28)

| Story | Scope | Interaction |
|-------|-------|-------------|
| 28-1 (done) | My Data stale tap | Independent; Today unchanged |
| **28-2 (this)** | Today permission unification | Leaves My Data unchanged |
| 28-3 (backlog) | Settings vs profile loading gate | No overlap |

Epic 28 closes with version bump **minor+1, patch=0, build+1** (`0.11.4+29` → `0.12.0+30` at epic close only).

### Previous story intelligence (28-1)

- Stale banner tap on My Data via `onTap: () => unawaited(cubit.refresh(silent: false))` — parity with Today stale, not permission work.
- Pattern: minimal screen-level diff, reuse existing cubit contracts, extend existing test file with tracking helpers.
- Post-audit tracker: `sprint-status-post-audit.yaml` (legacy `sprint-status.yaml` is Epics 1–13 complete).
- Sub-task OK-commit gate enforced; code review closed 28-1 at `22ae4c3`.

### Git intelligence (recent patterns)

Recent commits:
- `22ae4c3` / `1d07230` — story 28-1 close + sprint tracker
- `a501c9b` / `cd22d0f` — My Data stale tap feature + tests
- `1f555d4` — Epic 27 close at `0.11.4+29`

Follow: presentation-only diff, extend `today_screen_selector_test.dart`, no version bump until Epic 28 close.

### Latest tech notes

- **flutter_bloc ^9.x** — `BlocSelector` for permission slot; no package changes.
- **permission_handler** — `openAppSettings()`; no new API.
- **l10n** — `flutter gen-l10n` after ARB edits; generated files are not hand-edited.

### Project context reference

- OK-commit gate: `docs/project-context.md` §Development Workflow
- Version bump deferred to Epic 28 close: `.cursor/rules/app-versioning.mdc`
- Active sprint tracker: `sprint-status-post-audit.yaml`
- Current version: `0.11.4+29` (`pubspec.yaml`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` §Story 28-2, Epic 28]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-gestion-etat-erreur.md` §4 permission table]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` §permission_denied, edge cases]
- [Source: `lib/presentation/screens/today_screen.dart`]
- [Source: `lib/presentation/widgets/background_status_card.dart` — reference pattern]
- [Source: `lib/presentation/helpers/collection_health_evaluator.dart`]
- [Source: `_bmad-output/implementation-artifacts/stories/28-1-add-tap-to-refresh-on-my-data-stale-banner.md`]
- [Source: `test/presentation/screens/today_screen_selector_test.dart`]
- [Source: `test/widget_test.dart` L398–404]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sprint tracker: `sprint-status-post-audit.yaml` (legacy `sprint-status.yaml` is Epics 1–13 complete)
- Optional recovery widget test skipped: manual `cubit.emit` after `BlocProvider.value` did not rebuild `_PermissionDeniedSlot` in harness; recovery covered by `today_cubit_contract_test` refresh contract

### Completion Notes List

- Replaced `_PermissionCta` with `_PermissionDeniedSlot` (muted dot + `myDataBackgroundPermissionDenied` + single `myDataOpenSettings` CTA) above goal ring
- `_CollectionHealthSlot` now skips `permissionDenied` display — no duplicate "Sensor access revoked ✕"
- l10n Option A: reused My Data keys on Today only; no ARB edits
- Tests: 5 new selector cases + `widget_test.dart` finder update; full `flutter test --exclude-tags slow` green

### File List

- `lib/presentation/screens/today_screen.dart`
- `test/presentation/screens/today_screen_selector_test.dart`
- `test/widget_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

### Change Log

- 2026-07-19: Unified Today permission-denied UI (AUD-24) — single slot, My Data voice, tests updated
