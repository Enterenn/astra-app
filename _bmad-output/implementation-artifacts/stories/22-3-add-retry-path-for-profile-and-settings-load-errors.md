# Story 22.3: Add Retry Path for Profile and Settings Load Errors

Status: done

<!-- Post-audit Epic 22 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 22-3 · diagnostic-gestion-etat-erreur.md §2 · AUD-18 -->
<!-- Prerequisite: Story 22-2 — done -->
<!-- Version bump: deferred to Epic 22 close (patch+1, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want a way to retry when Profile/Settings fail to load,
So that a transient error does not leave me stuck on static error text.

## Acceptance Criteria

1. **Given** `ProfileStatus.error` is shown on Profile or Settings
   **When** the error UI renders
   **Then** a visible retry control is available (AUD-18)
   **And** activating retry calls `ProfileCubit.refresh()` and returns to loading/ready

2. **Given** retry succeeds
   **When** refresh completes
   **Then** normal Profile/Settings content is shown

3. **Given** retry fails again
   **When** refresh completes with an error
   **Then** the error UI remains with retry still available

4. **Given** retry is in flight (`ProfileStatus.loading`)
   **When** the screen rebuilds
   **Then** the existing `CircularProgressIndicator` loading state is shown (no duplicate spinners)

5. **Given** existing Profile/Settings widget tests
   **When** this story ships
   **Then** new tests cover retry tap → loading → ready on both screens
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-18 · diagnostic-gestion-etat-erreur.md §2 (Profile/Settings rows) · diagnostic-etat-chargement.md (Profile/Settings error sans retry)

**Depends on:** Story 22-2 — **done** · `ProfileCubit.refresh()` — **already implemented**

**Out of scope:** Theme preference error feedback (Story 22-4 / AUD-19), `discarded_futures` lint (Story 22-5), decoupling Settings locale/units from Profile loading gate (AUD-43 / Epic 24), version bump until Epic 22 closes, new `ProfileLoadError` variants.

## Tasks / Subtasks

- [x] **Sub-task A — Shared error panel + wire both screens** (AC: #1, #2, #3, #4)
  - [x] Read fully: `profile_screen.dart` L39–52, `settings_screen.dart` L54–67 — identical error branches
  - [x] Read: `profile_cubit.dart` — `refresh()` / `_refreshImpl()` (error → `loading` → `ready`/`error`; `_refreshInFlight` dedup)
  - [x] Add l10n key `commonRetry` (EN: "Retry", FR: "Réessayer") in `app_en.arb` + `app_fr.arb`; run codegen (`flutter gen-l10n` or project equivalent)
  - [x] Create `lib/presentation/widgets/profile_load_error_panel.dart`:
    - Props: `ProfileLoadError? loadError`
    - Centered `Column(mainAxisSize: min)` with existing `profileLoadErrorMessage(l10n, loadError)` body text
    - `AstraButton` `secondary` labeled `l10n.commonRetry`, `onPressed` → `context.read<ProfileCubit>().refresh()` (use `unawaited` from `dart:async` to silence future until 22-5)
    - `Semantics(button: true, label: l10n.commonRetry)` on the button (minimal a11y — full polish deferred to Epic 23)
    - `@visibleForTesting static const retryButtonKey = Key('profile_load_retry')` for widget tests
  - [x] Replace inline error `Text` in **both** `profile_screen.dart` and `settings_screen.dart` with `ProfileLoadErrorPanel(loadError: state.loadError)`
  - [x] **Do not modify** `ProfileCubit` unless a gap is found — `refresh()` already emits `ProfileState.loading()` when `status != ready` (L55–57)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Widget tests for retry path** (AC: #1, #2, #3, #5)
  - [x] Add `_RetryProfileCubit` harness in test files (pattern from `my_data_screen_test.dart` `_RetryExportMyDataCubit`):
    - Tracks `refreshAttempts`
    - First `refresh()` from error: emit `loading`, then `ready` (or stay `error` on failure path)
  - [x] `profile_screen_test.dart`:
    - Error state shows retry button (`find.byKey(ProfileLoadErrorPanel.retryButtonKey)`)
    - Tap retry → `refreshAttempts == 1` → content appears (`profileSectionInformations` or equivalent ready marker)
    - Failure path: retry → still shows error + retry button
  - [x] `settings_screen_test.dart`:
    - Same retry assertions with `settingsNotifications` / `settingsUnits` as ready markers
  - [x] Keep existing error-message tests passing (generic + null `loadError` fallback)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Regression** (AC: #5)
  - [x] Run: `flutter test test/presentation/screens/profile_screen_test.dart`
  - [x] Run: `flutter test test/presentation/screens/settings_screen_test.dart`
  - [x] Run: `flutter test test/presentation/cubits/profile_cubit_test.dart`
  - [x] Run: `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

### Review Findings

- [x] [Review][Patch] French ARB missing `@commonRetry` metadata block [`lib/l10n/app_fr.arb`] — `app_en.arb` includes `@commonRetry` description; `app_fr.arb` has only the bare key, breaking ARB schema parity.
- [x] [Review][Patch] `refreshAttempts` not asserted in failure-path retry tests [`test/presentation/screens/profile_screen_test.dart`, `test/presentation/screens/settings_screen_test.dart`] — failure-path tests do not verify `refreshAttempts == 1`, leaving double-fire undetected.
- [x] [Review][Defer] `Semantics(button: true)` may produce redundant button node if `AstraButton` already declares button semantics internally — deferred to Epic 23 a11y polish; deferred, pre-existing
- [x] [Review][Defer] `_RetryProfileCubit` duplicated verbatim in `profile_screen_test.dart` and `settings_screen_test.dart` — acceptable for story scope; deferred to Epic 26 test infra refactor; deferred, pre-existing
- [x] [Review][Defer] `ProfileLoadErrorPanel` hard-coupled to `ProfileCubit` type — `context.read<ProfileCubit>()` breaks if screen ever migrates to a separate cubit; deferred to Epic 25 architecture work; deferred, pre-existing
- [x] [Review][Defer] `loadError == null` passthrough pre-existing — `profileLoadErrorMessage` already accepts nullable; no regression introduced; deferred, pre-existing
- [x] [Review][Defer] No isolated `ProfileLoadErrorPanel` widget test — screen-level coverage sufficient for story scope; deferred to Epic 26; deferred, pre-existing

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Visible retry on Profile + Settings `ProfileStatus.error` | ThemeCubit persist SnackBars (22-4) |
| Shared `ProfileLoadErrorPanel` widget | StatusBanner refactor for My Data |
| `commonRetry` l10n key | Rich semantic labels (Epic 23) |
| Widget tests for retry flow | Cubit unit test for refresh failure (optional; widget tests primary) |
| `unawaited(refresh())` at call site | Enable `discarded_futures` lint (22-5) |

### Root cause (read before editing)

**Static error trap — no recovery path:**

Diagnostic §2: `profile_screen.dart` and `settings_screen.dart` both render centered error text via `profileLoadErrorMessage` but **no retry action** [Source: diagnostic-gestion-etat-erreur.md L51–54].

Loading diagnostic cross-ref: Profile/Settings `error` state with message text, **sans bouton retry** [Source: diagnostic-etat-chargement.md].

**Current implementation — identical dead-end in both screens:**

```39:52:lib/presentation/screens/profile_screen.dart
        if (state.status == ProfileStatus.error) {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(
                AstraSpacing.kScreenHorizontalPadding,
              ),
              child: Text(
                profileLoadErrorMessage(l10n, state.loadError),
                style: AstraTypography.body(context),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
```

`settings_screen.dart` L54–67 is a copy of the same pattern.

**Cubit already supports retry — UI is the gap:**

```37:91:lib/presentation/cubits/profile_cubit.dart
  Future<void> refresh() async {
    // ... _refreshInFlight dedup ...
  }

  Future<void> _refreshImpl() async {
    if (state.status != ProfileStatus.ready) {
      emit(const ProfileState.loading());
    }
    try {
      // load displayName, height, weight, goalNotificationsEnabled
      emit(ProfileState.ready(...));
    } catch (...) {
      emit(ProfileState(status: ProfileStatus.error, loadError: ProfileLoadError.generic));
    }
  }
```

| State transition | On retry tap | UI expectation |
|------------------|--------------|----------------|
| `error` → tap retry | `emit(loading)` then fetch | `CircularProgressIndicator` (existing branch) |
| `error` → success | `emit(ready)` | Profile body / Settings scroll body |
| `error` → fail again | `emit(error)` | Error panel + retry still visible |
| Double tap while in flight | `_refreshInFlight` returns same Future | Single loading cycle |

### Target implementation (guidance)

**Prefer explicit button over tap-on-banner:**

My Data uses `StatusBanner` with `onTap` for inline action errors. Profile/Settings use **full-screen centered** error — an explicit `AstraButton` below the message is clearer and matches touch-target conventions (`kMinTouchTarget`).

**Shared widget sketch:**

```dart
class ProfileLoadErrorPanel extends StatelessWidget {
  const ProfileLoadErrorPanel({required this.loadError, super.key});

  @visibleForTesting
  static const retryButtonKey = Key('profile_load_retry');

  final ProfileLoadError? loadError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AstraSpacing.kScreenHorizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profileLoadErrorMessage(l10n, loadError),
              style: AstraTypography.body(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
            AstraButton(
              key: retryButtonKey,
              label: l10n.commonRetry,
              variant: AstraButtonVariant.secondary,
              onPressed: () => unawaited(context.read<ProfileCubit>().refresh()),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Do not use `StatusBanner` here** — it is designed for inline banners inside scroll content, not full-screen error replacement. Reuse its *pattern* (action on error) via explicit button.

### Regression cautions

| Risk | Mitigation |
|------|------------|
| `_SeededProfileCubit` overrides `refresh()` to re-emit seeded error | Add `_RetryProfileCubit` with stateful retry simulation; do not break existing error-display tests |
| Settings shows locale/units while profile errors | Unchanged — Settings still gates entire body on `ProfileCubit` (AUD-43 is out of scope) |
| Retry during ready state (edge) | `refresh()` from ready does **not** emit loading first (L55 guard) — only error/loading paths hit this UI |
| Missing l10n codegen | Run `flutter gen-l10n` after arb edits |
| French smoke | `migrated_strings_fr_test` unaffected; optional spot-check `commonRetry` |

### Architecture compliance

- **Error recovery pattern:** Align with My Data `StatusBanner` + `onTap` retry semantics, adapted for full-screen error [Source: diagnostic-gestion-etat-erreur.md L60].
- **Cubit boundary:** UI-only change — `ProfileCubit` refresh contract unchanged.
- **DRY:** Single widget for Profile + Settings identical branches.
- **OK-commit gate:** One commit per sub-task [Source: docs/project-context.md].

### Project structure notes

| Path | Role |
|------|------|
| `lib/presentation/widgets/profile_load_error_panel.dart` | **NEW** — shared error + retry UI |
| `lib/presentation/screens/profile_screen.dart` | **UPDATE** — use `ProfileLoadErrorPanel` |
| `lib/presentation/screens/settings_screen.dart` | **UPDATE** — use `ProfileLoadErrorPanel` |
| `lib/presentation/cubits/profile_cubit.dart` | **READ** — `refresh()` contract; no changes expected |
| `lib/presentation/l10n/profile_error_messages.dart` | **READ** — reuse `profileLoadErrorMessage` |
| `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb` | **UPDATE** — add `commonRetry` |
| `test/presentation/screens/profile_screen_test.dart` | **UPDATE** — retry widget tests |
| `test/presentation/screens/settings_screen_test.dart` | **UPDATE** — retry widget tests |
| `_bmad-output/planning-artifacts/audits/diagnostic-gestion-etat-erreur.md` | **READ** — §2 Profile/Settings rows |

### Testing requirements

- **Primary:** `flutter test test/presentation/screens/profile_screen_test.dart`
- **Primary:** `flutter test test/presentation/screens/settings_screen_test.dart`
- **Regression:** `flutter test test/presentation/cubits/profile_cubit_test.dart`
- **Full:** `flutter test --exclude-tags slow`

**Suggested `_RetryProfileCubit` pattern:**

```dart
class _RetryProfileCubit extends ProfileCubit {
  _RetryProfileCubit({...}) : super(...);

  var refreshAttempts = 0;
  var succeedOnRetry = true;

  @override
  Future<void> refresh() async {
    if (isClosed) return;
    refreshAttempts++;
    emit(const ProfileState.loading());
    await Future<void>.value();
    if (isClosed) return;
    emit(succeedOnRetry
        ? ProfileState.ready(goalNotificationsEnabled: false)
        : const ProfileState(status: ProfileStatus.error, loadError: ProfileLoadError.generic));
  }
}
```

**Suggested widget test flow:**

1. Seed error state → expect error text + retry button
2. `await tester.tap(find.byKey(ProfileLoadErrorPanel.retryButtonKey))`
3. `await tester.pump()` → expect `CircularProgressIndicator`
4. `await tester.pump()` → expect ready content marker
5. Variant: `succeedOnRetry = false` → error text + retry still present

### Previous story intelligence (22-2)

- **Tracker:** Use `sprint-status-post-audit.yaml`, not legacy `sprint-status.yaml`.
- **Scope discipline:** UI-only gate — no cubit refactor unless refresh gap found.
- **Test harness:** `_SeededProfileCubit` in profile/settings tests overrides `refresh()` — extend with retry-specific subclass, don't mutate seeded cubit for all tests.
- **Commit pattern:** `fix(profile-ui):` or `fix(robustness):` prefix; sub-task OK-commit gate.
- **22-2 done:** Today Set goal CTA loading gate — unrelated; do not touch `today_screen.dart`.

### Git intelligence

Recent commits:
- `3c6eac9` — `fix(today-ui): harden Set goal tap guard after async fetch (story 22-2)`
- `f05c811` — `fix(today-ui): disable Set goal CTA during Today loading (story 22-2)`
- `eca8d21` — `fix(live-pipeline): harden LiveStepMonitor dispose sequencing (story 22-1)`

Pattern: small targeted diff + focused widget tests; story reference in commit message.

### Latest tech notes

- **`unawaited` from `dart:async`** — use at retry call site until Story 22-5 enables `discarded_futures` lint project-wide.
- **`AstraButton` secondary** — matches settings-style actions; meets `kMinTouchTarget`.
- **No new packages.**

### Project context reference

- OK-commit gate: sub-task → review brief → Baptiste OK → commit
- Tests: `flutter test --exclude-tags slow`
- Commit example: `fix(profile-ui): add retry on Profile/Settings load error (story 22-3)`
- Version bump: Epic 22 close only (`patch+1, build+1`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 22-3, AUD-18, Epic 22]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-gestion-etat-erreur.md` — §2 Profile/Settings, §4 load failure table]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-etat-chargement.md` — Profile/Settings error sans retry]
- [Source: `_bmad-output/implementation-artifacts/stories/22-2-disable-goal-cta-during-today-loading-states.md` — epic patterns, test harness]
- [Source: `lib/presentation/screens/profile_screen.dart`]
- [Source: `lib/presentation/screens/settings_screen.dart`]
- [Source: `lib/presentation/cubits/profile_cubit.dart`]
- [Source: `lib/presentation/widgets/status_banner.dart` — My Data retry reference]
- [Source: `lib/presentation/screens/my_data_screen.dart` — StatusBanner onTap retry pattern]
- [Source: `docs/project-context.md`]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Sub-task A: Created `ProfileLoadErrorPanel` shared widget with `AstraButton secondary` + `retryButtonKey`; replaced inline error `Text` in both `profile_screen.dart` and `settings_screen.dart`; added `commonRetry` l10n key (EN/FR); ran `flutter gen-l10n`. No `ProfileCubit` changes needed — `refresh()` contract already correct.
- Sub-task B: Added `_RetryProfileCubit` harness (tracks `refreshAttempts`, `succeedOnRetry`) in both screen test files. 4 new retry tests (success + failure path × 2 screens). Existing error-display tests updated to also assert `retryButtonKey` presence. Note: intermediate loading state not checked in retry tests — `emit(loading)` + `emit(ready)` flush within the same microtask cycle before frame render; loading branch already covered by existing `_SeededProfileCubit(loading)` tests.
- Sub-task C: 875/875 tests pass (no regressions).

### File List

- `lib/l10n/app_en.arb` — added `commonRetry`
- `lib/l10n/app_fr.arb` — added `commonRetry`
- `lib/l10n/app_localizations.dart` — regenerated
- `lib/l10n/app_localizations_en.dart` — regenerated
- `lib/l10n/app_localizations_fr.dart` — regenerated
- `lib/presentation/widgets/profile_load_error_panel.dart` — NEW
- `lib/presentation/screens/profile_screen.dart` — error branch replaced
- `lib/presentation/screens/settings_screen.dart` — error branch replaced
- `test/presentation/screens/profile_screen_test.dart` — `_RetryProfileCubit` + retry tests
- `test/presentation/screens/settings_screen_test.dart` — `_RetryProfileCubit` + retry tests

## Change Log

- 2026-07-17: Story context created (ready-for-dev) — ultimate context engine analysis completed
- 2026-07-17: Implementation complete (review) — Sub-task A: `ProfileLoadErrorPanel` + l10n; Sub-task B: retry widget tests; Sub-task C: 875/875 regression clean
