# ASTRA — Project Context for AI Agents

Rules and conventions that apply across all development work on **astra-app** Phase 0.

**Audience:** Baptiste — solo UI/UX designer, Flutter novice, shipping the Hub App.

---

## Token economy (mandatory)

All agent output and code delivery follows these rules. No exceptions unless Baptiste explicitly waives them.

1. **No fluff** — No introductions, conclusions, or obvious code narration. Straight to the point.
2. **Diff-only delivery** — Never rewrite an entire file in chat. Show targeted code blocks / diffs: file path, removed lines, added lines.
3. **Compact code** — Clean code, no superfluous comments.
4. **Step validation** — If architecture is unclear, ask ≤2 short lines before generating unused code.

Chat responses: French (`communication_language`). Prefer bullets over paragraphs. Skip restating the task.

---

## Development Workflow: OK Commit Gate

Every implementation increment follows this **mandatory gate**. No exceptions unless Baptiste explicitly waives it for a given step.

### Granularity

- **One git commit per completed sub-task** within a story (not one commit per entire story unless the story is a single sub-task).
- Sub-tasks should be logically separable: e.g. schema migration, then repository, then widget — each gets its own commit after approval.

### Agent flow (after each sub-task)

1. **Implement** the sub-task only — minimal scope, no drive-by refactors.
2. **Stop** — do not commit yet.
3. **Show compact review** (format below).
4. **Wait** for explicit approval: `OK commit`, `c'est bon`, `valide`, or equivalent.
5. **Only then** stage, commit, confirm success — then continue to the next sub-task.

### Compact review format

```markdown
## Review — [sub-task title]

**Files:** `path` — one-line purpose (≤5 bullets)
**Verify:** command / screen / expected (1–3 lines)
**Commit:** `type(scope): short imperative summary`
```

Then diffs only (file + −/+). No pedagogy, no "why this way", no "learn this".

### Commit message convention

Imperative, focused on **why**, scoped where helpful.

Examples:
- `feat(database): add timeseries_samples schema v1 with bucket unique index`
- `feat(today): add GoalRing widget with progress arc states`
- `fix(normalizer): handle step counter reset after reboot`

### What agents must NOT do

- Commit without Baptiste's explicit OK.
- Batch multiple sub-tasks into one commit unless Baptiste asks.
- Push to remote unless Baptiste explicitly requests it.

---

## Versioning

**Single source of truth:** `pubspec.yaml` → `version: major.minor.patch+build`

Flutter propagates this to Android `versionName` / `versionCode` automatically — no manual Gradle sync.

| Part | Example | When to bump |
|------|---------|--------------|
| `major` (`x`) | `0` → `1` | **Majeur** — breaking change, architecture pivot, or **1.0** public launch |
| `minor` (`y`) | `1` → `2` | **Moyen** — new user-facing feature, story/epic tranche, meaningful UX change |
| `patch` (`z`) | `0` → `1` | **Mineur** or **hotfix** — bug fixes, robustness, no new feature |
| `+build` | `+1` → `+2` | **Always** increment on every release APK / work phase (Android `versionCode`) |

### Work-phase → version bump

Bump `pubspec.yaml` at the **end of each work phase** (audit batch, story, hotfix sprint):

| Phase type | Bump | Example |
|------------|------|---------|
| **Hotfix** | `patch+1`, `build+1` | `0.2.0+2` → `0.2.1+3` |
| **Mineur** | `patch+1`, `build+1` | same as hotfix (fixes only, no new capability) |
| **Moyen** | `minor+1`, `patch=0`, `build+1` | `0.1.1+2` → `0.2.0+3` |
| **Majeur** | `major+1`, `minor=0`, `patch=0`, `build+1` | `0.2.1+3` → `1.0.0+4` (pre-1.0: reserve `1.0.0` for launch) |

Also update `README.md` version line when bumping. Historical checklist rows in `docs/BETA_CHECKLIST.md` are **not** rewritten.

**Current:** `0.2.0+2` — post-audit remediation (bug fixes, stale banners, dead-code cleanup). `0.x` = pre-1.0 OSS beta.

**In-app display:** Profile tab footer reads from `package_info_plus` (built manifest). Release APK: displayed version must match `pubspec.yaml` and `aapt dump badging`.

---

## Test commands

| Context | Command |
|---------|---------|
| **Daily / story work (default)** | `flutter test --exclude-tags slow` |
| **Full suite (CI / before epic close)** | `flutter test` |
| **Single file** | `flutter test test/path/to/file_test.dart` |

The `slow` tag is declared in `dart_test.yaml` and applied via `@Tags(['slow']) library;` in:
- `test/dev/data_inject_service_test.dart` — 25 920-row inject
- `test/dev/lifecycle_simulator_test.dart` — compaction on 90-day dataset
- `test/dev/chart_benchmark_test.dart` — render + query benchmarks
- `test/app_live_pipeline_lifecycle_test.dart` — ~41 s full-app integration

Agent rule: **always run `flutter test --exclude-tags slow`** in the story verification step unless the story explicitly touches a `slow`-tagged file. When it does, add the targeted file to the command instead of running the full slow suite.

---

## Platform background collection (Android vs iOS)

