# Story 24.6: Disable PeriodToggle During History Loading

Status: review

<!-- Post-audit Epic 24 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 24-6 · diagnostic-etat-chargement.md §3.6 · AUD-40 · UX-AUD-04 -->
<!-- Prerequisite: Stories 24-1 through 24-5 — done -->
<!-- Version bump deferred to Epic 24 close (patch+1, build+1) — last story in epic -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want the Trends period toggle disabled while History is loading,
So that I cannot change period on a ghost skeleton state.

## Acceptance Criteria

1. **Given** `HistoryStatus.loading` (initial Trends paint or any non-silent refresh path)
   **When** `PeriodToggle` is shown above chart skeletons
   **Then** segments are non-interactive (AUD-40, UX-AUD-04)
   **And** chrome remains visible (no hide/spinner swap)
   **And** disabled segments expose `Semantics.enabled: false` (mirror `ThemeSelector` / Story 22-2 pattern)

2. **Given** `HistoryStatus.ready` or `HistoryStatus.empty`
   **When** user taps a different period segment
   **Then** existing `HistoryCubit.selectPeriod` cache-only behaviour is unchanged (KPI-01 — no extra DB calls)
   **And** 7d / 30d / 12m chart switching, stats, and insights behave as before

3. **Given** `HistoryCubit.refresh(silent: true)` while Trends already shows ready data
   **When** refresh completes
   **Then** `HistoryStatus` stays non-loading throughout (silent refresh contract from Stories 21-7 / 24-3)
   **And** `PeriodToggle` stays enabled — no regression

4. **Given** defense-in-depth in cubit
   **When** `selectPeriod` is invoked while `state.status == HistoryStatus.loading`
   **Then** cubit is a no-op (no `copyWith(period: …)` ghost emit)
   **And** period cannot change until refresh resolves

5. **Given** verification runs after the gate ships
   **When** `dart analyze` and `flutter test --exclude-tags slow` execute
   **Then** both pass with zero regressions
   **And** new tests cover disabled + enabled widget paths and cubit no-op during loading

**Covers:** AUD-40 · UX-AUD-04 · diagnostic-etat-chargement.md §3.6 (ghost PeriodToggle)

**Depends on:** Stories 24-1 through 24-5 — **done** · Shared `AstraSegmentedControl.enabled` (Story 23-4) · Unified chart skeletons (Story 24-3)

**Out of scope:** Changing silent vs non-silent History refresh policy, chart skeleton visuals (24-3), chart layout tokens (24-4), History first-visit eager refresh (deferred audit item), version bump until Epic 24 closes, Epic 25+ architecture splits.

## Tasks / Subtasks

