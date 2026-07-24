# Story 30.3: Document iOS Background Collection Gap

Status: done

<!-- audits_2 Epic 30 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 30-3 · diagnostic-workmanager-maintenance-db.md #3 · AUD2-FR18 -->
<!-- Prerequisite: 30-2 done · base 0.13.0+32 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As an **iOS user**,
I want clear product documentation on how steps sync when the app is closed for days,
So that expectations match actual resume/backfill behaviour.

## Acceptance Criteria

1. **Given** WorkManager registration is Android-only (`!Platform.isAndroid` early return in `cancelStepCollectionWorkmanager`, `registerStepCollectionWorkmanager`, `registerDatabaseMaintenanceWorkmanager`)
   **When** documentation is updated
   **Then** the iOS background collection gap and resume/backfill strategy are documented in `docs/project-context.md` (primary) with cross-links to architecture — AUD2-FR18

2. **Given** the documentation pass
   **When** a maintainer reads `docs/project-context.md` + linked architecture sections
   **Then** it is explicit that iOS has **no** 15-min WorkManager step collection and **no** Phase 0 `BGAppRefresh` implementation — reconciliation happens on app open / foreground lifecycle only

3. **Given** misleading inline comments still claim iOS uses WorkManager
   **When** this story ships
   **Then** at minimum `data_lifecycle_service.dart` class doc no longer says "iOS via WorkManager" (comment-only fix allowed; no behaviour change)

4. **Given** diagnostic #3 in `diagnostic-workmanager-maintenance-db.md`
   **When** documentation is complete
   **Then** finding #3 and README todo M8 are marked `fixed` / done with story ref `30-3`

**Covers:** AUD2-FR18 · diagnostic-workmanager-maintenance-db.md #3 (P1)

**Depends on:** 30-2 done. Ships before 30-4.

**Out of scope:** Implementing iOS `BGAppRefresh`, HealthKit, or any new background scheduler; Android WM/FGS changes; version bump (Epic 30 close → patch+1); code changes beyond misleading comment fixes tied to AC #3.

## Tasks / Subtasks