Phase 0 ships an **Android reference** background stack (FGS + WorkManager + mandatory foreground backfill). iOS is **secondary** — no WorkManager parity, no FGS, no `BGAppRefresh` registration in the repo. Steps on device are not lost; SQLite ingestion catches up when the user opens the app.

Cross-links: [`architecture.md` §Platform Architecture](../_bmad-output/planning-artifacts/architecture.md#platform-architecture-android-vs-ios) · [`background-trust-and-movement-validation.md` §3.2](../_bmad-output/planning-artifacts/background-trust-and-movement-validation.md#32-process-killed-swipe-away--oem-kill)

### WorkManager registration (Android only)

Boot calls `registerWorkmanagerTasksForBoot` post-`runApp` (`main.dart`). On iOS, all three WM entry points early-return on `!Platform.isAndroid`:

| Function | Android | iOS Phase 0 |
|----------|---------|-------------|
| `cancelStepCollectionWorkmanager` | Cancels in-flight collect work | No-op |
| `registerStepCollectionWorkmanager` | Periodic ~15 min (`astra_step_collection_periodic`) | No-op |
| `registerDatabaseMaintenanceWorkmanager` | Weekly (`astra_database_maintenance_periodic`) | No-op |

WorkManager is **orchestration**, not a guaranteed 5-minute cadence — OEM battery optimization may defer tasks. Foreground backfill on app open remains mandatory on both platforms.

### Collection triggers by platform

| Trigger | Android | iOS Phase 0 |
|---------|---------|-------------|
| Process alive (foreground) | `LiveStepMonitor` + ~60 s activity-based persist | Same |
| Process backgrounded (RAM, not killed) | FGS health collection (`HealthForegroundServiceCoordinator`) | Live monitor stops; no FGS |
| Process killed / swipe away | WM ~15 min (best effort) + reopen backfill | **Reopen/resume backfill only** |
| Weekly `PRAGMA optimize` / `VACUUM` | WM maintenance task (background isolate) | My Data / foreground isolate offload when due — **not** scheduled WM |

**iOS gap (AUD2-FR18):** no 15-min WorkManager step collection, no Phase 0 `BGAppRefresh` implementation (architecture/PRD mention it as Phase 1+ future — not shipped). Grep confirms zero `BGAppRefresh` / `bg_app_refresh` in `lib/`.

### iOS resume / backfill path

**Cold start** — `AppLifecycleCoordinator.bindToWidget` sets `foregroundBackfill`:

- Live pipeline enabled → `LifecyclePersistService.runPersistCycle(sourceTimeout: Duration.zero)`
- Otherwise → `BackgroundCollector.collectOnce`

`AppScaffold` starts backfill in `_initialRefresh()` on mount — the shell may paint first. Today waits via `initialTodayRefresh()` / `reconcileAfterBackfillCompletes()` (fast-path display, then SQLite reconcile when backfill completes).

**Resume** — `onLifecycleResumed` → `resumeLivePipeline()`: local day boundary check → drain persist → optional phone peek (`PhonePedometerSource`) → monitor reconcile → silent Today/History/My Data refresh.

**Multi-day app closed:** OS pedometer counter continues advancing. SQLite only ingests when collection runs (user opens app). This is expected — not a data-loss bug.

### Stale UX (honest platform model)

| Signal | Threshold / behaviour |
|--------|----------------------|
| `isStaleData` | 4 h iOS / 12 h Android (`stale_data_evaluator.dart`) |
| My Data background card | `BackgroundCollectionStatus.iosBackfill` when not stale on iOS (`my_data_cubit.dart`) |
| l10n | `myDataBackgroundIosBackfill`, `bannerStaleFullIos` (`app_en.arb`) |

Android 12 h avoids false stale after overnight sleep. iOS 4 h reflects the backfill-only model without WM parity.

### DB maintenance on iOS

`DataLifecycleService` runs downsampling + `VACUUM` in a `[compute]` isolate (short-lived connection) so VACUUM does not race the UI connection. iOS maintenance is **opportunistic** — triggered from My Data flows or foreground offload when due. **Resume must not VACUUM** while the UI SQLite connection is open (`AppLifecycleCoordinator._onAppForegrounded` comment).

---

## Story completion checklist (applies to every story)

Before marking a story done:

- [ ] All sub-tasks implemented and each **OK-commit gated** separately
- [ ] Acceptance criteria verified (stated in compact review Verify line)
- [ ] No secrets in committed files (`.env`, keys, etc.)
- [ ] `docs/DEPENDENCIES.md` updated if packages added
- [ ] `flutter test --exclude-tags slow` passes (or explicit note if a slow-tagged file is the story's subject)

---

## References

**Entry point:** [`_bmad-output/README.md`](../_bmad-output/README.md)

**Specifications:**

- Architecture: `_bmad-output/planning-artifacts/architecture.md`
- PRD: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md`
- PRD addendum (SQL, ADP): `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md`
- UX: `_bmad-output/planning-artifacts/ux-design-specification.md`
- Epics & stories: `_bmad-output/planning-artifacts/epics.md`
- Decision log: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/.decision-log.md`

**Implementation tracking:**

- Sprint status: `_bmad-output/implementation-artifacts/sprint-status.yaml`
- Readiness assessment: `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-25.md`
- Story files (when created): `_bmad-output/implementation-artifacts/stories/`
