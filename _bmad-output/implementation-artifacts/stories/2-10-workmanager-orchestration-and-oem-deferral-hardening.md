# Story 2.10: WorkManager Orchestration & OEM Deferral Hardening

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **builder**,
I want WorkManager and background health checks to be reliable on reference Android devices,
So that passive collection survives OEM battery policies.

## Acceptance Criteria

1. **Given** `BackgroundHealthCapabilityEvaluator` (new, per architecture D-23)
   **When** instantiated from `AppDependencies`
   **Then** it reports: activity permission, notification permission, battery optimization exemption status, FGS declaration presence — no scattered permission logic in screens

2. **Given** WorkManager periodic task registered
   **When** FGS is unavailable (permission revoked, OS killed service)
   **Then** WM still runs reconciliation as fallback orchestrator (architecture: WM ≠ realtime guarantee)

3. **Given** Samsung/Xiaomi/Huawei-style battery deferral detected
   **When** evaluator runs
   **Then** capability flag is exposed for future My Data UI (Epic 4.2) — **no user-facing copy in this story**

4. **Given** physical Android device
   **When** WM callback executes with `@pragma('vm:entry-point')`
   **Then** isolate-safe DB write succeeds; foreground backfill remains mandatory fallback if isolate init fails

## Tasks / Subtasks