- [x] **Sub-task A — `project-context.md` iOS background section** (AC: #1, #2)
  - [x] Read fully: `workmanager_callback.dart` (L167-223), `main.dart` (boot WM registration), `app_lifecycle_coordinator.dart`, `lifecycle_live_pipeline_service.dart`, `lifecycle_persist_service.dart`, `stale_data_evaluator.dart`, `my_data_cubit.dart` (background status), `health_foreground_service.dart` (Android-only FGS)
  - [x] Add a new section **"Platform background collection (Android vs iOS)"** to `docs/project-context.md` after Test commands (before Story completion checklist) covering:
    - Android: WM 15-min collect + weekly maintenance (`astra_step_collection_periodic`, `astra_database_maintenance_periodic`); FGS health when process backgrounded; mandatory foreground backfill on cold start/resume
    - iOS gap: all three WM register/cancel functions no-op on `!Platform.isAndroid`; no FGS; **no BGAppRefresh code in Phase 0** (architecture/PRD mention it as future — document as not shipped)
    - iOS resume/backfill path: `AppLifecycleCoordinator.foregroundBackfill` → `BackgroundCollector.collectOnce` on cold start; `resumeLivePipeline()` drain + optional phone peek on `AppLifecycleState.resumed`; `LiveStepMonitor` while process alive
    - Multi-day closed app: OS pedometer counter continues; SQLite catches up only when user opens app — not a data-loss bug
    - Stale UX: `isStaleData` — 4h iOS / 12h Android; My Data `BackgroundCollectionStatus.iosBackfill`; l10n keys `myDataBackgroundIosBackfill`, `bannerStaleFullIos`
    - DB maintenance on iOS: opportunistic via My Data / foreground isolate offload (`DataLifecycleService` compute path); **not** scheduled WM; resume must not VACUUM on UI connection
  - [x] Cross-link: `_bmad-output/planning-artifacts/architecture.md` §Platform Architecture, `background-trust-and-movement-validation.md` §3.2
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Fix misleading WorkManager-on-iOS comment** (AC: #3)
  - [x] Update `data_lifecycle_service.dart` class doc (L106-109): replace "iOS via WorkManager" with accurate Phase 0 wording (foreground/My Data opportunistic maintenance only)
  - [x] Grep repo for other claims that iOS has WM 15-min collection; fix comment/doc strings only — do not change runtime behaviour
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Diagnostic closure** (AC: #4)
  - [x] Update `planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` #3 → `fixed` with story ref; refresh synthèse table + plan d'action P1 row
  - [x] Update `planning-artifacts/audits_2/README.md`: diagnostic 03 row #3 statut → `fixed (30-3)`; M8 → done; diagnostic 03 P1+ ouverts count if applicable
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

Phase 0 ships Android reference background stack (FGS + WorkManager + foreground backfill). iOS intentionally has **no WorkManager parity** — three registration functions early-return:

```174:176:lib/core/services/workmanager_callback.dart
  if (!(isAndroid ?? Platform.isAndroid)) {
    return;
  }
```

(Same guard at L191-193 and L221-223.)

Boot still calls `registerWorkmanagerTasksForBoot` post-`runApp` (`main.dart:73`), but on iOS both periodic tasks are never registered. Steps are **not lost** on device — the OS pedometer counter advances — but SQLite ingestion only runs when collection executes:

| Trigger | Android | iOS Phase 0 |
|---------|---------|-------------|
| Process alive | `LiveStepMonitor` + ~60s persist | Same |
| Process backgrounded (RAM) | FGS health collection | Live monitor stops; no FGS |
| Process killed | WM ~15 min (best effort) + reopen backfill | **Reopen/resume backfill only** |
| Weekly VACUUM | WM maintenance task | My Data / foreground offload when due |

**Gap AUD2-FR18:** `docs/project-context.md` (agent source of truth) has **zero** iOS/background content today. Architecture and `background-trust-and-movement-validation.md` describe the model but agents implementing Epic 30+ may miss the iOS honesty requirement. Diagnostic #3 remains `open`.

[Source: `diagnostic-workmanager-maintenance-db.md` #3 · `epics-audits-2.md` AUD2-FR18]

### Document precisely — Phase 0 vs future

| Topic | Phase 0 reality (document this) | Future / architecture only (do not imply shipped) |
|-------|--------------------------------|---------------------------------------------------|
| WM step collection | Android only | — |
| WM DB maintenance | Android only | — |
| FGS health | Android only (`HealthForegroundServiceCoordinator`) | — |
| BGAppRefresh | **Not implemented** — no Swift/Dart registration in repo | Mentioned in PRD/architecture as Phase 1+ (P6 in background-trust doc) |
| Foreground backfill | Both platforms — mandatory | — |
| Stale threshold | 4h iOS / 12h Android | `stale_data_evaluator.dart` |

Grep confirms: zero `BGAppRefresh` / `bg_app_refresh` in `lib/`. Do not document BGAppRefresh as active behaviour.

### iOS resume/backfill code path (must be reflected in docs)

**Cold start** (`AppLifecycleCoordinator.bindToWidget`):

```118:125:lib/core/services/app_lifecycle_coordinator.dart
    _session.foregroundBackfill = enableLiveStepPipeline
        ? _persist.runPersistCycle(
            enableGoalNotification: false,
            sourceTimeout: Duration.zero,
          )
        : deps.backgroundCollector.collectOnce(
            enableGoalNotification: false,
          );
```

Passed to `AppScaffold` → awaited before shell paint when non-null. Parallel reconcile via `LifecycleLivePipelineService.reconcileAfterBackfillCompletes()`.

**Resume** (`onLifecycleResumed` → `resumeLivePipeline`): day boundary check → drain persist → optional phone peek → monitor reconcile → Today/History/My Data silent refresh.

**Stale evaluation:**

```1:15:lib/core/health/stale_data_evaluator.dart
/// Android: 12 hours — avoids false stale after overnight sleep.
/// iOS: 4 hours — honest backfill model without WorkManager parity.
```

**My Data UI** already honest — document as existing UX, not new work:

- `BackgroundCollectionStatus.iosBackfill` when not stale (`my_data_cubit.dart:660-661`)
- `myDataBackgroundIosBackfill` / `bannerStaleFullIos` in `app_en.arb`

### Misleading comment to fix (AC #3)

```106:109:lib/core/services/data_lifecycle_service.dart
/// Phase 0 scheduling: Android weekly WorkManager; iOS via WorkManager /
/// My Data flows — not on app resume (resume must not VACUUM while UI DB is open).
```

Second line is correct (no VACUUM on resume); first clause wrongly implies iOS WorkManager. Replace with: Android weekly WM; iOS opportunistic maintenance via My Data / foreground isolate offload only.

### Preserve (do not break)

| Behaviour | Must remain |
|-----------|-------------|
| Android WM registration post-`runApp` | Unchanged |
| iOS early returns in WM functions | Unchanged |
| Foreground backfill / resume pipeline | Unchanged |
| Stale thresholds 4h / 12h | Unchanged |
| Existing iOS l10n copy | Unchanged unless doc references keys only |

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-04 / architecture §Platform | Document WM as orchestration, not realtime guarantee; iOS secondary, no parity promise |
| S-5 (background-trust doc) | Honest platform UX — document stale/backfill model |
| AUD2-FR18 | Explicit iOS gap + resume strategy in `project-context.md` |
| Token economy | Doc-only delivery; diff-only in review |

[Source: `architecture.md` §Platform Architecture (L390-411) · `background-trust-and-movement-validation.md` §3.2]

### File structure requirements

| File | Action |
|------|--------|
| `docs/project-context.md` | **Add** "Platform background collection (Android vs iOS)" section |
| `lib/core/services/data_lifecycle_service.dart` | Fix class doc comment (AC #3) |
| `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` | Close #3 |
| `_bmad-output/planning-artifacts/audits_2/README.md` | Sync #3 + M8 |

**Do not touch:** `workmanager_callback.dart` behaviour, `main.dart` boot sequence, `background_collector.dart`, version bump, tests (unless grep-driven comment fix in test file — unlikely).

**Optional grep after Sub-task B:**

```bash
rg -i "ios.*workmanager|workmanager.*ios" docs lib _bmad-output/planning-artifacts
```

Fix misleading hits in docs/comments only.

### Testing requirements

Documentation story — **no new Flutter tests required.**

| Verify | Expected |
|--------|----------|
| Manual read of new `project-context.md` section | Android/iOS table accurate vs code paths above |
| `rg "iOS via WorkManager"` | Zero hits after Sub-task B |
| `rg "BGAppRefresh" lib/` | Still zero — confirms doc says "not implemented" |
| `flutter test --tags critical` | Passes (no code behaviour change; run if Sub-task B touched `lib/`) |

Do **not** run bare `flutter test` unless Baptiste asks.

### Previous story intelligence (30-2)

| Learning | Impact on 30-3 |
|----------|----------------|
| Diagnostic closure pattern: update diagnostic `#N` + README row + M-todo | Replicate for #3 / M8 |
| OK commit gate per sub-task (A → B → C) | Same workflow |
| Epic 30 doc stories follow audits_2 tracker, not main `sprint-status.yaml` | Update `sprint-status-audits-2.yaml` on story create |
| 30-1/30-2 fixed Android-side DB contention | iOS doc should note Android WM exists **in addition to** foreground backfill — layered catch-up |

[Source: `stories/30-2-configure-pragma-busy-timeout-on-database-open.md`]

### Cross-story context (Epic 30)

| Story | Status | Relationship |
|-------|--------|--------------|
| 30-1 | done | Android WM maintenance lock — doc should mention WM maintenance task exists on Android only |
| 30-2 | done | busy_timeout — Android multi-isolate; iOS single-isolate typical but same DB open path |
| **30-3** | **this story** | Documentation-only — closes AUD2-FR18 |
| 30-4 | backlog | `TimeProvider` in `_TimeoutBoundedSource` — Android WM testability; unrelated to iOS gap |

After Epic 30: bump patch+1 in `pubspec.yaml` + `README.md`, mark `epic-30: done`.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `035832d` | 30-2 done — diagnostic #5 closed; pattern for #3 closure |
| `70f0c83` | busy_timeout — Android concurrency layer |
| `2538f68` / `9b89373` | 30-1 maintenance lock merged |

Epic 30 active on `main`; 30-3 is next per `sprint-status-audits-2.yaml` NEXT comment.

### Latest tech / library notes

- **workmanager ^0.9.x** — Android-only in this project; plugin may compile on iOS but registration is deliberately skipped.
- **pedometer** — cumulative since-boot on both platforms; backfill reads via `PhonePedometerSource` inside `BackgroundCollector`.
- **No new packages.** Documentation + optional comment fix only.

### Project context reference

- OK commit gate: sub-tasks A→C, separate commits after Baptiste approval
- Communication: French in chat; story + `project-context.md` section in English
- Version bump: defer to Epic 30 close (patch+1)
- Sprint tracker for this epic: `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml` (not main `sprint-status.yaml` — Epics 1–13 complete)

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 30-3, AUD2-FR18]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` #3]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` §03 #3, M8]
- [Source: `_bmad-output/planning-artifacts/architecture.md` §Platform Architecture]
- [Source: `_bmad-output/planning-artifacts/background-trust-and-movement-validation.md` §3.2]
- [Source: `lib/core/services/workmanager_callback.dart`]
- [Source: `lib/core/services/app_lifecycle_coordinator.dart`]
- [Source: `lib/core/services/lifecycle/lifecycle_live_pipeline_service.dart`]
- [Source: `lib/core/health/stale_data_evaluator.dart`]
- [Source: `lib/presentation/cubits/my_data_cubit.dart`]
- [Source: `stories/30-2-configure-pragma-busy-timeout-on-database-open.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sub-task B: `flutter test --tags critical` — pass

### Completion Notes List

- Sub-task A: added `docs/project-context.md` §Platform background collection (Android vs iOS) — WM/FGS/iOS gap, resume/backfill, stale UX, DB maintenance; cross-links architecture + background-trust §3.2. Commit `fd89518`.
- Sub-task B: fixed misleading `DataLifecycleService` class doc; `rg "iOS via WorkManager" lib/` → 0 hits. Commit `d427577`.
- Sub-task C: diagnostic 03 #3 → `fixed` (30-3); README row #3 + M8 done; P1+ ouverts 4→3. Commit `030c91d`.
- All AC satisfied (AUD2-FR18). No version bump (Epic 30 close).

### File List

- `docs/project-context.md`
- `lib/core/services/data_lifecycle_service.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/stories/30-3-document-ios-background-collection-gap.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`

### Change Log

- 2026-07-24: Story 30-3 — document iOS background collection gap (AUD2-FR18); close diagnostic 03 #3.
- 2026-07-24: Code review — patch cold-start backfill timing wording in `project-context.md`.

### Review Findings

- [x] [Review][Patch] AppScaffold backfill timing doc inaccurate [`docs/project-context.md:154`] — fixed: shell may paint before backfill completes; Today waits via `initialTodayRefresh` / `reconcileAfterBackfillCompletes`.
- [x] [Review][Defer] README diagnostic 03 #2 still `open` vs diagnostic `fixed` (30-1) [`audits_2/README.md:148`] — deferred, pre-existing.
- [x] [Review][Defer] `architecture.md:362` mentions BGAppRefresh as active iOS maintenance path — deferred, pre-existing cross-doc drift.
