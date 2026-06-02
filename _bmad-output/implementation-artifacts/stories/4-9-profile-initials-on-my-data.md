# Story 4.9: Profile Initials on My Data (Settings Entry)

Status: backlog

<!-- Depends on Story 4.8 display_name preference. English-only Phase 0. -->

## Story

As a **user**,
I want a simple profile affordance on My Data using my initials,
So that I have a recognizable entry point for preferences even without an account.

## Acceptance Criteria

1. **Given** a non-empty `display_name` in preferences
   **When** My Data profile header renders
   **Then** a circular badge (~40dp) shows one or two uppercase initials derived from the trimmed name (first letter; two letters = first + last word initial if space-separated)
   **And** tap scrolls to or focuses profile rows (display name, goal, appearance) per integrated My Data section order

2. **Given** no display name stored
   **When** My Data profile header renders
   **Then** a neutral placeholder icon is shown (not fake letters)
   **And** tap still reaches display-name edit affordance from Story 4.8

3. **Given** user updates display name on My Data
   **When** save succeeds
   **Then** initials badge updates on rebuild without cold start

4. **Given** UX tone and sovereignty model
   **When** profile header is shown
   **Then** no account CTA, no cloud sync copy, no photo picker

## Tasks / Subtasks

- [ ] **Sub-task A — Initials helper** (AC: #1, #3)
  - [ ] Pure function `String? initialsFromDisplayName(String? name)` in `lib/core/` or presentation util — test edge cases: single name, two words, unicode, trim
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task B — Profile header widget** (AC: #1–#4)
  - [ ] `ProfileInitialsBadge` widget — circle `bg.elevated`, Figtree label for letters, 48dp min touch target on tap target wrapper
  - [ ] Integrate at top of `MyDataScreen` once 4.2/4.7 section scaffold exists (or stub header if 4.8 row-only layout)
  - [ ] `Scrollable.ensureVisible` or section anchor for tap → profile block
  - [ ] Widget tests: initials vs placeholder
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task C — Verification**
  - [ ] `flutter analyze` + `flutter test`
  - [ ] Manual: name "Alex" → A; "Marie Dupont" → MD; clear name → placeholder
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Scope boundary

**In scope:** Visual initials badge + navigation affordance on My Data.

**Out of scope:** i18n, photos, accounts, Today greeting changes (4.8).

### Dependencies

- **Story 4.8** — `display_name` preference must exist.
- **Story 4.2 / 4.7** — full My Data layout recommended before polish; badge can land on minimal screen earlier.

**Suggested order:** After **4.8**, ideally after **4.7** (integrated My Data section order).

### References

- [Source: `epics.md` — Story 4.9]
- [Source: Story 4.8 — display name preference]

## Dev Agent Record

### Agent Model Used

_(filled on implementation)_

### Completion Notes

_(filled on implementation)_

### File List

_(filled on implementation)_