- [x] **Sub-task A — Wire `enabled` on PeriodToggle + History screen** (AC: #1, #3)
  - [x] Read fully: `period_toggle.dart`, `history_screen.dart`, `theme_selector.dart` (reference pattern)
  - [x] Add `enabled` param to `PeriodToggle` (default `true`) → pass through to `AstraSegmentedControl.enabled`
  - [x] In `history_screen.dart`: `enabled: state.status != HistoryStatus.loading`
  - [x] Do **not** hide toggle or swap to spinner during loading
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Harden `HistoryCubit.selectPeriod` during loading** (AC: #4)
  - [x] Read fully: `history_cubit.dart` `selectPeriod` (L71–93)
  - [x] Replace loading branch (`emit(state.copyWith(period: period))`) with early return (same guard as `period == state.period`)
  - [x] Preserve empty/ready branches unchanged
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests + regression** (AC: #2, #5)
  - [x] Extend `test/presentation/widgets/period_toggle_test.dart`:
    - `enabled: false` → tap does not fire `onChanged`
    - semantics `isEnabled: false` on each segment (copy pattern from `theme_selector_test.dart` L90–97)
  - [x] Add cubit test in `history_cubit_test.dart`: while status is `loading`, `selectPeriod` leaves period unchanged
  - [x] Run targeted tests + `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Disable PeriodToggle when `HistoryStatus.loading` | Change `refresh()` silent default or app_scaffold tab hooks |
| Cubit no-op guard during loading | New ARB keys |
| Widget + cubit tests | History screen full integration test (optional smoke only) |
| Reuse existing `AstraSegmentedControl.enabled` | Chart skeleton / bar count changes |
| Last Epic 24 story — bump version only at epic close | Epic 25 architecture work |

### Root cause (read before editing)

**Ghost interactive toggle during skeleton:**

While `HistoryStatus.loading`, `PeriodToggle` stays fully tappable. `HistoryCubit.selectPeriod` currently emits `state.copyWith(period: period)` without recomputing chart data — user can switch 7d ↔ 30d ↔ 12m labels while skeleton still paints, causing period/chart mismatch [Source: diagnostic-etat-chargement.md L86, L124 · epics-post-audit.md AUD-40 · UX-AUD-04].

**Story 24-3 explicitly deferred** this gate so skeleton unification could ship first [Source: 24-3 AC #4, out-of-scope list].

**Precedent:** Story 22-2 disabled Today Set goal CTA during loading via `AstraPressable(enabled: false)` + semantics + cubit defense-in-depth [Source: 22-2].

### Current implementation (UPDATE — read completely before editing)

**History screen — toggle always enabled:**

```56:59:lib/presentation/screens/history_screen.dart
                      PeriodToggle(
                        selected: state.period,
                        onChanged: context.read<HistoryCubit>().selectPeriod,
                      ),
```

**PeriodToggle — no `enabled` param yet:**

```7:38:lib/presentation/widgets/period_toggle.dart
class PeriodToggle extends StatelessWidget {
  const PeriodToggle({
    required this.selected,
    required this.onChanged,
    super.key,
  });
  // ...
    return AstraSegmentedControl<HistoryPeriod>(
      options: [ /* 7d / 30d / 12m */ ],
      selected: selected,
      onChanged: onChanged,
      semanticsHint: l10n.trendsChartRangeSemantics,
    );
```

**Reference — ThemeSelector already exposes `enabled`:**

```7:45:lib/presentation/widgets/theme_selector.dart
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });
  // ...
      enabled: enabled,
```

**AstraSegmentedControl — disabled behaviour built-in:**

```43:44:lib/presentation/widgets/astra_segmented_control.dart
  final bool enabled;
```

When `enabled: false`: segments get `Opacity(0.5)`, `InkWell(onTap: null)`, `Semantics(enabled: false)` [Source: `_SegmentTarget` L190–212].

**Cubit — loading branch causes ghost period change (fix in Sub-task B):**

```71:79:lib/presentation/cubits/history_cubit.dart
  void selectPeriod(HistoryPeriod period) {
    if (isClosed || period == state.period) {
      return;
    }

    if (state.status == HistoryStatus.loading) {
      emit(state.copyWith(period: period));
      return;
    }
```

**When loading actually occurs:**

| Trigger | Emits `HistoryStatus.loading`? |
|---------|-------------------------------|
| Cubit initial state | Yes (`super(const HistoryState.loading())`) |
| `refresh(silent: false)` | Yes (if not already loading) |
| `refresh()` / `refresh(silent: true)` (all production call sites today) | **No** — keeps ready/empty state |
| First Trends tab visit | Starts loading → `app_scaffold` calls `refresh()` (silent) → resolves to ready |

Production `app_scaffold.dart` always calls `_historyCubit.refresh()` with default `silent: true` (L253). Ghost toggle primarily affects **first paint** and any future non-silent refresh callers — still worth fixing per audit.

**Charts during loading (unchanged — 24-3):**

- `StepBarChart` / `TrendsMonthlyBarChart` render `AstraBarLoadingSkeleton` when `status == HistoryStatus.loading`
- Toggle stays visible above skeleton per UX-AUD-04

### Recommended approach

| Decision | Rationale |
|----------|-----------|
| Add `enabled` to `PeriodToggle`, wire from `history_screen` | Minimal diff; mirrors `ThemeSelector`; reuses 23-4 segmented control |
| Gate on `state.status != HistoryStatus.loading` only | Matches AC; silent refresh keeps toggle interactive |
| Remove cubit `copyWith(period)` during loading | Eliminates ghost state even if UI regresses |
| Do **not** add `IgnorePointer` wrapper | `AstraSegmentedControl.enabled` already handles tap + a11y |
| Do **not** change `_refreshImpl` silent semantics | Out of scope; 24-3 AC preserved |
| Tests mirror `theme_selector_test.dart` disabled cases | Established pattern; fast widget coverage |

### Architecture compliance

- **Presentation-only change** + one cubit guard — no schema, DI, or repository edits [Source: architecture layering]
- **NFR-AUD-07:** touch targets stay ≥48 dp when disabled (`ConstrainedBox minHeight: kMinTouchTarget` unchanged)
- **NFR-AUD-08:** no new hardcoded colors — disabled opacity from existing segmented control
- **KPI-01 / FR-28:** ready-state `selectPeriod` must remain cache-only — do not add fetches in this story
- **OK commit gate** — one commit per sub-task [Source: docs/project-context.md]

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/period_toggle.dart` | UPDATE — add `enabled` param |
| `lib/presentation/screens/history_screen.dart` | UPDATE — pass loading gate |
| `lib/presentation/cubits/history_cubit.dart` | UPDATE — no-op `selectPeriod` when loading |
| `test/presentation/widgets/period_toggle_test.dart` | UPDATE — disabled tap + semantics tests |
| `test/presentation/cubits/history_cubit_test.dart` | UPDATE — loading + selectPeriod no-op test |

**No changes expected:** `step_bar_chart.dart`, `trends_monthly_bar_chart.dart`, `app_scaffold.dart`, `astra_segmented_control.dart`, ARB files, `pubspec.yaml`

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md]
- Targeted:
  - `flutter test test/presentation/widgets/period_toggle_test.dart`
  - `flutter test test/presentation/cubits/history_cubit_test.dart`
- Cubit test setup hint: instantiate cubit (initial state loading), call `selectPeriod(HistoryPeriod.days30)` **before** `refresh()` completes, assert `cubit.state.period` still default and status still `loading`
- Manual smoke (optional): open Trends tab on cold start → try tapping period segments during skeleton → no thumb move; after load → toggle works; switch tabs away/back → silent refresh → toggle stays enabled during brief background refresh

### Previous story intelligence

**From Story 24-5 (done 2026-07-18):**
- Constants-only pattern: minimal surface, grep guards, full test suite (~939 tests)
- Explicitly listed PeriodToggle loading gate as **next story (24-6)**
- Sprint tracker: **`sprint-status-post-audit.yaml`**

**From Story 24-3 (done):**
- Unified `AstraBarLoadingSkeleton` for Trends charts; **intentionally left PeriodToggle interactive** until this story
- AC #4: cubit loading flags unchanged in 24-3 — **this story now owns the cubit loading guard fix**

**From Story 22-2 (done):**
- Disable interactive chrome during loading: UI gate + semantics + cubit defense-in-depth
- `@visibleForTesting` helpers optional — only add if cubit logic grows; simple early return needs no helper

**From Story 23-4 (done):**
- `AstraSegmentedControl` keyboard focus restored; disabled segments keep `Semantics(enabled: false)` — PeriodToggle inherits automatically

### Git intelligence summary

Recent commits (Epic 24):
- `1b8a55c` / `ce06797` — story 24-5 constants + tests
- `279eeff` — story 24-4 chart/typography tokens
- PeriodToggle / history loading gate **not touched** in 24-1–24-5 — clean focused surface

Commit style: `fix(design-system): …`, `test(design-system): …`, `chore(review): …`

### Latest tech information

- **Flutter 3.x / Dart 3.12:** no API changes — optional named param on widget
- **`AstraSegmentedControl.enabled`** stable since 23-4 — no package upgrades required
- **flutter_bloc ^9.1.1:** cubit early-return pattern unchanged

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`
- Audit source: `_bmad-output/planning-artifacts/audits/diagnostic-etat-chargement.md` §3.6
- Epic source: `_bmad-output/planning-artifacts/epics-post-audit.md` Story 24-6
- UX NFR: UX-AUD-04 in epics-post-audit.md NFR table
- Current app version: `0.11.0+25` (`pubspec.yaml`) — bump at **Epic 24 close** only (patch+1, build+1)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5

### Debug Log References

### Completion Notes List

- Sub-task A: Added `enabled` param (default `true`) to `PeriodToggle`, passed through to `AstraSegmentedControl.enabled`. Wired `enabled: state.status != HistoryStatus.loading` in `history_screen.dart`. Mirrors `ThemeSelector` pattern exactly.
- Sub-task B: Replaced ghost `emit(state.copyWith(period: period))` during loading with early return — cubit is now a strict no-op when `HistoryStatus.loading`. Empty/ready branches unchanged.
- Sub-task C: 2 widget tests (disabled tap + disabled semantics) + 1 cubit test (no-op during loading). 947/947 suite green.

### File List

- lib/presentation/widgets/period_toggle.dart
- lib/presentation/screens/history_screen.dart
- lib/presentation/cubits/history_cubit.dart
- test/presentation/widgets/period_toggle_test.dart
- test/presentation/cubits/history_cubit_test.dart

### Change Log

- 2026-07-18: Story context created — ready-for-dev (create-story workflow)
- 2026-07-18: Implemented all 3 sub-tasks — status → review
