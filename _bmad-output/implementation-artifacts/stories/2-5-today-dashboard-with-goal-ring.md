# Story 2.5: Today Dashboard with Goal Ring

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to see today's steps versus my daily goal in a clear ring dashboard,
So that I can check progress at a glance.

## Acceptance Criteria

1. **Given** step samples exist for today
   **When** the Today tab is opened
   **Then** `GoalRing` shows proportional arc, center count (Darker Grotesque), "steps today" and "goal N" labels (FR14, UX-DR5)
   **And** `SourceChip` displays "Phone sensor" (UX-DR7)

2. **Given** steps exceed the daily goal
   **When** the ring renders
   **Then** arc caps at 100% and center count shows actual total (overflow via number, not second lap)

3. **Given** no permission or no samples yet
   **When** Today loads
   **Then** empty/loading/no-permission states render per UX spec (dashed track, `--`, skeleton)

4. **Given** stale threshold exceeded (12h Android / 4h iOS)
   **When** Today is visible
   **Then** compact `StatusBanner` stale line appears linking user to My Data (UX-DR8 compact)

## Tasks / Subtasks

- [x] **Sub-task A — Stale threshold helper + ingestion hook wiring** (AC: #4, refresh contract)
  - [x] Add `lib/core/health/stale_data_evaluator.dart` — pure function: `DateTime? lastIngestionUtc`, `DateTime nowUtc`, `bool isIos` → `bool isStale`; thresholds **12h Android / 4h iOS** ([Source: `architecture.md` — iOS stale threshold]).
  - [x] Add unit tests in `test/core/health/stale_data_evaluator_test.dart`.
  - [x] Allow UI registration of `BackgroundCollector.onIngestionComplete` after construction (mutable setter or `registerOnIngestionComplete` — collector is built in `AppDependencies` before `TodayCubit` exists).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — TodayCubit + state** (AC: #1–#4 data layer)
  - [x] Add `lib/presentation/cubits/today_state.dart` — sealed or enum-driven `TodayStatus`: `loading`, `noPermission`, `empty`, `progress`, `goalMet`, `overflow`; fields: `steps`, `goal`, `isStale`, `lastIngestionUtc` optional.
  - [x] Add `lib/presentation/cubits/today_cubit.dart`:
    - [x] Inject `StepRepository`, `UserPreferencesRepository`, `TimeProvider`, activity permission checker (reuse `resolveActivityPermission` + `permission_handler` pattern from onboarding; injectable for tests).
    - [x] `Future<void> refresh()` — parallel `getTodaySteps()`, `getDailyStepGoal()`, `getLastIngestionUtc()`, permission status; compute stale via evaluator; map to state (overflow when `steps > goal`, goalMet when `steps >= goal` and not overflow semantics per UX).
    - [x] **Read-only** — never call `upsertIngestionBucket()`.
  - [x] Add `test/presentation/cubits/today_cubit_test.dart` — fake repos, permission granted/denied, stale boundary at 12h/4h, overflow vs goalMet.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — GoalRing widget** (AC: #1–#3)
  - [x] Add `lib/presentation/widgets/goal_ring.dart` — `CustomPainter` or `CircularProgressIndicator` styled to UX; diameter 220–260 via `LayoutBuilder`; 9dp stroke; track `accentPrimaryMuted`, arc `accentPrimary` round caps.
  - [x] States: loading skeleton pulse, empty `0`, progress 0–99%, goalMet/overflow full arc (100% cap), no-permission dashed track + center `--`.
  - [x] Center: `AstraTypography.displayFor`, sublabels Figtree caption "steps today" / "goal {formatted}".
  - [x] Semantics: `label: Steps today: N of goal`, `value`/`min`/`max` for progress ([Source: UX §4.3]).
  - [x] Add `test/presentation/widgets/goal_ring_test.dart` — pump widget states, semantics, overflow arc capped.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — SourceChip + StatusBanner (compact stale)** (AC: #1, #4)
  - [x] Add `lib/presentation/widgets/source_chip.dart` — pill "Phone sensor", `bgSubtle` / `textSecondary`, optional 14dp icon.
  - [x] Add `lib/presentation/widgets/status_banner.dart` — variant enum: `staleCompact` (Today), reserve `staleFull` stub for Epic 4.2; 3px left accent `statusStale`; copy: **"Steps may be delayed — see My Data"**; `onTap` navigates to My Data tab.
  - [x] Widget tests for compact stale visibility and tap callback.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — TodayScreen + AppScaffold integration** (AC: #1–#4, refresh triggers)
  - [x] Replace `TodayScreen` placeholder with `BlocProvider<TodayCubit>` + layout: optional compact stale banner → hero `GoalRing` (upper ~55%) → `SourceChip`.
  - [x] `AppScaffold`: hoist `TodayCubit` creation (needs `AppDependencies` via constructor or `InheritedWidget`); pass `onNavigateToMyData: () => setState(() => _selectedIndex = 2)`.
  - [x] Wire refresh triggers ([Source: `architecture.md` — Cubit refresh triggers]):
    - [x] Initial `refresh()` in cubit creation / screen init.
    - [x] `AppLifecycleState.resumed` → `todayCubit.refresh()` (in addition to existing `collectOnce()` in `AstraApp`).
    - [x] `backgroundCollector` ingestion callback → `todayCubit.refresh()` when buckets upserted.
    - [x] When Today tab selected (`_selectedIndex == 0`): `Timer.periodic(60s)` → `refresh()`; cancel when leaving tab or dispose.
  - [x] No-permission: optional text button / link → `openAppSettings()` via `permission_handler` (non-blocking).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task F — Verification** (AC: #1–#4)
  - [x] Run `flutter analyze` and `flutter test`.
  - [x] Manual: complete onboarding with permission → walk or inject steps → Today shows count + arc; deny permission path shows dashed `--`; force stale by mocking old `getLastIngestionUtc` in debug if needed.
  - [x] Review brief documents what is **deferred** to 2.6/2.7/4.2.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 2.5:**
- `TodayCubit` / `TodayState` — read path only.
- `GoalRing`, `SourceChip`, `StatusBanner` (compact stale variant).
- `TodayScreen` real dashboard layout per UX §2.3.
- Stale evaluation using `StepRepository.getLastIngestionUtc()` (delivered in 2.4).
- Cubit refresh: resume, ingestion complete, 60s poll while Today tab visible.
- Platform-honest stale thresholds (12h Android / 4h iOS).
- Accessibility semantics for ring (not celebration layers).

**Out of scope — defer to later stories:**
- `GoalCelebration` animation, `celebration_shown_date` preference → **Story 2.6** (ring may show **goalMet** visual at 100% arc without celebration layers).
- `NotificationService`, goal notification → **Story 2.7**.
- Full `BackgroundStatusCard`, OEM battery deep-links, `stale-full` My Data banner → **Story 4.2**.
- `HistoryCubit`, charts → **Epic 3**.
- Goal editor on My Data → **Story 4.6**.
- Dev data inject UI → **Story 3.1** (tests may seed DB via repository directly).

Do not over-implement. This story is the **first real Today surface** — not notifications, not celebration choreography.

### Pipeline position (Epic 2)

```text
BackgroundCollector.collectOnce()
        │
        v
StepRepository (getTodaySteps, getLastIngestionUtc)  ← read only
        │
        v
TodayCubit.refresh()  ← THIS STORY
        │
        v
GoalRing + SourceChip + StatusBanner (compact)
```

Stories 2.3–2.4 delivered persistence + collection. Story 2.5 surfaces totals to the user.

### Architecture contracts (must match exactly)

**Read path (D-03):**

| Caller | Method | Notes |
|--------|--------|-------|
| `TodayCubit` | `getTodaySteps()`, `getLastIngestionUtc()` | Read-only |
| `TodayCubit` | `UserPreferencesRepository.getDailyStepGoal()` | Read-only |
| UI / Cubits | **Must not** call `upsertIngestionBucket()` | Ingestion writes stay in `BackgroundCollector` |

**TodayCubit refresh triggers** ([Source: `architecture.md` — Cubit refresh triggers]):

| Trigger | Implementation hint |
|---------|---------------------|
| App resume | `AstraApp.didChangeAppLifecycleState` → `todayCubit.refresh()` |
| Ingestion complete | `BackgroundCollector.onIngestionComplete` → `todayCubit.refresh()` |
| Today tab visible | `Timer.periodic(60s)` while `_selectedIndex == 0` |
| Cold start / first open Today | `refresh()` in cubit init |

Foreground `collectOnce()` already runs in `AstraApp` — do not remove; cubit refresh runs **after** or in parallel (reads latest SQLite).

**Stale thresholds** ([Source: `architecture.md` — iOS stale threshold]):

| Platform | Threshold | Rationale |
|----------|-------------|-----------|
| Android | 12 hours since `getLastIngestionUtc()` | Avoid false stale after overnight sleep |
| iOS | 4 hours | Honest backfill model; no WM parity |

```dart
bool isStale({
  required DateTime? lastIngestionUtc,
  required DateTime nowUtc,
  required bool isIos,
}) {
  if (lastIngestionUtc == null) return false; // no samples yet → empty state, not stale banner
  final threshold = isIos ? const Duration(hours: 4) : const Duration(hours: 12);
  return nowUtc.difference(lastIngestionUtc) > threshold;
}
```

**Goal ring math:**

- `progress = (steps / goal).clamp(0.0, 1.0)` for arc sweep.
- **Overflow:** arc stays at 100%; center text shows actual `steps` (e.g. 10 847 vs goal 8 000).
- **goalMet** (2.5): same full arc as overflow visually; **no** `GoalCelebration` widget until 2.6.

**Time semantics:** `getTodaySteps()` already uses `LocalDayCalculator` per-row offsets (Story 2.3). Cubit must not reimplement day boundaries.

### Current code state

| Path | Current state | What 2.5 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/presentation/screens/today_screen.dart` | `TabPlaceholderBody` stub | Full dashboard + BlocProvider | SafeArea / theme tokens |
| `lib/presentation/screens/app_scaffold.dart` | Static `TodayScreen()` in list | Inject deps, TodayCubit, tab navigation callback | 3-tab shell, tokens, semantics on tabs |
| `lib/app.dart` | `ThemeCubit`, lifecycle `collectOnce()` | Add `todayCubit.refresh()` on resume | Onboarding gate, theme |
| `lib/core/di/app_dependencies.dart` | Exposes repos + `backgroundCollector` | No new deps required; wire ingestion callback from shell | Existing factories + tests |
| `lib/core/services/background_collector.dart` | `final onIngestionComplete` ctor-only | Mutable registration for UI cubit | WM isolate leaves null |
| `lib/data/repositories/step_repository.dart` | `getTodaySteps`, `getLastIngestionUtc` | Read-only from cubit | Upsert SQL unchanged |
| `lib/data/repositories/user_preferences_repository.dart` | `getDailyStepGoal()` | Read-only from cubit | Sole prefs writer |
| `lib/core/constants/astra_*.dart` | Design tokens ready | Use `context.astraColors`, `AstraTypography`, `AstraSpacing` | No ad-hoc hex in widgets |
| `lib/presentation/cubits/theme_cubit.dart` | Pattern reference | Mirror cubit + state file split | — |

`GoalRing`, `TodayCubit`, `SourceChip`, `StatusBanner`, `stale_data_evaluator` **do not exist yet**.

### Recommended file layout

```text
lib/core/health/stale_data_evaluator.dart              # NEW
lib/presentation/cubits/today_cubit.dart               # NEW
lib/presentation/cubits/today_state.dart               # NEW
lib/presentation/widgets/goal_ring.dart              # NEW
lib/presentation/widgets/source_chip.dart            # NEW
lib/presentation/widgets/status_banner.dart          # NEW
lib/presentation/screens/today_screen.dart           # UPDATE
lib/presentation/screens/app_scaffold.dart           # UPDATE
lib/app.dart                                         # UPDATE (resume → refresh)
lib/core/services/background_collector.dart          # UPDATE (UI callback registration)

test/core/health/stale_data_evaluator_test.dart       # NEW
test/presentation/cubits/today_cubit_test.dart         # NEW
test/presentation/widgets/goal_ring_test.dart          # NEW
test/presentation/widgets/status_banner_test.dart    # NEW (optional merge with goal_ring)
```

### TodayCubit sketch (suggested)

```dart
class TodayCubit extends Cubit<TodayState> {
  TodayCubit({
    required StepRepository stepRepository,
    required UserPreferencesRepository userPreferences,
    required TimeProvider clock,
    required Future<bool> Function() activityPermissionGranted,
  }) : _stepRepository = stepRepository,
       _userPreferences = userPreferences,
       _clock = clock,
       _activityPermissionGranted = activityPermissionGranted,
       super(const TodayState.loading());

  Future<void> refresh() async {
    emit(const TodayState.loading());
    final granted = await _activityPermissionGranted();
    if (!granted) {
      emit(const TodayState.noPermission());
      return;
    }
    final steps = await _stepRepository.getTodaySteps();
    final goal = await _userPreferences.getDailyStepGoal();
    final lastUtc = await _stepRepository.getLastIngestionUtc();
    final stale = isStaleData(
      lastIngestionUtc: lastUtc,
      nowUtc: _clock.nowUtc(),
      isIos: Platform.isIOS,
    );
    emit(TodayState.ready(
      steps: steps,
      goal: goal,
      isStale: stale,
      // map goalMet / overflow / empty from steps & goal
    ));
  }
}
```

Permission check: reuse `Permission.activityRecognition` / `Permission.sensors` via existing `resolveActivityPermission()` — inject status checker in tests.

### GoalRing layout (UX §2.3, D-3)

- Hero vertically centered in upper ~55% of body (below optional stale banner).
- `LayoutBuilder` → `size = constraints.maxWidth * 0.6` clamped `[220, 260]`.
- Loading: `CircularProgressIndicator` or muted arc with `AnimationController` pulse — respect `MediaQuery.disableAnimationsOf`.
- No permission: `CircularProgressIndicator` with dashed track via custom painter `dashPattern`.

### Step count formatting

UX expects locale-friendly grouping (e.g. `10 847`). **Do not add `intl` package** (not in locked deps). Add a tiny helper e.g. `lib/presentation/formatters/step_count_formatter.dart` with thin-space thousands separator sufficient for Phase 0.

### AppScaffold / navigation pattern

`AppScaffold` owns tab index. Pass into `TodayScreen`:

```dart
TodayScreen(
  deps: deps,
  onNavigateToMyData: () => setState(() => _selectedIndex = 2),
)
```

`StatusBanner` `onTap` invokes callback — no GoRouter (D-10).

### Wiring ingestion callback

`BackgroundCollector` is constructed in `AppDependencies.create()` without cubit reference. Minimal fix:

```dart
// background_collector.dart
VoidCallback? onIngestionComplete;
void registerOnIngestionComplete(VoidCallback? callback) {
  onIngestionComplete = callback;
}
```

In `AppScaffold.initState` after cubit exists:

```dart
deps.backgroundCollector.registerOnIngestionComplete(
  () => _todayCubit.refresh(),
);
```

Clear on dispose to avoid leaks.

### Architecture compliance

| Decision / invariant | Requirement for 2.5 |
|----------------------|---------------------|
| D-03 | Cubit reads repository only; no ingestion writes |
| D-09 | `flutter_bloc` Cubit — `TodayCubit` + `TodayState` |
| D-10 | Tab shell unchanged; no GoRouter |
| D-21 | Uses `getTodaySteps()` only; no `ChartDayAggregate` |
| D-25 | Stale uses `TimeProvider.nowUtc()` — no `DateTime.now()` in cubit |
| FR14 | Goal ring + labels + source chip |
| FR5 (partial) | Compact stale on Today only |
| NFR6 | English semantics labels |
| UX-DR5,7,8,19 | Ring, chip, compact stale, a11y |

### Anti-patterns

- Do not implement `GoalCelebration`, notification, or `celebration_shown_date` (2.6 / 2.7).
- Do not call `upsertIngestionBucket()` from UI layer.
- Do not use SQL `date(start_time, zone_offset)` or device TZ for today total.
- Do not add Riverpod, GoRouter, or global `Stream` state graphs.
- Do not duplicate `getTodaySteps()` logic in the widget — cubit owns data.
- Do not show full stale diagnostic copy on Today (My Data owns that in 4.2).
- Do not add coach copy ("You're crushing it!", streaks).
- Do not block the whole app when permission denied — ring shows `--` + settings link only.

### Testing requirements

| Area | Requirement |
|------|-------------|
| `stale_data_evaluator` | Boundary at 12h/4h; null last ingestion → not stale |
| `today_cubit` | Permission denied → `noPermission`; overflow steps > goal; stale flag |
| `goal_ring` | Arc cap 100%; semantics label; dashed no-permission |
| Widget/golden | Optional; prefer semantics + pump tests |
| Integration | Manual on device after 2.4 collection path |

Run: `flutter analyze`, `flutter test test/core/health/ test/presentation/cubits/today_cubit_test.dart test/presentation/widgets/goal_ring_test.dart`

### Previous story intelligence (2.4)

- `getLastIngestionUtc()` implemented — use for stale banner; **do not re-add query**.
- `BackgroundCollector.onIngestionComplete` fires only when `upsertedCount > 0` — Today refresh should tolerate zero writes on empty walks.
- Foreground `collectOnce()` on cold start + resume already in `AstraApp` — add cubit `refresh()` alongside, not instead.
- WorkManager isolate must keep `onIngestionComplete == null`.
- Physical WM spike may still be pending on real device — UI can show empty/0 until samples exist.
- Review gate: **one commit per sub-task** after Baptiste OK ([Source: `docs/project-context.md`]).

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `feat(steps): complete story 2.4 with ingestion baseline hardening` | Collector + baseline stable; build Today reads on top |
| `feat(collector): wire foreground backfill on cold start and resume` | Lifecycle pattern to extend with `TodayCubit.refresh()` |
| `feat(steps): add WorkManager step collection callback` | Ingestion callback hook exists — register from shell |

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| flutter_bloc | ^9.1.1 | `TodayCubit` / `BlocProvider` |
| permission_handler | (existing) | Activity permission status + `openAppSettings` |
| sqflite | (existing) | Via repositories only |

**No new pubspec dependencies** expected. Do not add `intl` for number formatting.

### Project context reference

- Review-before-commit workflow mandatory per sub-task.
- Baptiste is Flutter novice — review briefs should explain Cubit, `CustomPainter`, and `BlocProvider` placement.
- [Source: `docs/project-context.md`]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — State management, notifications table (read for boundaries)]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.3 Today, §2.2 StatusBanner, §4.3 accessibility]
- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 2.5 AC]
- [Source: `_bmad-output/implementation-artifacts/stories/2-4-background-collector-and-android-workmanager.md` — pipeline + `getLastIngestionUtc`]

### Latest technical notes

- **flutter_bloc 9.x:** `Cubit` + immutable state classes; use `copyWith` or sealed states; emit `loading` at start of `refresh()` to avoid stale UI during async read.
- **CustomPainter ring:** `canvas.drawArc` with `StrokeCap.round`; progress arc sweeps clockwise from top (`-pi/2` start); track full circle behind.
- **Timer periodic:** cancel in `dispose` and when tab index ≠ 0 to avoid battery drain on History/My Data.
- **Semantics progress:** `Semantics(value: steps.toDouble(), label: '...', increasedValue: goal.toDouble())` or `ExcludeSemantics` only for decorative layers (none in 2.5).

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- **Sub-task A (2026-06-02):** Added `isStaleData()` pure function with 12h Android / 4h iOS thresholds; null last ingestion → not stale. Refactored `BackgroundCollector` to use `registerOnIngestionComplete()` for post-construction UI wiring. 15 tests pass (7 stale evaluator + 8 collector).
- **Sub-task B (2026-06-02):** Added `TodayState` with 6 status variants and `TodayCubit.refresh()` read path (parallel repo reads, permission check, stale evaluation). 11 cubit tests cover permission, progress/goalMet/overflow, and stale boundaries.
- **Sub-task C (2026-06-02):** Added `GoalRing` widget with `GoalRingPainter` (CustomPainter), step count formatter, loading pulse, dashed no-permission track, semantics. 8 widget tests pass.
- **Sub-task D (2026-06-02):** Added `SourceChip` pill and `StatusBanner` with `staleCompact`/`staleFull` variants, 3px stale accent, tap callback. 5 widget tests pass.
- **Sub-task E (2026-06-02):** Integrated Today dashboard — `AppScaffold` hoists `TodayCubit`, wires refresh triggers (init, resume, ingestion, 60s poll), `TodayScreen` layout with GoalRing/SourceChip/stale banner. Updated app_scaffold + widget tests.
- **Sub-task F (2026-06-02):** `flutter analyze` clean; 144/144 tests pass. Story ready for review.
- **Code review (2026-06-02):** Silent refresh (no loading flash), coalesced refresh, resume collect-then-refresh, tab-return refresh, GoalRing/StatusBanner a11y, FittedBox for text scale, centered SourceChip. 150/150 tests pass.

### Deferred (out of scope 2.5)

- **2.6** — `GoalCelebration` animation, `celebration_shown_date` preference
- **2.7** — `NotificationService`, goal notification
- **4.2** — `StatusBanner.staleFull`, `BackgroundStatusCard`, OEM battery deep-links on My Data

### File List

- `lib/core/health/stale_data_evaluator.dart` (new)
- `test/core/health/stale_data_evaluator_test.dart` (new)
- `lib/core/services/background_collector.dart` (modified)
- `test/core/services/background_collector_test.dart` (modified)
- `lib/presentation/cubits/today_state.dart` (new)
- `lib/presentation/cubits/today_cubit.dart` (new)
- `test/presentation/cubits/today_cubit_test.dart` (new)
- `lib/presentation/formatters/step_count_formatter.dart` (new)
- `lib/presentation/widgets/goal_ring.dart` (new)
- `test/presentation/widgets/goal_ring_test.dart` (new)
- `lib/presentation/widgets/source_chip.dart` (new)
- `lib/presentation/widgets/status_banner.dart` (new)
- `test/presentation/widgets/status_banner_test.dart` (new)
- `lib/presentation/screens/today_screen.dart` (modified)
- `lib/presentation/screens/app_scaffold.dart` (modified)
- `lib/app.dart` (modified)
- `lib/presentation/cubits/today_cubit.dart` (modified — isClosed guard)
- `test/presentation/screens/app_scaffold_test.dart` (modified)
- `test/widget_test.dart` (modified)

## Story completion status

- Ultimate context engine analysis completed — comprehensive developer guide created
- Status: **done**
