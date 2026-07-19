# Story 28.3: Decouple Settings Theme, Locale, and Units from Profile Loading Gate

Status: done

<!-- Post-audit Epic 28 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 28-3 · diagnostic-etat-chargement.md §3 item 10 · AUD-43 -->
<!-- Prerequisite: Story 28-2 done; no dependency on Epic 28 close -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want to change theme, locale, and units even while Profile is still loading,
So that independent preferences are not blocked by profile fetch.

## Acceptance Criteria

1. **Given** `ProfileCubit` is in `ProfileStatus.loading`
   **When** Settings screen renders
   **Then** locale, units, theme mode, accent, and notification preference sections are visible and interactive (AUD-43)
   **And** only profile-dependent sections (if any) remain behind the profile loading gate

2. **Given** `ProfileStatus.error`
   **When** Settings is open
   **Then** preference sections remain usable (existing retry for profile error unchanged from Story 22-3)
   **And** preference persist failures still use SnackBar feedback (22-4 pattern)

3. **Given** user changes locale/units/theme while profile loads
   **When** persist succeeds
   **Then** cubits update immediately without waiting for profile ready

4. **Given** widget tests for Settings
   **When** this story ships
   **Then** tests cover interactive prefs during `ProfileStatus.loading`

**Covers:** AUD-43 · diagnostic-etat-chargement.md §3 item 10 · diagnostic-gestion-etat-erreur.md (Settings vs Profile gate)

**Depends on:** Story 28-2 — **done** · Story 22-3 retry panel — **done** · Story 22-4 theme SnackBars — **done**

**Out of scope:** Profile screen loading gate (stays full-screen spinner/error), unified `AppFailure` model, moving notification toggle to a new cubit, version bump until Epic 28 close, My Data / Today changes.

## Tasks / Subtasks

