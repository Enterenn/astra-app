# Story 22.5: Enable discarded_futures Lint and Fix Callback Sites

Status: review

<!-- Post-audit Epic 22 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 22-5 · diagnostic-convention-structure.md §2.2 · AUD-20 -->
<!-- Prerequisite: Story 22-4 — done (Settings theme/accent already use unawaited) -->
<!-- Version bump: deferred to Epic 22 close (patch+1, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want `discarded_futures` enabled with call sites fixed,
So that fire-and-forget Futures in UI callbacks are explicit and reviewable.

## Acceptance Criteria

1. **Given** `analysis_options.yaml`
   **When** this story ships
   **Then** `discarded_futures: true` is enabled under `linter.rules` (AUD-20)
   **And** `include: package:flutter_lints/flutter.yaml` is preserved

2. **Given** audit-listed UI callback boundaries (diagnostic §2.2)
   **When** lint is enabled
   **Then** each site uses explicit `unawaited(...)` or `await` (never bare `() => futureMethod()`):
   - `my_data_screen.dart` — error-banner retries: `exportAndShare`, `pickAndImport`, `confirmAndPurge`
   - `today_screen.dart` — stale compact banner `refresh(silent: false)`; permission CTA `openAppSettings()`
   - `settings_screen.dart` — unit/language picker `onTap` helpers (`_pickLanguage`, `_pickDistanceUnit`, `_pickWeightUnit`, `_pickHeightUnit`)
   - `onboarding_flow.dart` — `_onIntroContinue`, `_onHeightLetsGo`, `_onHeightSkip` in `onPrimary` / `onSecondary`
   - Theme/accent callbacks — **already fixed in 22-4**; verify still wrapped, do not regress

3. **Given** enabling `discarded_futures` project-wide
   **When** `dart analyze` runs
   **Then** zero `discarded_futures` infos across `lib/` (lint applies globally — not only audit-listed files)
   **And** known non-UI hits from pre-scan are fixed:
   - `today_cubit.dart:109` — `_liveStepsSubscription?.cancel()` in `attachLiveMonitor`
   - `app_scaffold.dart:223-226` — cubit `.close()` in `dispose`
   - `goal_ring.dart` — `AnimationController.forward()` / `reverse()` in sync methods
   - `goal_celebration.dart` — `AnimationController.forward()` cascade; `HapticFeedback.*` calls
   - `astra_horizontal_ruler.dart` — `AnimationController.forward()` cascades and micro-tick forwards

4. **Given** existing test suite
   **When** this story ships
   **Then** `flutter test --exclude-tags slow` passes
   **And** no behaviour change beyond making async intent explicit (no new features, no error-handling changes)

**Covers:** AUD-20 · diagnostic-convention-structure.md §2.2 · diagnostic-convention-structure.md Synthèse (Basse — Lint)

**Depends on:** Story 22-4 — **done** · project-wide `unawaited` pattern in cubits/coordinator — **already established**

**Out of scope:** `avoid_void_async` or other new lints, refactoring `MyDataCubit` FilePicker coupling (AUD-43 / Epic 25), renaming `ttl`/`vm` abbreviations (§2.4), version bump until Epic 22 closes, changing fire-and-forget semantics (only annotate, do not await UI callbacks that must stay non-blocking).

## Tasks / Subtasks

- [x] **Sub-task A — Enable lint + inventory** (AC: #1, #3)
  - [x] Add to `analysis_options.yaml`:
    ```yaml
    include: package:flutter_lints/flutter.yaml
    linter:
      rules:
        discarded_futures: true
    ```
  - [x] Run `dart analyze` — capture full list of `discarded_futures` hits
  - [x] Cross-check against audit §2.2 table; note any hits beyond listed files
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Fix audit-listed UI callback sites** (AC: #2)
  - [x] `my_data_screen.dart` — add `import 'dart:async';`; wrap three `StatusBanner.onTap` futures with `unawaited(...)`
  - [x] `today_screen.dart` — `unawaited(context.read<TodayCubit>().refresh(silent: false))` on stale banner; `unawaited(openAppSettings())` on permission CTA
  - [x] `settings_screen.dart` — wrap four `_pick*Unit` / `_pickLanguage` `onTap` with `unawaited(...)` (theme/accent already done — leave as-is)
  - [x] `onboarding_flow.dart` — add `import 'dart:async';`; wrap `_onIntroContinue`, `_onHeightLetsGo`, `_onHeightSkip` with `unawaited(...)`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Fix remaining lib violations** (AC: #3)
  - [x] `today_cubit.dart:109` — `unawaited(_liveStepsSubscription?.cancel())` before reassignment (mirror dispose at L1256)
  - [x] `app_scaffold.dart:223-226` — `unawaited(_todayCubit.close())` etc. in `dispose` (Bloc `close()` returns `Future<void>`)
  - [x] `goal_ring.dart` — wrap `forward()` / `reverse()` / `reset()` futures in sync tick/scheduling methods
  - [x] `goal_celebration.dart` — `unawaited` on `..forward()` cascade and `HapticFeedback.lightImpact()` / `mediumImpact()`
  - [x] `astra_horizontal_ruler.dart` — `unawaited` on animation `forward()` calls in `_runReadoutMicroTick`, `_pulseIndicator`, scroll settle paths
  - [x] Re-run `dart analyze` until zero `discarded_futures` in `lib/`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Verify** (AC: #4)
  - [x] `dart analyze` — clean (no `discarded_futures`)
  - [x] `flutter test --exclude-tags slow`
  - [x] Spot-check: My Data error-banner tap still retries; Today stale tap still refreshes; Settings pickers still open sheet; onboarding flow still advances
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Enable `discarded_futures` in `analysis_options.yaml` | Other linter rules (`avoid_void_async`, etc.) |
| `unawaited` / `await` at all analyze hits in `lib/` | `test/` violations unless analyze fails on them |
| Audit §2.2 UI callback sites | Epic 25 MyDataCubit FilePicker decoupling |
| Preserve existing fire-and-forget behaviour | Converting UI callbacks to `async` handlers |
| OK-commit gate per sub-task | Version bump (Epic 22 close) |

### Root cause (read before editing)

**Lint not enabled today** — `analysis_options.yaml` only includes `flutter_lints`; `discarded_futures` is opt-in [Source: diagnostic-convention-structure.md L128].

**Project already uses `unawaited` correctly in cubits/coordinator** — gaps are at **UI callback boundaries** where `() => futureMethod()` silently discards the Future [Source: diagnostic-convention-structure.md §2.2].

**22-4 already fixed Settings theme/accent** — do not duplicate or remove those wrappers:

```335:348:lib/presentation/screens/settings_screen.dart
                      onChanged: (preference) => unawaited(
                        _setThemePreference(context, preference: preference),
                      ),
// ...
                      onSelected: (preset) => unawaited(
                        _setAccentPreset(context, preset: preset),
                      ),
```

### Target fixes (audit §2.2 — current gaps)

**my_data_screen.dart** — error retry banners fire-and-forget cubit futures:

```136:161:lib/presentation/screens/my_data_screen.dart
              onTap: () => cubit.exportAndShare(),
// ...
              onTap: () => cubit.pickAndImport(...),
// ...
              onTap: () => cubit.confirmAndPurge(...),
```

Fix pattern: `onTap: () => unawaited(cubit.exportAndShare())`

**today_screen.dart** — stale banner refresh:

```373:374:lib/presentation/screens/today_screen.dart
              onTap: () =>
                  context.read<TodayCubit>().refresh(silent: false),
```

Also fix permission CTA at L446: `onPressed: () => unawaited(openAppSettings())` (`permission_handler` returns `Future<bool>`).

**settings_screen.dart** — picker rows still bare:

```233:286:lib/presentation/screens/settings_screen.dart
                  onTap: () => _pickLanguage(context, ...),
                  onTap: () => _pickDistanceUnit(context, ...),
                  onTap: () => _pickWeightUnit(context, ...),
                  onTap: () => _pickHeightUnit(context, ...),
```

Fix: `onTap: () => unawaited(_pickLanguage(context, ...))` — file already imports `dart:async`.

**onboarding_flow.dart** — async handlers in sync `VoidCallback` slots:

```98:122:lib/presentation/onboarding/onboarding_flow.dart
                  onPrimary: ... : () => _onIntroContinue(context),
// ...
                  onSecondary: () => _onHeightSkip(context),
                  onPrimary: () => _onHeightLetsGo(context),
```

`commitWeightAndContinue` / `skipWeight` / `previousStep` are `void` — no change needed.

### Non-UI violations (pre-scan — must fix for clean analyze)

| File | Line(s) | Issue | Fix |
|------|---------|-------|-----|
| `today_cubit.dart` | 109 | `cancel()` before resubscribe | `unawaited(_liveStepsSubscription!.cancel())` |
| `app_scaffold.dart` | 223-226 | `BlocBase.close()` in `dispose` | `unawaited(_todayCubit.close())` ×4 |
| `goal_ring.dart` | 420, 476-477, 520, 538 | `AnimationController.forward/reverse` | `unawaited(_countUpController!.forward())` etc. |
| `goal_celebration.dart` | 76, 94-96 | `..forward()` cascade; `HapticFeedback` | `unawaited(_sequenceController!.forward())`; `unawaited(HapticFeedback.lightImpact())` |
| `astra_horizontal_ruler.dart` | 185, 283, 304, 335, 396 | animation forwards in sync methods | `unawaited` on each `forward()` |

### Decision guide: `unawaited` vs `await`

| Context | Use |
|---------|-----|
| `onTap` / `onPressed` / `onChanged` in StatelessWidget | `unawaited` — must not block callback |
| `dispose()` / sync void lifecycle | `unawaited` — cannot make `dispose` async |
| Animation tick / timer callback | `unawaited` — same constraint |
| Private `async` helper called from UI | `unawaited(helper(...))` at call site OR make helper sync with internal unawaited |
| Method that is already `async` and owns the flow | `await` inside the async body |

**Do not** convert `onTap: () => unawaited(foo())` to `onTap: () async { await foo(); }` unless the widget API requires it — existing project convention prefers `unawaited` at boundary.

### Regression cautions

| Risk | Mitigation |
|------|------------|
| Double-wrap `unawaited` after 22-4 | Grep before edit; theme/accent already wrapped |
| `cancel()` without unawaited in attach vs dispose inconsistency | Align attach (L109) with dispose (L1256) pattern |
| Animation `forward()` behaviour change | `unawaited` does not alter execution — only satisfies lint |
| Missing `dart:async` import | Add only where `unawaited` newly introduced (`my_data_screen`, `onboarding_flow`; settings already has it) |
| Analyze hits in `test/` | Run full `dart analyze`; fix `lib/` first; extend to `test/` only if CI fails |

### Architecture compliance

- **Convention:** `unawaited()` from `dart:async` — project standard since Epic 2/6 [Source: `today_cubit.dart`, `app_lifecycle_coordinator.dart`, `app_scaffold.dart`].
- **Lint config:** top-level `linter.rules` override in `analysis_options.yaml` — standard Dart analyzer pattern.
- **No semantic change:** this story is annotation-only; error handling from 22-3/22-4 must not regress.
- **OK-commit gate:** one commit per sub-task [Source: docs/project-context.md].

### Project structure notes

| Path | Role |
|------|------|
| `analysis_options.yaml` | **UPDATE** — enable `discarded_futures` |
| `lib/presentation/screens/my_data_screen.dart` | **UPDATE** — 3 banner `onTap` |
| `lib/presentation/screens/today_screen.dart` | **UPDATE** — stale banner + permission CTA |
| `lib/presentation/screens/settings_screen.dart` | **UPDATE** — 4 picker `onTap` (verify theme/accent) |
| `lib/presentation/onboarding/onboarding_flow.dart` | **UPDATE** — 3 async callbacks |
| `lib/presentation/cubits/today_cubit.dart` | **UPDATE** — subscription cancel |
| `lib/presentation/screens/app_scaffold.dart` | **UPDATE** — cubit close in dispose |
| `lib/presentation/widgets/goal_ring.dart` | **UPDATE** — animation forwards |
| `lib/presentation/widgets/goal_celebration.dart` | **UPDATE** — animation + haptics |
| `lib/presentation/widgets/astra_horizontal_ruler.dart` | **UPDATE** — animation forwards |
| `lib/presentation/cubits/my_data_cubit.dart` | **READ** — confirm `Future<void>` on export/import/purge |
| `lib/presentation/screens/settings_screen.dart` | **READ** — 22-4 theme helpers as reference |

### Testing requirements

- **Lint gate:** `dart analyze` — zero `discarded_futures` (primary acceptance signal)
- **Regression:** `flutter test --exclude-tags slow`
- **No new tests required** — behaviour unchanged; existing widget/cubit tests cover flows
- **Manual spot-check (optional):** trigger My Data export error banner tap; Today stale banner tap; Settings language picker; onboarding intro continue

### Previous story intelligence (22-4)

- **Tracker:** `sprint-status-post-audit.yaml` — not legacy `sprint-status.yaml`
- **Theme/accent:** already `unawaited(_setThemePreference(...))` — story 22-5 completes the lint enablement deferred from 22-4 out-of-scope
- **Settings pattern:** `dart:async` already imported; mirror for `_pickLanguage` / unit pickers
- **Commit pattern:** `chore(lint):` or `fix(robustness):` with story reference
- **22-3/22-4:** Profile retry + theme SnackBar — do not touch those paths except adjacent picker `onTap` wrappers

### Git intelligence

Recent commits:
- `9b44c21` — close story 22-4 (theme error SnackBar + gen-l10n)
- `f021747` — settings SnackBar on theme failure
- `34e3e96` — ThemeCubit `Future<bool>` contract

Pattern: small scoped fixes + test pass; story ID in commit message; OK-commit per sub-task.

### Latest tech notes

- **Dart `discarded_futures` lint** — flags `Future`-returning calls in non-`async` functions; fix with `unawaited()` or `await` [Dart linter docs].
- **`unawaited` from `dart:async`** — marks intentional fire-and-forget; preferred over `// ignore: discarded_futures`
- **Flutter 3.x** — `AnimationController.forward()` returns `TickerFuture`; `HapticFeedback.*` returns `Future<void>` — both trigger lint
- **`BlocBase.close()`** — returns `Future<void>` since bloc 8.x — needs `unawaited` in sync `dispose`
- **No new packages**

### Project context reference

- OK-commit gate: sub-task → review brief → Baptiste OK → commit
- Tests: `flutter test --exclude-tags slow`
- Commit example: `chore(lint): enable discarded_futures and wrap UI callback futures (story 22-5)`
- Version bump: Epic 22 close only (`patch+1, build+1`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 22-5, AUD-20, Epic 22]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-convention-structure.md` — §2.2, §2.3, Synthèse]
- [Source: `_bmad-output/implementation-artifacts/stories/22-4-align-theme-preference-error-feedback-with-other-settings.md` — deferred lint, unawaited pattern]
- [Source: `_bmad-output/implementation-artifacts/stories/22-3-add-retry-path-for-profile-and-settings-load-errors.md` — tracker, OK-commit]
- [Source: `analysis_options.yaml`]
- [Source: `lib/presentation/screens/my_data_screen.dart`]
- [Source: `lib/presentation/screens/today_screen.dart`]
- [Source: `lib/presentation/onboarding/onboarding_flow.dart`]
- [Source: `lib/presentation/screens/settings_screen.dart`]
- [Source: `docs/project-context.md`]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5

### Debug Log References

### Completion Notes List

- Sub-task A: `discarded_futures: true` enabled in `analysis_options.yaml`; `dart analyze` revealed 18 hits (all in Sub-task C files; UI callback sites not flagged by lint but fixed per AC #2)
- Sub-task B: 7 UI callback boundaries wrapped with `unawaited` across 4 files; `dart:async` added to 3 files
- Sub-task C: 18 lint hits resolved — subscription cancel, 4 cubit close(), 5 animation forward/reverse, 2 haptic calls, 1 `..forward()` cascade, 3 scroll `animateTo.whenComplete` patterns; `dart:async` added to `astra_horizontal_ruler.dart`; `??= ...repeat()` cascades refactored to null-check + `unawaited`
- Sub-task D: `dart analyze lib/` → No issues found; `flutter test --exclude-tags slow` → 879 passed, 0 failed

### File List

- `analysis_options.yaml`
- `lib/presentation/screens/my_data_screen.dart`
- `lib/presentation/screens/today_screen.dart`
- `lib/presentation/screens/settings_screen.dart`
- `lib/presentation/onboarding/onboarding_flow.dart`
- `lib/presentation/cubits/today_cubit.dart`
- `lib/presentation/screens/app_scaffold.dart`
- `lib/presentation/widgets/goal_ring.dart`
- `lib/presentation/widgets/goal_celebration.dart`
- `lib/presentation/widgets/astra_horizontal_ruler.dart`

## Change Log

- 2026-07-17: Story context created (ready-for-dev) — ultimate context engine analysis completed
- 2026-07-17: Implemented all sub-tasks A–D; status → review
