# Story 24.3: Unify Loading Patterns for Week and Trends Surfaces

Status: done

<!-- Post-audit Epic 24 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 24-3 · diagnostic-etat-chargement.md §2.1 · AUD-36 · UX-AUD-01 · UX-AUD-04 -->
<!-- Version bump deferred to Epic 24 close (patch+1, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want Today week and Trends chart loading to use the same visual language for local SQLite waits,
So that loading does not feel like three different apps.

## Acceptance Criteria

1. **Given** Today week strip waits on local SQLite (`weekDays.isEmpty`)
   **When** loading UI shows in `_WeekSection`
   **Then** the `CircularProgressIndicator` is replaced by a **skeleton placeholder** in the same visual family as Trends charts (AUD-36, UX-AUD-01)
   **And** the placeholder is shape-faithful to the 7 day pills (not a generic spinner)
   **And** section height remains ~72 logical px (no layout jump vs current `SizedBox(height: 72)`)

2. **Given** Trends charts wait on local SQLite (`HistoryStatus.loading`)
   **When** `StepBarChart` or `TrendsMonthlyBarChart` renders loading UI
   **Then** both use a **shared skeleton widget** (not two private `_LoadingSkeleton` copies) (AUD-36)
   **And** bar color remains `colors.textMuted.withValues(alpha: 0.18)` with top radius 4 (unchanged visual token)
   **And** daily chart still shows **7** skeleton bars; monthly chart still shows **12**

3. **Given** the unified skeleton family
   **When** skeletons paint in light or dark theme
   **Then** all use `context.astraColors.textMuted @ 0.18α` — no hardcoded greys (NFR-AUD-08)
   **And** optional pulse animation follows `MediaQuery.disableAnimationsOf(context)` like `_GoalRingCenterSkeleton` (static bars when reduce-motion)

4. **Given** loading gates and cubit emit logic
   **When** this story ships
   **Then** `TodayCubit` / `HistoryCubit` loading flags and refresh semantics are **unchanged**
   **And** `PeriodToggle` remains interactive during History loading (deferred to 24-6)
   **And** GoalRing skeleton, ActivityStatsRow `—` placeholders, My Data section spinners remain unchanged

5. **Given** verification runs after unification
   **When** `dart analyze` and `flutter test --exclude-tags slow` execute
   **Then** both pass with zero regressions
   **And** `step_bar_chart_test.dart` and `trends_monthly_bar_chart_test.dart` still assert correct skeleton bar counts (7 / 12)
   **And** `screen_smoke_test.dart` week-loading case still passes
   **And** repo grep finds **zero** `CircularProgressIndicator` under `_WeekSection` loading branch

**Covers:** AUD-36 · UX-AUD-01 · UX-AUD-04 · diagnostic-etat-chargement.md §2.1

**Depends on:** Stories 24-1 and 24-2 done (no code dependency — design-system cleanup complete).

**Out of scope:** PeriodToggle loading gate (24-6), chart axis/layout token centralization (24-4), GoalRing / ActivityStatsRow loading patterns, My Data / Profile full-screen spinners, History cubit silent-refresh behavior, version bump until Epic 24 closes.

## Tasks / Subtasks

- [x] **Sub-task A — Extract shared skeleton widget(s)** (AC: #2, #3)
  - [x] Create `lib/presentation/widgets/astra_bar_loading_skeleton.dart` (or split `astra_chart_bar_skeleton.dart` + week variant if cleaner)
  - [x] Parameterize: `barCount`, `barHeights` (or height builder), `padding`, optional pulse
  - [x] Color: `colors.textMuted.withValues(alpha: 0.18 * opacityScale)`; top `Radius.circular(4)`; horizontal gap `AstraSpacing.kSpaceXs`
  - [x] Respect `MediaQuery.disableAnimationsOf(context)` for pulse (mirror goal_ring.dart L766 pattern)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Migrate Trends charts to shared skeleton** (AC: #2, #3)
  - [x] Replace private `_LoadingSkeleton` in `step_bar_chart.dart` (L93–125) with shared widget (7 bars, heights `48 + (i % 3) * 24`)
  - [x] Replace private `_LoadingSkeleton` in `trends_monthly_bar_chart.dart` (L103–135) with shared widget (12 bars, heights `40 + (i % 4) * 16`)
  - [x] Delete both private classes after migration
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Replace week strip spinner with skeleton** (AC: #1, #3)
  - [x] In `today_screen.dart` `_WeekSection` (L406–410): replace `CircularProgressIndicator` with 7-pill-shaped skeleton row matching `WeekProgressRow` spacing (`Expanded` + `kSpaceXs` gaps)
  - [x] Pill skeleton: rounded capsule (`kRadiusFull`), ~same vertical padding as `_DayPill` (`kSpaceSm` vertical); inner placeholder bars for weekday label + day number zones
  - [x] Keep `weekDays.isEmpty` gate and trophy hidden while loading (unchanged)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests + regression** (AC: #5)
  - [x] Add `test/presentation/widgets/astra_bar_loading_skeleton_test.dart` — bar count, color token, reduce-motion static path
  - [x] Update chart widget tests if skeleton widget type changes assertions
  - [x] Run `dart analyze` + targeted chart tests + `flutter test --exclude-tags slow`
  - [x] Grep `_WeekSection` / `today_screen.dart` — no `CircularProgressIndicator` in week loading branch
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Week strip: spinner → skeleton | GoalRing center skeleton refactor |
| Trends charts: dedupe `_LoadingSkeleton` | ActivityStatsRow `—` placeholders |
| Shared skeleton color/animation tokens | My Data 24px section spinners |
| Widget tests for shared skeleton | PeriodToggle disable (24-6) |
| Preserve cubit loading gates | Chart axis constants (24-4) |
| Green analyze + test suite | History silent vs non-silent refresh |

### Root cause (read before editing)

**Audit finding:** Local SQLite waits use four different visual patterns — Trends bar skeletons, Today week spinner, GoalRing pulsed rects, activity stats dashes [Source: diagnostic-etat-chargement.md §2.1 L43–48].

**Epic AC:** Unify week + Trends loading; My Data long I/O may keep spinners [Source: epics-post-audit.md Story 24-3 L860–863].

**UX NFRs:** UX-AUD-01 (fast-path + loading consistency), UX-AUD-04 (Trends skeleton coherence — PeriodToggle ghost fixed separately in 24-6).

### Current implementation (UPDATE — presentation widgets only)

**Today week — spinner (replace):**

```406:410:lib/presentation/screens/today_screen.dart
          child: vm.weekDays.isEmpty
              ? const SizedBox(
                  height: 72,
                  child: Center(child: CircularProgressIndicator()),
                )
              : WeekProgressRow(
```

Loading gate: `weekDays.isEmpty` (orthogonal to `TodayStatus.loading` during fast-path cold start). Trophy hidden when empty (L401–405).

**Trends daily chart — private skeleton (extract):**

```93:125:lib/presentation/widgets/step_bar_chart.dart
class _LoadingSkeleton extends StatelessWidget {
  // 7 bars, textMuted @ 0.18α, top radius 4
}
```

**Trends monthly chart — duplicate private skeleton (extract):**

```103:135:lib/presentation/widgets/trends_monthly_bar_chart.dart
class _LoadingSkeleton extends StatelessWidget {
  // 12 bars, same color/radius pattern, different heights
}
```

**Reference — GoalRing pulse pattern (reuse animation contract, do not refactor GoalRing):**

```840:892:lib/presentation/widgets/goal_ring.dart
class _GoalRingCenterSkeleton extends StatelessWidget {
  // textMuted @ 0.18 * opacityScale; pulseController null when reduceMotion
}
```

**Week pill layout reference (shape target for skeleton):**

```25:40:lib/presentation/widgets/week_progress_row.dart
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: AstraSpacing.kSpaceXs),
          Expanded(child: _DayPill(...)),
        ],
      ],
    );
```

### Recommended approach

| Decision | Rationale |
|----------|-----------|
| Shared bar skeleton for charts | Eliminates duplicate `_LoadingSkeleton` classes; single color/animation source |
| Week strip uses skeleton family, not spinner | AUD-36: same visual language for local SQLite waits |
| Week skeleton = 7 capsules, not 7 chart bars | Shape-faithful to `WeekProgressRow`; avoids misleading bar-chart metaphor |
| Optional pulse on all skeletons | Aligns with GoalRing; respect `disableAnimationsOf` |
| Do not touch cubits | Loading emit logic is correct; this is presentation-only |
| Keep chart bar counts/heights | Existing tests count skeleton `Container`s with top radius 4 |

### Architecture compliance

- **Presentation-only** refactor — no repository, schema, cubit, or DI changes [Source: architecture.md layering]
- **NFR-AUD-08:** use `AstraColors.textMuted` token only; no new hardcoded hex
- **OK commit gate** — one commit per sub-task; wait for Baptiste OK [Source: docs/project-context.md]
- **IndexedStack tab persistence:** week skeleton shows on cold start when `weekDays: []`; do not block title/scroll (unchanged)

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/astra_bar_loading_skeleton.dart` | **NEW** — shared skeleton builder |
| `lib/presentation/widgets/step_bar_chart.dart` | UPDATE — use shared skeleton, delete `_LoadingSkeleton` |
| `lib/presentation/widgets/trends_monthly_bar_chart.dart` | UPDATE — use shared skeleton, delete `_LoadingSkeleton` |
| `lib/presentation/screens/today_screen.dart` | UPDATE — `_WeekSection` loading branch |
| `test/presentation/widgets/astra_bar_loading_skeleton_test.dart` | **NEW** |
| `test/presentation/widgets/step_bar_chart_test.dart` | VERIFY / UPDATE assertions if needed |
| `test/presentation/widgets/trends_monthly_bar_chart_test.dart` | VERIFY / UPDATE assertions if needed |
| `test/presentation/screens/screen_smoke_test.dart` | VERIFY week loading smoke |

**No changes expected:** `today_cubit.dart`, `history_cubit.dart`, `history_screen.dart`, `period_toggle.dart`, `goal_ring.dart`, `pubspec.yaml`

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md]
- Targeted: `flutter test test/presentation/widgets/step_bar_chart_test.dart test/presentation/widgets/trends_monthly_bar_chart_test.dart test/presentation/widgets/astra_bar_loading_skeleton_test.dart`
- Chart loading tests locate skeleton bars via `BoxDecoration` top radius 4 — update finder if widget tree changes but **preserve bar count assertions** (7 / 12)
- Manual smoke (optional): cold start Today → week skeleton (not spinner); open Trends tab → chart skeleton unchanged feel; toggle dark theme

### Previous story intelligence

**From Story 24-2 (done 2026-07-18):**
- Constants-only cleanup; 914 tests green with `--exclude-tags slow`
- `borderPrimary` removed — skeletons must use `textMuted`, not border tokens
- OK commit gate pattern: 3 sub-tasks + verify sub-task

**From Story 24-1 (done 2026-07-17):**
- Shared widget extraction pattern: new file in `presentation/widgets/`, focused widget test, migrate call sites, delete duplicates
- Presentation-only; no cubit changes
- Quote from 24-1 out-of-scope: *"Loading/skeleton patterns (24-3)"* — now in scope here only

**From Epic 22 Story 22-2:**
- Today goal CTA disabled during loading — do not regress; week skeleton change must not re-enable any loading interactions removed there

### Git intelligence summary

Recent commits (Epic 24):
- `dcad3b0` — close story 24-2 after code review
- `696c2ad` / `ea733d8` — dead token removal in `astra_typography.dart` / `astra_colors.dart`
- `389d1e3` — close story 24-1; `SheetDragHandle` extraction

Commit style: `refactor(design-system): …`, `test(design-system): …`, `chore(review): …`

`today_screen.dart`, chart widgets not touched in 24-1/24-2 — clean surface for this story.

### Latest tech information

- **Flutter `withValues(alpha:)`:** Project already uses `Color.withValues` (not deprecated `withOpacity`) — continue in new skeleton widget.
- **Reduce motion:** Use `MediaQuery.disableAnimationsOf(context)` (project convention) — not raw platform accessibility flags.
- **No package upgrades** required.

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (**not** `sprint-status.yaml`)
- Audit source: `_bmad-output/planning-artifacts/audits/diagnostic-etat-chargement.md` §2.1
- Epic source: `_bmad-output/planning-artifacts/epics-post-audit.md` Story 24-3
- UX loading policy: UX-AUD-01, UX-AUD-04 in epics-post-audit.md NFR table
- Current app version: `0.11.0+25` (`pubspec.yaml`) — do not bump in this story

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5 (Cursor Agent)

### Debug Log References

- AnimatedBuilder reduce-motion test scoped to `AstraBarLoadingSkeleton` to avoid false positive from Flutter internal MaterialApp builders.

### Completion Notes List

- Sub-task A: `AstraBarLoadingSkeleton` StatefulWidget créé — `barCount`, `barHeightAt`, `padding`, pulse via `AnimationController.repeat(reverse:true)`, `unawaited`, `disableAnimationsOf` respecté.
- Sub-task B: `_LoadingSkeleton` supprimé de `step_bar_chart.dart` (7 bars) et `trends_monthly_bar_chart.dart` (12 bars) — migrés vers `AstraBarLoadingSkeleton`. 0 lint.
- Sub-task C: `CircularProgressIndicator` retiré de `_WeekSection` — remplacé par `_WeekLoadingSkeleton` (StatefulWidget, 7 capsules `kRadiusFull`, `textMuted @ 0.18`, pulse reduce-motion). Height 72px maintenue.
- Sub-task D: 4 nouveaux tests dans `astra_bar_loading_skeleton_test.dart`. Suite complète : 918 tests, 0 régression.
- AC #5 : `dart analyze` → 0 issues ; grep `CircularProgressIndicator` dans `today_screen.dart` → 0 résultats.

### File List

- `lib/presentation/widgets/astra_bar_loading_skeleton.dart` (NEW)
- `lib/presentation/widgets/step_bar_chart.dart` (UPDATED — shared skeleton, private class deleted)
- `lib/presentation/widgets/trends_monthly_bar_chart.dart` (UPDATED — shared skeleton, private class deleted)
- `lib/presentation/screens/today_screen.dart` (UPDATED — _WeekLoadingSkeleton added, CircularProgressIndicator removed)
- `test/presentation/widgets/astra_bar_loading_skeleton_test.dart` (NEW)

### Change Log

- 2026-07-18: Story context created — ready-for-dev (create-story workflow)
- 2026-07-18: Implementation complete — status set to review (4 commits: feat/refactor/refactor/test)