- [x] **Sub-task A — Capability snapshot model + evaluator core** (AC: #1, #3)
  - [x] Add `lib/core/health/background_health_capability_snapshot.dart`:
    - [x] Immutable snapshot with at minimum: `activityRecognitionGranted`, `notificationGranted`, `batteryOptimizationExempt` (Android; `true` on iOS/no-op), `fgsHealthDeclared` (Android manifest static probe), `likelyOemBatteryDeferral` (derived flag), `manufacturer` (nullable string, Android only).
    - [x] Document field semantics in dartdoc — Epic 4.2 `BackgroundStatusCard` will consume this; **no UI strings in this story**.
  - [x] Add `lib/core/services/background_health_capability_evaluator.dart`:
    - [x] `Future<BackgroundHealthCapabilitySnapshot> evaluate()` — single entry point.
    - [x] Delegate activity check via existing `resolveActivityPermission()` + status (reuse logic from `AppDependencies.defaultActivityPermissionGranted`, do not duplicate platform branching).
    - [x] Delegate notification check via injected `NotificationService.hasNotificationPermission` or equivalent checker.
    - [x] `likelyOemBatteryDeferral`: `true` when Android + known aggressive OEM manufacturer (Samsung, Xiaomi, Huawei, Oppo, Vivo, OnePlus, Realme — case-insensitive match on `manufacturer`) **and** `batteryOptimizationExempt == false`.
  - [x] Unit tests with injected checkers returning deterministic statuses.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Android native capability probes** (AC: #1, #3)
  - [x] Extend Kotlin (prefer new `BackgroundHealthCapabilityChannel.kt` attached from `MainActivity`, or extend `HealthForegroundChannel` if cleaner):
    - [x] `isIgnoringBatteryOptimizations()` via `PowerManager.isIgnoringBatteryOptimizations(packageName)`.
    - [x] `getDeviceManufacturer()` → `Build.MANUFACTURER`.
  - [x] Dart side: injectable `PlatformCapabilityProbe` abstraction so tests never hit platform channel.
  - [x] **Manifest:** add `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` only if evaluator exposes a future settings opener (Epic 4.2); checking status via `PowerManager` does **not** require this permission — do **not** auto-request exemption in Story 2.10 (no user-facing flows).
  - [x] `fgsHealthDeclared`: set `true` when manifest contains `HealthStepForegroundService` + `foregroundServiceType="health"` — verify via existing `test/android/android_manifest_test.dart` and set compile-time constant or probe result documented in evaluator (runtime service-not-running ≠ declaration missing).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Wire evaluator into `AppDependencies` + dedupe permission gates** (AC: #1)
  - [x] Add `backgroundHealthCapabilityEvaluator` to `AppDependencies.create()` / `.test()`.
  - [x] Refactor **thin delegation** (do not rewrite onboarding/Today UX):
    - [x] `AppDependencies.activityPermissionGranted` → calls evaluator (or shared private helper used by both).
    - [x] `HealthForegroundServiceCoordinator` receives activity gate from deps/evaluator — remove parallel default implementations where they diverge.
    - [x] **Do not** add evaluator calls to every widget — screens keep injected checkers from deps; evaluator is the canonical implementation behind those checkers.
  - [x] Extend `test/core/di/app_dependencies_test.dart` — evaluator present and `evaluate()` callable in test factory.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — WorkManager orchestration hardening** (AC: #2, #4)
  - [x] **Keep** `registerStepCollectionWorkmanager()` in `main.dart` after `AppDependencies.create()` — WM registers on Android regardless of FGS state (D-04).
  - [x] Verify/harden WM path when FGS cannot run:
    - [x] Activity permission revoked → FGS start skipped (existing); WM task still executes `collectOnce` (may write 0 buckets — OK).
    - [x] Document in code comment near registration: WM = reconciliation fallback, not realtime guarantee.
  - [x] Optional hardening (implement if low-risk): pass `databasePath` in WM `inputData` from UI isolate via `path_provider` + `getDatabasesPath()` so callback never relies on implicit path in killed-process edge cases.
  - [x] Ensure `runStepCollectionWorkmanagerTask` continues returning `false` on bootstrap failure (WM retry) and foreground backfill in `AstraApp` remains unchanged (mandatory D-04).
  - [x] Add/extend test: WM registration occurs when `HealthForegroundServiceCoordinator` reports not running / activity denied (mocked).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Regression + integration tests** (AC: #1–#3)
  - [x] `test/core/services/background_health_capability_evaluator_test.dart` — all snapshot fields, OEM deferral matrix (Samsung + not exempt → true; Samsung + exempt → false; Google + not exempt → false).
  - [x] `test/core/services/workmanager_callback_test.dart` — keep green; add case for FGS-unavailable bootstrap (sources only `PhonePedometerSource`, no UI monitor).
  - [x] `test/app_health_fgs_lifecycle_test.dart` + `test/app_live_pipeline_lifecycle_test.dart` — full regression after deps refactor.
  - [x] Run `flutter analyze` + `flutter test`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task F — Physical device verification + docs** (AC: #4)
  - [ ] Manual WM spike on physical Android (reuse procedure in `docs/DEPENDENCIES.md` §WorkManager device verification):
    - [ ] Grant activity permission → background app → force WM job or wait 15 min → reopen → `getLastIngestionUtc()` updated OR foreground backfill recovers.
    - [ ] Revoke activity permission → confirm WM still scheduled (jobscheduler) and app does not crash; FGS does not start.
  - [ ] On OEM device (Oppo CPH2663 or equivalent): run `evaluator.evaluate()` via debug log or temporary dev-only print — confirm `manufacturer` + `likelyOemBatteryDeferral` plausible.
  - [x] Update `docs/DEPENDENCIES.md` — evaluator section, battery/OEM notes, WM fallback semantics.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 2.10:**
- `BackgroundHealthCapabilityEvaluator` + `BackgroundHealthCapabilitySnapshot` (architecture D-23)
- Android battery optimization + OEM manufacturer probes (Kotlin method channel)
- Centralize capability checks behind `AppDependencies` — reduce scattered permission logic
- WM orchestration verification/hardening as FGS fallback (D-04)
- Tests + physical WM spike + docs

**Out of scope — defer to other stories:**
- `BackgroundStatusCard`, stale copy, battery deep-link UX → **Story 4.2** (evaluator exposes flags only; optional `openBatteryOptimizationSettings()` stub OK if zero UI wiring)
- Today ring / live overlay changes → **Story 2.9 (done)** — do not regress
- FGS implementation changes beyond permission gating → **Story 2.8 (done)**
- Health Connect, iOS BGAppRefresh → unchanged
- Auto-prompting user to disable battery optimization → **Epic 4.2** (trust copy first)
- New pub dependency for OEM helpers (`battery_optimization_permission`, etc.) → **avoid**; use thin Kotlin channel on existing `MainActivity` pattern

This story completes Epic 2's passive pipeline **infrastructure** — not My Data UI.

### Pipeline position (Epic 2 — closing story)

```text
BackgroundHealthCapabilityEvaluator  ← THIS STORY (capability truth)
         │
         ├── gates FGS start (activity) — existing coordinator
         ├── flags OEM deferral for 4.2
         └── informs WM fallback expectations

FGS health (5 min) ──┐
WorkManager (15 min) ├──> BackgroundCollector ──> SQLite
Foreground backfill ─┘
Live overlay (UI) ── bonus only (2.9)
```

Approved sequence (sprint-change-proposal 2026-06-02): **2.9 → 2.10 → 2.8** — all prerequisites **done**.

### Architecture contracts (must match exactly)

**D-23 — BackgroundHealthCapabilityEvaluator:**

| Check | Android | iOS |
|-------|---------|-----|
| Activity recognition | `Permission.activityRecognition` / iOS sensors | Same resolver |
| Notification | `Permission.notification` | Same |
| Battery optimization exempt | `PowerManager.isIgnoringBatteryOptimizations` | Always `true` (N/A) |
| FGS health declared | Manifest service + type health | N/A (`false` or ignored) |
| OEM deferral risk | Derived flag | Always `false` |

**D-04 — Background orchestration (unchanged):**

| Layer | Role |
|-------|------|
| FGS health | Primary passive path when OS permits (2.8) |
| WorkManager | Orchestration + fallback when FGS unavailable — **not** realtime 5-min guarantee |
| Foreground backfill | Mandatory on every open — never remove |

**Write path (unchanged):** Only `BackgroundCollector` → `upsertIngestionBucket()`.

**Scattered logic to consolidate (grep before/after):**

| Location today | Action |
|----------------|--------|
| `AppDependencies.defaultActivityPermissionGranted` | Delegate to evaluator/shared helper |
| `TodayCubit._defaultActivityPermissionGranted` | Keep injectable; default = deps checker |
| `HealthForegroundServiceCoordinator._activityPermissionGranted` | Inject from deps |
| `NotificationService.hasNotificationPermission` | Evaluator calls this — do not duplicate notification API |

**Do not** move onboarding permission **request** flows into evaluator — evaluator **checks** only; `OnboardingCubit` keeps request UX.

### Capability snapshot sketch (suggested API)

```dart
class BackgroundHealthCapabilitySnapshot {
  const BackgroundHealthCapabilitySnapshot({
    required this.activityRecognitionGranted,
    required this.notificationGranted,
    required this.batteryOptimizationExempt,
    required this.fgsHealthDeclared,
    required this.likelyOemBatteryDeferral,
    this.manufacturer,
  });

  final bool activityRecognitionGranted;
  final bool notificationGranted;
  final bool batteryOptimizationExempt;
  final bool fgsHealthDeclared;
  final bool likelyOemBatteryDeferral;
  final String? manufacturer;
}

class BackgroundHealthCapabilityEvaluator {
  Future<BackgroundHealthCapabilitySnapshot> evaluate();
}
```

Epic 4.2 will map snapshot → `BackgroundStatusCard` states (`healthy` / `stale` / `ios_backfill` / `permission_denied`) combined with `isStaleData()` — **not in 2.10**.

### Current code state

| Path | Current state | What 2.10 changes | Must preserve |
|------|---------------|-------------------|---------------|
| `lib/core/services/background_health_capability_evaluator.dart` | **Does not exist** | Create | — |
| `lib/core/di/app_dependencies.dart` | No evaluator; duplicate activity checkers | Add evaluator; thin delegation | All existing deps fields |
| `lib/core/services/workmanager_callback.dart` | WM 0.9 API, shared bootstrap | Optional `inputData` path; document fallback | `@pragma('vm:entry-point')`; `createIsolateBackgroundCollector` |
| `lib/main.dart` | WM register after deps | Keep order; no iOS WM | Notification init timeout handling |
| `lib/core/services/health_foreground_service.dart` | Activity gate before FGS start | Inject shared checker | Lifecycle matrix (2.8) |
| `android/.../MainActivity.kt` | HealthForegroundChannel only | Add capability channel | Existing FGS channel |
| `android/.../AndroidManifest.xml` | FGS health service declared | Possibly `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` only if settings opener added | No INTERNET; no dataSync |
| `test/android/android_manifest_test.dart` | FGS health assertions | May assert REQUEST_IGNORE if added | Existing tests stay green |

### Recommended file layout

```text
lib/core/health/background_health_capability_snapshot.dart     # NEW
lib/core/services/background_health_capability_evaluator.dart  # NEW
lib/core/services/android_capability_probe.dart                # NEW (platform channel wrapper)
android/.../BackgroundHealthCapabilityChannel.kt               # NEW
lib/core/di/app_dependencies.dart                              # UPDATE
lib/core/services/health_foreground_service.dart                 # UPDATE (inject checker)
lib/main.dart                                                    # UPDATE (optional inputData)
lib/core/services/workmanager_callback.dart                    # UPDATE (optional inputData)
docs/DEPENDENCIES.md                                             # UPDATE

test/core/services/background_health_capability_evaluator_test.dart  # NEW
test/core/di/app_dependencies_test.dart                              # UPDATE
test/core/services/workmanager_callback_test.dart                    # UPDATE
```

### WM + FGS fallback matrix (verify in tests/docs)

| Condition | FGS | WM periodic | Foreground backfill |
|-----------|-----|-------------|---------------------|
| All capabilities OK, app backgrounded | Runs (2.8) | May still fire | On next open |
| Activity permission denied | Skipped | Still registered | On open |
| Battery optimized (OEM deferral) | May be killed | Deferred by OS | **Required** recovery path |
| Force-stop | None | None until relaunch | On open |
| Process alive, foreground | Stopped (2.8) | May fire | N/A |

WM overlap with FGS: `IngestionCollectionLock` + `BackgroundCollector._collectInFlight` already prevent corrupt concurrent writes (2.8 review) — regression only.

### Architecture compliance

| Decision / invariant | Requirement for 2.10 |
|----------------------|------------------------|
| D-04 | WM remains registered; FGS optional layer; backfill mandatory |
| D-06 | WM isolate DB unchanged — `openIsolateAstraDatabase()` |
| D-23 | Single evaluator class; no screen-level permission branching for capability **state** |
| D-25 | No `DateTime.now()` in evaluator (no clock needed for permission checks) |
| FR4 | Passive acceptance depends on WM+FGS+backfill stack — evaluator enables honest status later |
| FR6 | `fgsHealthDeclared` reflects manifest — already compliant from 2.8 |
| NFR3 | No new network/analytics packages |

### Anti-patterns

- Do not build `BackgroundStatusCard` or any user-facing OEM/battery copy in this story.
- Do not remove WorkManager registration when FGS is active.
- Do not remove foreground backfill from `AstraApp`.
- Do not add second production caller of `upsertIngestionBucket()`.
- Do not auto-request `ignoreBatteryOptimizations` on app launch (trust/onboarding owns permission **requests**).
- Do not add `device_info_plus` or OEM helper packages without Baptiste review + `docs/DEPENDENCIES.md` update.
- Do not break Story 2.9 cold-start sequence or FGS pause/resume lifecycle.
- Do not promise continuous 5-min WM cadence in docs — orchestration only.
- Do not scatter new `Permission.activityRecognition.status` calls in presentation layer after refactor.

### Testing requirements

| Area | Requirement |
|------|-------------|
| Evaluator unit tests | All snapshot fields; OEM matrix; iOS no-op defaults |
| Platform probe tests | Mock channel — battery exempt / not exempt |
| WM tests | Registration on Android; task bootstrap success/failure; optional inputData |
| DI test | Evaluator wired in `AppDependencies.test()` |
| Regression | FGS lifecycle, live pipeline, WM callback, background_collector lock tests green |
| Manifest | FGS health + no dataSync (existing) |
| Manual | WM spike on physical device; evaluator flags on OEM device |

Run: `flutter analyze`, `flutter test`  
On Windows: use `scripts/pre_test.ps1` if `sqlite3.dll` lock from parallel processes (Story 2.9).

### Previous story intelligence

**Story 2.9 (done):**
- Today Display Truth Model finalized; cold-start `refresh()` before live attach.
- `IngestionCollectionLock` for WM/FGS/UI overlap — do not weaken.
- Manual field tests deferred — not blocking 2.10.

**Story 2.8 (done):**
- FGS + WM coexist; shared `createIsolateBackgroundCollector`.
- Evaluator explicitly deferred to 2.10 — **implement now**, do not duplicate FGS logic.
- Physical FR4 walk test deferred — WM spike still required for AC #4.

**Story 2.4 (done):**
- WM 0.9 `executeTask` API; 15-min periodic minimum; isolate bootstrap pattern.
- `getLastIngestionUtc()` for stale detection — evaluator complements, does not replace.

**Story 2.7 (done):**
- Notification permission separate from activity — evaluator reports both independently.

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `974c7a3` | 2.9 done — Epic 2.10 is next; do not regress lifecycle tests |
| `ae568d2` / `0320ceb` | Cold-start/resume hardening — preserve `app.dart` sequences |
| `e28ff58` | 2.8 done — FGS channel pattern for new capability channel |
| `fe0be77` | Ingestion lock + FGS tests — keep green after DI changes |

### Library / framework requirements

| Package | Version | Usage in 2.10 |
|---------|---------|-----------------|
| `permission_handler` | ^12.0.1 | Activity + notification status; optional future `Permission.ignoreBatteryOptimizations` for 4.2 settings opener |
| `workmanager` | ^0.9.0+3 | Keep 0.9 `executeTask` — no API downgrade |
| `sqflite` | ^2.4.2+1 | Unchanged WM isolate factory |

**New dependencies:** None expected — Kotlin `PowerManager` + `Build.MANUFACTURER` via method channel.

### Latest technical information

- **permission_handler 12.x:** `Permission.ignoreBatteryOptimizations.status` reads system setting without dialog — suitable for evaluator **check**; `.request()` opens system UI (defer to Epic 4.2).
- **Battery optimization check:** Prefer native `PowerManager.isIgnoringBatteryOptimizations()` over Dart-only heuristics — OEM ROMs return unreliable statuses through generic APIs.
- **OEM deferral:** Samsung/Xiaomi/Huawei/Oppo/Vivo/OnePlus/Realme use aggressive task killers — architecture expects honest stale UI later, not silent failure. `likelyOemBatteryDeferral` is a **hint flag**, not proof WM is deferred.
- **workmanager 0.9.0+3:** Periodic minimum 15 minutes unchanged; passing `inputData` with `databasePath` is supported and improves killed-process reliability.
- **Android 14+ FGS:** Already declared in manifest (2.8); evaluator `fgsHealthDeclared` validates static declaration, not runtime `isHealthCollectionServiceRunning()`.

### Project context reference

- Review-before-commit per sub-task ([Source: `docs/project-context.md`]).
- Baptiste is Flutter novice — explain evaluator vs permission **request**, method channels, and OEM battery policies in review briefs.
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-04, D-23, Platform Architecture, AppDependencies]
- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 2.10 AC]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-02.md` — evaluator scope, sequence]
- [Source: `_bmad-output/planning-artifacts/background-trust-and-movement-validation.md` — OEM lag expectations]
- [Source: `_bmad-output/implementation-artifacts/stories/2-4-background-collector-and-android-workmanager.md` — WM bootstrap]
- [Source: `_bmad-output/implementation-artifacts/stories/2-8-android-fgs-health-passive-pipeline.md` — FGS/WM coexistence]
- [Source: `_bmad-output/implementation-artifacts/stories/2-9-today-display-truth-model-and-live-overlay.md` — do not regress]
- [Source: `docs/DEPENDENCIES.md` — WM verification procedure]
- [Source: `lib/core/health/stale_data_evaluator.dart` — separate concern; 4.2 combines with capability snapshot]

## Dev Agent Record

### Agent Model Used

Composer (dev-story 2026-06-02)

### Debug Log References

- `flutter test` — 291 tests passed (full suite)
- `flutter analyze` — no issues found

### Completion Notes List

- Implemented D-23 `BackgroundHealthCapabilityEvaluator` + snapshot; Kotlin channel for battery exemption and manufacturer; wired through `AppDependencies` with shared activity gate for FGS.
- WM registration passes `databasePath` in `inputData`; documented D-04 fallback semantics in `main.dart` / `registerStepCollectionWorkmanager`.
- **Pending:** AC #4 physical-device WM spike + OEM evaluator log on Baptiste hardware (Sub-task F).

### File List

- lib/core/health/background_health_capability_snapshot.dart (new)
- lib/core/health/background_health_manifest.dart (new)
- lib/core/services/background_health_capability_evaluator.dart (new)
- lib/core/services/platform_capability_probe.dart (new)
- lib/core/services/android_platform_capability_probe.dart (new)
- lib/core/di/app_dependencies.dart
- lib/core/services/workmanager_callback.dart
- lib/main.dart
- android/app/src/main/kotlin/com/astraapp/astra_app/BackgroundHealthCapabilityChannel.kt (new)
- android/app/src/main/kotlin/com/astraapp/astra_app/MainActivity.kt
- docs/DEPENDENCIES.md
- test/core/services/background_health_capability_evaluator_test.dart (new)
- test/core/di/app_dependencies_test.dart
- test/core/services/workmanager_callback_test.dart
- test/android/android_manifest_test.dart
- test/presentation/widgets/period_toggle_test.dart

### Change Log

- 2026-06-02: Story 2.10 — capability evaluator, Android probes, AppDependencies wiring, WM inputData hardening, tests + docs (automated); physical verification deferred.
- 2026-06-02: Seven sub-task commits (A–F docs + chore); status → review.
- 2026-06-02: Code review fixes — shared activity gate, WM UPDATE policy for databasePath; status → done.

## Story Completion Status

- Status: **done** (Sub-task F manual device checks deferred — run when convenient per `docs/DEPENDENCIES.md`)
- Ultimate context engine analysis completed — comprehensive developer guide created
- **Note:** Epic 2 closing infrastructure story — delivers `BackgroundHealthCapabilityEvaluator` and WM fallback hardening; My Data UI consumes flags in Story 4.2
- **Prerequisites satisfied:** Stories 2.9 and 2.8 done; WM + FGS + backfill pipeline operational