- [x] **Sub-task A — Remove Settings global Profile gate** (AC: #1, #2)
  - [x] Read fully before editing:
    - `lib/presentation/screens/settings_screen.dart` — `_SettingsScreenBody` L51–64 (global loading/error gate)
    - `lib/presentation/screens/profile_screen.dart` L33–41 — **contrast only; do not change Profile**
    - `lib/presentation/widgets/profile_load_error_panel.dart` — retry contract from 22-3
    - `_bmad-output/planning-artifacts/audits/diagnostic-etat-chargement.md` §3 item 10
  - [x] **Recommended implementation:**
    1. Replace `_SettingsScreenBody` gate with scroll-first layout: always render preference sections.
    2. When `ProfileStatus.error`: show `ProfileLoadErrorPanel` **inline at top of scroll** (not full-screen replacement); prefs scroll below.
    3. When `ProfileStatus.loading`: **no** full-screen `CircularProgressIndicator`; prefs visible immediately.
    4. When `ProfileStatus.ready`: unchanged scroll body (no error banner).
  - [x] Preserve `SecondaryScreenShell` title and bottom nav scroll padding.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Notification toggle during loading/error** (AC: #1, #2, #3)
  - [x] Read: `lib/presentation/cubits/profile_cubit.dart` — `setGoalNotificationsEnabled` L213–216 (`ready`-only guard)
  - [x] Relax guard so Settings can persist notification pref when `ProfileStatus.loading` or `ProfileStatus.error` (not only `ready`):
    - Compare current value via `state.goalNotificationsEnabled` when `ready`, else `await userSettings.getGoalNotificationsEnabled()` before early-return.
    - On success: `emit(state.copyWith(goalNotificationsEnabled: enabled))` without forcing `status: ready`.
    - Preserve permission request + SnackBar error path in `settings_screen.dart` (22-4 pattern).
  - [x] **Do not** change `updateDisplayName` / height / weight guards — Profile-only.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests** (AC: #2, #4)
  - [x] Update `test/presentation/screens/settings_screen_test.dart`:
    - Replace `shows loading indicator while profile is loading` — assert **no** full-screen spinner; assert Language/Units/Notifications/Theme cards visible.
    - Replace `shows error message when profile fails to load` — assert error panel **and** prefs visible (not mutually exclusive).
    - Update `retry tap → loading → error keeps retry button visible` — prefs remain visible alongside retry panel after failed retry.
    - Add: `ProfileStatus.loading` — tap Language row opens sheet (or verify `SettingsPreferenceRow` onTap wired); toggle notification switch persists (seed `goalNotificationsEnabled: false` in DB, tap switch, assert cubit/repo updated). **Skipped:** widget harness flaky on switch/sheet tap; visibility covered by updated tests + cubit guard in B.
    - Add: `ProfileStatus.error` — theme segment tap still works; notification switch toggle works. **Skipped:** same harness issue; error+visibility covered by updated tests.
  - [x] Optional: `profile_cubit_test.dart` — `setGoalNotificationsEnabled` succeeds during `loading` state. **Skipped** (optional; guard verified via implementation).
  - [x] Run `flutter test test/presentation/screens/settings_screen_test.dart --exclude-tags slow`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Settings decoupled from Profile loading/error gate (AUD-43) | Profile screen gate (unchanged) |
| Inline profile error + retry above prefs on Settings error | New shared `AppFailure` / StatusBanner refactor |
| Notification toggle during loading/error via ProfileCubit relax | Extract NotificationCubit |
| Widget test updates for loading/error + interactivity | Locale/units/theme cubit changes (already independent) |
| OK-commit sub-task gate | Version bump until Epic 28 close |

### Root cause (read before editing)

**Settings blocked by unrelated Profile fetch:**

Diagnostic loading §3 item 10: locale, units, and theme are **already in memory** via root `LocaleCubit`, `UnitsCubit`, `ThemeCubit`, but Settings wraps the entire body in `ProfileCubit` loading/error gates [Source: diagnostic-etat-chargement.md L90].

**Current dead-end gate:**

```51:64:lib/presentation/screens/settings_screen.dart
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        if (state.status == ProfileStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == ProfileStatus.error) {
          return ProfileLoadErrorPanel(loadError: state.loadError);
        }

        return const _SettingsScrollBody();
      },
    );
```

**Independent cubits (no Profile dependency):**

| Section | Cubit | Bootstrapped at app start |
|---------|-------|---------------------------|
| Language | `LocaleCubit` | Yes — `app_dependencies.dart` |
| Units | `UnitsCubit` | Yes |
| Theme mode + accent | `ThemeCubit` | Yes |
| Goal notifications | `ProfileCubit` | Loaded in `ProfileCubit.refresh()` |

Locale/units/theme persist via `UserSettingsRepository` with immediate emit — no Profile gate needed [Source: `locale_cubit.dart`, `units_cubit.dart`, `theme_cubit.dart`].

**Notification special case:** Toggle UI reads `profileState.goalNotificationsEnabled` and calls `profileCubit.setGoalNotificationsEnabled`, which currently returns `false` unless `ProfileStatus.ready` [Source: `profile_cubit.dart` L213–216]. This is the **only** cubit change expected.

**Story 22-3 regression note:** 22-3 intentionally kept Settings gated on error ("AUD-43 is out of scope"). This story **reverses that for Settings only** while preserving `ProfileLoadErrorPanel` retry behaviour inline.

### Target layout (Settings only)

```
SecondaryScreenShell(title: Settings)
└── SingleChildScrollView
    ├── [if ProfileStatus.error] ProfileLoadErrorPanel (inline, scrollable)
    ├── Language SectionCard (LocaleCubit)
    ├── Units SectionCard (UnitsCubit)
    ├── Notifications SectionCard (ProfileCubit switch)
    └── Theme SectionCard (ThemeCubit)
```

**Profile screen:** unchanged full-screen spinner / error [Source: `profile_screen.dart` L35–41].

### Recommended `_SettingsScreenBody` shape

```dart
// Pseudocode — adapt to existing padding/helpers in _SettingsScrollBody
return BlocBuilder<ProfileCubit, ProfileState>(
  builder: (context, profileState) {
    return SingleChildScrollView(
      padding: /* existing bottom nav padding */,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (profileState.status == ProfileStatus.error) ...[
            ProfileLoadErrorPanel(loadError: profileState.loadError),
            const SizedBox(height: AstraSpacing.kSpaceMd),
          ],
          const _SettingsPreferenceSections(), // extract from _SettingsScrollBody
        ],
      ),
    );
  },
);
```

Refactor `_SettingsScrollBody` → `_SettingsPreferenceSections` (or inline) to avoid duplicate scroll views. **One** `SingleChildScrollView` only.

### Notification guard relaxation (minimal cubit diff)

```dart
// profile_cubit.dart — setGoalNotificationsEnabled
if (isClosed) return false;
if (state.status != ProfileStatus.ready &&
    state.status != ProfileStatus.loading &&
    state.status != ProfileStatus.error) {
  return false;
}

final currentEnabled = state.status == ProfileStatus.ready
    ? state.goalNotificationsEnabled
    : await userSettings.getGoalNotificationsEnabled();
if (enabled == currentEnabled) return false;
// ... permission + persist unchanged ...
emit(state.copyWith(goalNotificationsEnabled: enabled));
```

When `refresh()` later completes to `ready`, it re-reads DB — consistent if persist succeeded.

### Architecture compliance

- **Layering:** Presentation screen restructure + minimal `ProfileCubit` guard change. No repository/DI/new cubits.
- **State management:** Keep existing cubits; Settings reads `LocaleCubit`, `UnitsCubit`, `ThemeCubit`, `ProfileCubit` as today.
- **Error feedback:** SnackBars for locale/units/theme/notification persist failures — unchanged 22-4 pattern [Source: `settings_screen.dart` L92–96, L116–119, L177–180].
- **Profile retry:** Reuse `ProfileLoadErrorPanel` + `ProfileCubit.refresh()` — do not invent new retry UI.
- **Selectors:** Not required — section-level `BlocBuilder` already isolates rebuilds.

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/screens/settings_screen.dart` | **UPDATE** — remove global gate; inline error panel; single scroll |
| `lib/presentation/cubits/profile_cubit.dart` | **UPDATE** — relax `setGoalNotificationsEnabled` guard |
| `lib/presentation/screens/profile_screen.dart` | **DO NOT CHANGE** |
| `lib/presentation/widgets/profile_load_error_panel.dart` | **READ** — reuse as-is (may need `Align`/`Padding` wrapper for inline scroll) |
| `test/presentation/screens/settings_screen_test.dart` | **UPDATE** — loading/error/interactivity assertions |
| `test/presentation/cubits/profile_cubit_test.dart` | **OPTIONAL UPDATE** — loading-state notification persist |

### Testing requirements

- Default gate: `flutter test --exclude-tags slow`
- Targeted: `test/presentation/screens/settings_screen_test.dart`
- Tests to **replace** (behaviour inversion):
  - L295–330: loading → prefs visible, no spinner-only screen
  - L332–369: error → error panel **and** prefs visible
  - L411–448: failed retry → retry panel **and** prefs visible
- Tests to **add**:
  - Loading: cards visible + at least one interactive action (language row tap or switch toggle)
  - Error: theme tap or switch still functional
- Preserve: card order test, theme/accent SnackBar failure tests, switch reflects ready-state preference
- Harness: reuse `_SeededProfileCubit`, `_RetryProfileCubit`, `_pumpSettingsScreen` from existing file

### Cross-story context (Epic 28)

| Story | Scope | Interaction |
|-------|-------|-------------|
| 28-1 (done) | My Data stale tap | Independent |
| 28-2 (done) | Today permission unification | Independent |
| **28-3 (this)** | Settings vs Profile gate | Closes AUD-43; last Epic 28 story |

Epic 28 closes with version bump **minor+1, patch=0, build+1** (`0.11.4+29` → `0.12.0+30` at epic close only).

### Previous story intelligence (28-2)

- Presentation-only diffs preferred; extend existing test file rather than new harness.
- Reuse existing l10n keys and widgets; YAGNI on new abstractions.
- Post-audit tracker: `sprint-status-post-audit.yaml` (legacy `sprint-status.yaml` is Epics 1–13 complete).
- OK-commit sub-task gate enforced; code review closed 28-2 at `2e2cb12`.

### Previous story intelligence (22-3 / 22-4)

- **22-3:** Introduced `ProfileLoadErrorPanel` with `retryButtonKey`; Settings error was full-screen — **this story moves panel inline without removing retry**.
- **22-4:** Theme/accent persist failures → `settingsThemeUpdateError` SnackBar; notification failures → `settingsNotificationUpdateError`. **Preserve exactly.**

### Git intelligence (recent patterns)

Recent commits:
- `2e2cb12` / `da9130a` — story 28-2 close + permission UX
- `22ae4c3` / `1d07230` — story 28-1 close
- `1f555d4` — Epic 27 close at `0.11.4+29`

Follow: minimal diff, update `settings_screen_test.dart`, optional small cubit guard, no version bump until Epic 28 close.

### Latest tech notes

- **flutter_bloc ^9.x** — `BlocBuilder` on `ProfileCubit` for error banner only; preference sections use existing cubit builders.
- **No package changes.**
- **`ProfileLoadErrorPanel`** uses `Center` — for inline scroll, wrap in `Padding` or adjust alignment so retry button is not vertically centered in full viewport (dev choice: `Align(alignment: Alignment.topCenter)` wrapper).

### Project context reference

- OK-commit gate: `docs/project-context.md` §Development Workflow
- Version bump deferred to Epic 28 close: `.cursor/rules/app-versioning.mdc`
- Active sprint tracker: `sprint-status-post-audit.yaml`
- Current version: `0.11.4+29` (`pubspec.yaml`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` §Story 28-3, Epic 28, AUD-43]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-etat-chargement.md` §3 item 10]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-gestion-etat-erreur.md` §2 Settings rows]
- [Source: `lib/presentation/screens/settings_screen.dart`]
- [Source: `lib/presentation/cubits/profile_cubit.dart`]
- [Source: `lib/presentation/screens/profile_screen.dart` — contrast, unchanged]
- [Source: `_bmad-output/implementation-artifacts/stories/22-3-add-retry-path-for-profile-and-settings-load-errors.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/28-2-unify-today-permission-denied-messaging-and-cta.md`]
- [Source: `test/presentation/screens/settings_screen_test.dart`]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Sub-task A (`38687e1`): Settings scroll-first layout; inline `ProfileLoadErrorPanel` on error; `_SettingsPreferenceSections` extracted.
- Sub-task B (`d0924a4`): `setGoalNotificationsEnabled` accepts `loading`/`error`; reads DB for current value when not `ready`.
- Sub-task C (`07a0b64`): Updated loading/error/retry widget tests; flaky interactive tap tests dropped per user decision.
- Code review: bootstrap notification pref on cubit init; preserve pref on refresh loading/error; idempotent toggle sync.
- `flutter test --exclude-tags slow` → 988 passed.

### File List

- `lib/presentation/screens/settings_screen.dart`
- `lib/presentation/cubits/profile_cubit.dart`
- `test/presentation/screens/settings_screen_test.dart`
- `test/presentation/cubits/profile_cubit_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`
- `pubspec.yaml`
- `README.md`

## Change Log

- 2026-07-19: Story 28-3 implemented — Settings prefs decoupled from Profile loading gate (AUD-43).
- 2026-07-19: Code review fixes — notification pref bootstrap/preserve; story closed; Epic 28 at `0.12.0+30`.
