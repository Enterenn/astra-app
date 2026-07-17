# Story 23.3: Introduce Live Region for Goal Ring, Activity Stats, and Health Status

Status: review

<!-- Post-audit Epic 23 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 23-3 · diagnostic-accessibilité-statique.md LiveRegion Majeur · AUD-27 · AUD-31 · UX-AUD-02 · UX-AUD-03 -->
<!-- Prerequisite: Story 23-2 — done (unit tile Semantics + ExcludeSemantics pattern) -->
<!-- Version bump: deferred to Epic 23 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **TalkBack/VoiceOver user**,
I want step count, activity stats, and collection health changes announced politely,
So that live updates are audible without flooding intermediate animation frames.

## Acceptance Criteria

1. **Given** `GoalRing` semantics container (`goal_ring.dart` L634–654)
   **When** committed step count changes (cubit `state.steps` / status transition)
   **Then** `Semantics(liveRegion: true, …)` announces the updated label politely (AUD-27, UX-AUD-02)
   **And** the label continues to use `_targetSteps` / existing `_semanticsLabel` helpers — **not** `_displayedSteps` or animation controller ticks
   **And** intermediate count-up / micro-tick animation frames do **not** mutate the live-region label (existing test: `semantics report target steps during count-up animation`)

2. **Given** `ActivityStatsRow` when kcal, distance, or walking duration values change
   **When** the row rebuilds with new committed metrics
   **Then** a parent `Semantics(liveRegion: true, label: …)` announces the summary (AUD-27)
   **And** decorative icons and inner `Text` nodes are under `excludeSemantics: true` so the summary is announced once
   **And** loading / no-permission / zero-day states use dedicated localized semantics copy (new ARB keys)

3. **Given** `CollectionHealthIndicator` (`collection_health_indicator.dart` L53–55)
   **When** `display` or `lastIngestionUtc` changes the status label
   **Then** existing `Semantics(label: …)` gains `liveRegion: true` (AUD-31)
   **And** `excludeSemantics: true` on children is preserved

4. **Given** `BackgroundStatusCard` primary status copy (`background_status_card.dart` L41–78)
   **When** `status` or `lastIngestionUtc` changes the dynamic text
   **Then** `Semantics(liveRegion: true, label: primaryCopy, excludeSemantics: true)` wraps the status row (AUD-31)
   **And** the permission-denied `TextButton` remains a separate actionable semantics node (not swallowed by parent `excludeSemantics`)
   **And** the status-dot `Semantics(label: myDataStatusIndicator)` is preserved or merged without duplicate announcements

5. **Given** `GoalCelebration` (`goal_celebration.dart` L134–136)
   **When** celebration fires once/day
   **Then** existing `liveRegion: true` + decorative `ExcludeSemantics` layers remain correct — **verify only, no regression** (UX-AUD-03)

6. **Given** widget tests for the touched widgets
   **When** this story ships
   **Then** each target widget has `liveRegion` semantics coverage (mirror `goal_celebration_test.dart` L68–87 pattern)
   **And** existing GoalRing / CollectionHealth semantics tests still pass
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-27 · AUD-31 · UX-AUD-02 · UX-AUD-03 · diagnostic-accessibilité-statique.md LiveRegion Majeur

**Depends on:** Story 23-2 — **done** (`ExcludeSemantics` on visual children inside labeled `Semantics`)

**Out of scope:** Chart `liveRegion` (Story 23-5), segmented control keyboard focus (23-4), week day pill goal-achieved semantics (23-6), settings notifications `MergeSemantics` (23-7), decorative icon `ExcludeSemantics` sweep (AUD-33), `AnimatedStepCount` standalone semantics (parent `GoalRing` owns live region), version bump until Epic 23 closes.

## Tasks / Subtasks

