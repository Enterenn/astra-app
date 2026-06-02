# Story 4.8: Local Display Name and Today Greeting

Status: backlog

<!-- User-confirmed 2026-06-03: English-only copy; i18n deferred. No coach personalization on celebration/notifications. -->

## Story

As a **user**,
I want to optionally tell the app my first name and see a calm greeting on Today,
So that the app feels personal without creating an account or sending data anywhere.

## Acceptance Criteria

1. **Given** first launch onboarding (trust → permissions → goal)
   **When** user reaches the new optional display-name step after goal
   **Then** copy asks what to call them (English only)
   **And** **Skip** completes onboarding without storing a name
   **And** non-empty trimmed input persists to `user_preferences` key `display_name` via `UserPreferencesRepository` only

2. **Given** no `display_name` stored (null/empty after trim)
   **When** Today loads
   **Then** no greeting line is rendered and ring layout is unchanged

3. **Given** a stored display name
   **When** Today loads
   **Then** one caption line above the goal ring shows **Hello, {name}** (Figtree caption, `text.secondary`, horizontal screen padding)
   **And** step totals are **not** repeated under the greeting (ring remains sole numeric hero)

4. **Given** My Data screen exists (minimal row acceptable before full Epic 4.2 layout)
   **When** user edits display name and saves
   **Then** preference persists immediately and Today greeting updates on next `TodayCubit.refresh()` without app restart

5. **Given** full health-data purge (Story 4.5)
   **When** purge completes
   **Then** `display_name` is retained with `daily_step_goal`, `theme_mode`, and onboarding flag (FR20 / D-11)

6. **Given** UX tone guardrails (UX §4.6)
   **When** greeting or onboarding copy is shown
   **Then** voice is calm and factual — no coach language, exclamation marks, or gamification

## Tasks / Subtasks

- [ ] **Sub-task A — Preference key + repository API** (AC: #1, #4, #5)
  - [ ] Add `kDisplayNameKey = 'display_name'` in `lib/core/constants/preference_keys.dart`
  - [ ] `UserPreferencesRepository`: `Future<String?> getDisplayName()`, `Future<void> setDisplayName(String? name)` — trim, treat empty as clear (delete key or store empty consistently)
  - [ ] Validate max length (e.g. 32 chars) before write; reject/control whitespace-only
  - [ ] Unit tests in `test/data/repositories/user_preferences_repository_test.dart`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task B — Onboarding display-name step** (AC: #1, #6)
  - [ ] Add `lib/presentation/onboarding/onboarding_display_name_page.dart` — single text field, primary Continue, ghost Skip
  - [ ] Extend `OnboardingCubit` / state: step count 4 (trust, permissions, goal, display name); goal page calls `nextStep` instead of completing; display name step calls `completeOnboarding(goal: …)` with optional name
  - [ ] Wire `IndexedStack` in `onboarding_flow.dart`; update progress indicator steps
  - [ ] English copy examples: title "What should we call you?", field label "First name", Skip "Continue without name"
  - [ ] Widget/cubit tests for skip vs save paths
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task C — Today greeting** (AC: #2, #3, #6)
  - [ ] `TodayCubit.refresh()` loads `getDisplayName()` into `TodayState` (nullable `displayName`)
  - [ ] `TodayScreen`: if `displayName != null`, padding-top caption **Hello, {displayName}** below compact stale banner, above ring flex area
  - [ ] Semantics: include greeting in Today screen label when present; do not duplicate step count in semantics value
  - [ ] Widget test: greeting visible/hidden; no second step count line
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task D — My Data edit row** (AC: #4)
  - [ ] Add display-name row on `MyDataScreen` (text field or tap-to-edit sheet mirroring goal editor pattern from 4.6)
  - [ ] Save → `setDisplayName` → `TodayCubit.refresh()` if cubit reachable (callback via scaffold or `AppDependencies`)
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task E — Purge contract + verification** (AC: #5)
  - [ ] When Story 4.5 purge service lands, assert `display_name` not cleared (test or document handoff in 4.5 if 4.8 lands first)
  - [ ] Run `flutter analyze` and `flutter test`
  - [ ] Manual: onboarding with name → Today shows Hello; skip → no line; edit on My Data → updates Today; purge (when available) keeps name
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope:**
- Local `display_name` preference (SQLite `user_preferences`, no migration required — key/value table)
- Optional onboarding step after goal
- Today **Hello, {name}** caption only (English hardcoded strings)
- My Data edit affordance (minimal row OK before full section layout)
- Purge retention contract

**Out of scope — defer:**
- **i18n** (`flutter_localizations`, `.arb`, locale resolution) — later epic/pass
- Personalized **GoalCelebration** or **notification** copy
- Step count subtitle under greeting (duplicates ring)
- **Profile initials avatar** on My Data → **Story 4.9**
- Account, cloud profile, photo upload

### Pipeline position (Epic 4)

```text
UserPreferencesRepository.display_name
        │
        ├── OnboardingDisplayNamePage (optional)
        ├── TodayCubit → TodayScreen greeting
        └── My Data edit row
        │
        v
Purge (4.5) must NOT delete display_name
```

**Suggested dev order:** 4.8 can start after Epic 1–3 (prefs + Today + onboarding exist). May run in parallel with 4.1–4.3; should complete **before or with** 4.5 so purge tests include `display_name`. My Data full layout (4.2, 4.7) can follow — 4.8 only needs a minimal edit row.

### Implementation hints

| Area | Guidance |
|------|----------|
| Key | `display_name` — same pattern as `daily_step_goal` string value |
| Onboarding order | Trust (0) → Permissions (1) → Goal (2) → Display name (3) → complete |
| Today layout | Greeting in top `Column` child before `Expanded` ring; use `AstraSpacing.kScreenHorizontalPadding` |
| Copy | Exact: `Hello, $name` — comma, no exclamation |
| Security | No logging of display name in production paths |

### References

- [Source: `epics.md` — Story 4.8]
- [Source: `architecture.md` — D-11 purge retains non-health prefs]
- [Source: `ux-design-specification.md` — §2.3 Today layout, §4.6 tone]
- [Source: Story 1.4 — `UserPreferencesRepository` sole writer]
- [Source: Story 2.5 — `TodayScreen` / `TodayCubit`]

## Dev Agent Record

### Agent Model Used

_(filled on implementation)_

### Completion Notes

_(filled on implementation)_

### File List

_(filled on implementation)_