- [x] **Sub-task A — GoalRing liveRegion** (AC: #1)
  - [x] Add `liveRegion: true` to existing outer `Semantics` in `goal_ring.dart` `build` (~L634)
  - [x] Do **not** change `_semanticsLabel`, `_semanticsValue`, or tie label to `_displayedSteps`
  - [x] Do **not** add semantics to `AnimatedStepCount` (already inside `ExcludeSemantics`)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — ActivityStatsRow liveRegion + ARB** (AC: #2)
  - [x] Add ARB keys (EN + FR) e.g. `todayActivityStatsSemanticsLoading`, `todayActivityStatsSemanticsNoPermission`, `todayActivityStatsSemanticsSummary` with `{kcal}`, `{distance}`, `{distanceUnit}`, `{duration}` placeholders
  - [x] Add `_semanticsLabel(l10n, distanceUnit)` private helper mirroring `_formattedValues` branches
  - [x] Wrap `_buildRow` content in `Semantics(liveRegion: true, label: …, excludeSemantics: true)`
  - [x] Run `flutter gen-l10n`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — CollectionHealthIndicator liveRegion** (AC: #3)
  - [x] Add `liveRegion: true` to existing `Semantics` (~L53)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — BackgroundStatusCard liveRegion** (AC: #4)
  - [x] Wrap status `Row` (dot + `primaryCopy` text) in `Semantics(liveRegion: true, label: primaryCopy, excludeSemantics: true)`
  - [x] Keep `TextButton` for permission-denied **outside** the excluding parent (sibling in `Column`)
  - [x] Optionally fold dot into parent label (status text already includes meaning) — avoid double announcement with `myDataStatusIndicator`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — GoalCelebration verification** (AC: #5)
  - [x] Run existing `goal_celebration_test.dart` semantics test — confirm no code change needed
  - [x] Document pass in completion notes; skip commit if zero diff
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (only if fix required)

- [x] **Sub-task F — Semantics widget tests + regression** (AC: #6)
  - [x] `goal_ring_test.dart`: assert `liveRegion: true` on GoalRing semantics node (extend existing semantics group)
  - [x] `activity_stats_row_test.dart`: add semantics group — loading label, progress summary, `liveRegion` flag
  - [x] `collection_health_indicator_test.dart`: assert `liveRegion: true` on active state
  - [x] `background_status_card_test.dart`: assert `liveRegion` + label for healthy; harness test for stale → healthy transition updates semantics label
  - [x] `dart analyze` + `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `liveRegion: true` on GoalRing, ActivityStatsRow, CollectionHealthIndicator, BackgroundStatusCard | Chart bar selection liveRegion (23-5) |
| New ARB keys for ActivityStatsRow semantics summary | GoalRing label/key changes (already UX-AUD-02 compliant) |
| Semantics widget tests for liveRegion flag | Today Set goal button (23-1 — done) |
| GoalCelebration regression verify | Version bump (Epic 23 close) |

### Root cause (read before editing)

**Audit finding:** Only `goal_celebration.dart` uses `liveRegion`; dynamic Today core (step ring, activity stats, collection health) and My Data background status update silently for assistive tech [Source: diagnostic-accessibilité-statique.md L213–244, L343–364].

**Epic fold:** AUD-31 (CollectionHealthIndicator + BackgroundStatusCard) is intentionally bundled with AUD-27 in this story [Source: epics-post-audit.md scopeDecision L21].

**Animation vs announcement (critical):** `GoalRing` visual count uses `_displayedSteps` + `AnimatedStepCount`, but semantics label already reads `_targetSteps` from cubit state. Adding `liveRegion` on that node announces on **state commit**, not per animation frame. Do **not** refactor semantics to track `_displayedSteps` — would regress `goal_ring_test.dart` L491–524 and flood TalkBack during count-up.

### Current implementation (UPDATE — do not rewrite)

**GoalRing — semantics container (add `liveRegion` only):**

```634:654:lib/presentation/widgets/goal_ring.dart
          return Semantics(
            label: _semanticsLabel(l10n),
            value: _semanticsValue,
            increasedValue: _semanticsMaxValue,
            decreasedValue: _semanticsDecreasedValue,
            container: true,
            child: ExcludeSemantics(
              child: SizedBox(
                // AnimatedStepCount + ring visuals — no own semantics
```

**ActivityStatsRow — no semantics today:**

```48:86:lib/presentation/widgets/activity_stats_row.dart
  Widget _buildRow(BuildContext context, DistanceDisplayUnit distanceUnit) {
    // ... formats kcal, distance, duration
    return IntrinsicHeight(
      child: Row(
        // _StatColumn widgets — icons + Text only
```

**CollectionHealthIndicator — label exists, missing liveRegion:**

```53:55:lib/presentation/widgets/collection_health_indicator.dart
    return Semantics(
      label: label,
      excludeSemantics: true,
```

**BackgroundStatusCard — dynamic text without liveRegion:**

```52:78:lib/presentation/widgets/background_status_card.dart
    return Column(
      children: [
        Row(
          // dot Semantics + Text(primaryCopy) — no parent liveRegion
```

**GoalCelebration — reference implementation (READ ONLY):**

```134:136:lib/presentation/widgets/goal_celebration.dart
    return Semantics(
      liveRegion: true,
      label: l10n.todayGoalCelebrationLabel,
```

### Reference pattern — liveRegion + excludeSemantics

Follow `GoalCelebration`: parent `Semantics(liveRegion: true, label: …)` + `ExcludeSemantics` on decorative/duplicate visual children [Source: goal_celebration.dart L134–136, L181–187, L209–312].

Follow Story 23-1 / 23-2: when parent owns `label`, wrap child `Text` in `ExcludeSemantics` if not using `excludeSemantics: true` on parent [Source: today_screen.dart Set goal block, unit_option_picker_sheet.dart].

**Flutter API:** `Semantics.liveRegion: true` maps to platform **polite** live region (WCAG aria-live=polite equivalent). No package required [Source: Flutter SemanticsProperties].

### ActivityStatsRow semantics label design

Proposed ARB (adapt wording to match UX §4.3 tone — descriptive, English UI source):

```json
"todayActivityStatsSemanticsLoading": "Activity stats: loading",
"todayActivityStatsSemanticsNoPermission": "Activity stats: no permission",
"todayActivityStatsSemanticsSummary": "{kcal} kilocalories, {distance} {distanceUnit}, {duration} walking"
```

Use existing formatters (`formatKcal`, `formatDisplayDistanceValue`, `formatWalkingDuration`, distance unit labels from `todayStatsKmLabel` / `todayStatsMiLabel`) so semantics match visible values.

### Architecture compliance

- **Presentation-only** — no cubit, repository, schema, or screen orchestration edits [Source: architecture.md NFR-5]
- **Localization:** New user-facing strings via ARB + `flutter gen-l10n` [Source: project-context.md, Story 19-2]
- **OK commit gate:** One commit per sub-task; wait for Baptiste approval [Source: project-context.md § Development Workflow]
- **BlocSelector slices unchanged:** Today screen `_GoalRingViewModel` / `_ActivityStatsViewModel` / collection health VM — this story only touches leaf widgets

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/goal_ring.dart` | UPDATE — add `liveRegion: true` on outer Semantics |
| `lib/presentation/widgets/activity_stats_row.dart` | UPDATE — Semantics wrapper + `_semanticsLabel` helper |
| `lib/presentation/widgets/collection_health_indicator.dart` | UPDATE — add `liveRegion: true` |
| `lib/presentation/widgets/background_status_card.dart` | UPDATE — Semantics wrapper on status row |
| `lib/l10n/app_en.arb` | ADD ActivityStats semantics keys |
| `lib/l10n/app_fr.arb` | ADD French translations |
| `lib/l10n/app_localizations*.dart` | REGENERATE |
| `test/presentation/widgets/goal_ring_test.dart` | ADD liveRegion assertion |
| `test/presentation/widgets/activity_stats_row_test.dart` | ADD semantics test group |
| `test/presentation/widgets/collection_health_indicator_test.dart` | ADD liveRegion assertion |
| `test/presentation/widgets/background_status_card_test.dart` | ADD semantics + transition test |

**No changes expected:** `goal_celebration.dart`, `today_screen.dart`, `my_data_screen.dart`, `animated_step_count.dart`

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md § Test commands]
- Semantics tests: `tester.ensureSemantics()` before assertions [Source: goal_celebration_test.dart L68–87]
- LiveRegion assertion template:
  ```dart
  final node = tester.widget<Semantics>(
    find.bySemanticsLabel(expectedLabel),
  );
  expect(node.properties.liveRegion, isTrue);
  ```
- GoalRing: extend existing semantics group — do not break `semantics report target steps during count-up animation`
- BackgroundStatusCard: use `StatefulWidget` harness to pump stale then healthy — assert label updates
- Use `AppLocalizations` / `l10n_test_helper.dart` — no hardcoded English in new tests (except where existing tests already use English literals)

### Previous story intelligence

**From 23-2 (direct epic predecessor):**
- Parent `Semantics.label` is overridden by child `Text` without exclusion — use `excludeSemantics: true` on parent OR `ExcludeSemantics` per child
- Widget-level semantics tests belong next to the widget under test
- Generic widget API unchanged — fix at leaf widget only

**From 23-1:**
- GoalRing semantics intentionally deferred to this story — do not touch Set goal button
- `_semanticsLabel` / ARB keys for GoalRing already exist — only add `liveRegion`

**From 2-6 (GoalCelebration original):**
- `liveRegion: true` + `ExcludeSemantics` on glow/particles/micro-copy is the project reference
- Celebration announces once via outer Semantics; inner `GoalRing` is `ExcludeSemantics` during animation

### Git intelligence summary

Recent Epic 23 commits (23-1, 23-2):
- `feat(a11y): add semantics to unit option picker tiles`
- `feat(today): wire dedicated Set goal semantics label`
- `test(a11y): cover unit option picker semantics and selection`

No in-flight changes on `goal_ring.dart`, `activity_stats_row.dart`, `collection_health_indicator.dart`, or `background_status_card.dart`.

### Latest tech information

- **Flutter 3.x Semantics:** `liveRegion: bool` on `Semantics` widget — when `label`/`value` change, assistive tech announces politely. No `SemanticsService` manual calls needed for static label updates.
- **Anti-pattern:** Setting `liveRegion` on nodes whose label changes every animation frame (e.g. tying to `_onCountUpTick`) — causes announcement flood. This project already avoids that by using `_targetSteps` for GoalRing label.
- **Static audit disclaimer:** Runtime TalkBack/VoiceOver spot-check recommended before Epic 23 close [Source: epics-post-audit.md NFR-AUD-05].

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Version bump at Epic 23 close only: `sprint-status-post-audit.yaml` WORKFLOW NOTES
- UX semantics table: `_bmad-output/planning-artifacts/ux-design-specification.md` §4.3
- Sprint tracker for post-audit epics: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (not `sprint-status.yaml` — original epics 1–13 complete)

## Dev Agent Record

### Agent Model Used

claude-sonnet-5-thinking-high

### Debug Log References

- GoalCelebration test regression: dual `liveRegion` nodes after GoalRing change — fixed via `ExcludeSemantics` on null-controller path + test finder by semantics label

### Completion Notes List

- ✅ Sub-task A: `liveRegion: true` on GoalRing outer Semantics; label still uses `_targetSteps`
- ✅ Sub-task B: ActivityStatsRow semantics wrapper + 3 ARB keys (EN/FR) + `_semanticsLabel` helper
- ✅ Sub-task C: `liveRegion: true` on CollectionHealthIndicator
- ✅ Sub-task D: BackgroundStatusCard status row wrapped; dot semantics merged into parent label; TextButton kept outside
- ✅ Sub-task E: GoalCelebration verified — minor fix: ExcludeSemantics on pre-animation GoalRing; test finder updated
- ✅ Sub-task F: liveRegion assertions in 4 test files; `dart analyze` clean; `flutter test --exclude-tags slow` passes

### File List

- `lib/presentation/widgets/goal_ring.dart`
- `lib/presentation/widgets/activity_stats_row.dart`
- `lib/presentation/widgets/collection_health_indicator.dart`
- `lib/presentation/widgets/background_status_card.dart`
- `lib/presentation/widgets/goal_celebration.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_fr.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_fr.dart`
- `test/presentation/widgets/goal_ring_test.dart`
- `test/presentation/widgets/activity_stats_row_test.dart`
- `test/presentation/widgets/collection_health_indicator_test.dart`
- `test/presentation/widgets/background_status_card_test.dart`
- `test/presentation/widgets/goal_celebration_test.dart`

### Change Log

- 2026-07-17: Story 23-3 implemented — liveRegion on GoalRing, ActivityStatsRow, CollectionHealthIndicator, BackgroundStatusCard; semantics tests added; GoalCelebration regression fix
