# Story 26.5: Cover Isolate Background Collector Factory Bootstrap

Status: in-progress

<!-- Post-audit Epic 26 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 26-5 · diagnostic-couverture-structurelle.md Top #4 · AUD-54 · NFR-AUD-03/06 -->
<!-- Prerequisite: Story 2-8 factory extraction done; Story 26-3 notification rollback patterns available for reuse -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want `createIsolateBackgroundCollector` tested directly,
So that WorkManager/FGS isolate bootstrap regressions are caught early.

## Acceptance Criteria

1. **Given** `createIsolateBackgroundCollector`
   **When** unit tests run
   **Then** at least one test **invokes the factory by name** (`await createIsolateBackgroundCollector(...)`) inside a dedicated `group('createIsolateBackgroundCollector')` or test name containing `createIsolateBackgroundCollector` (AUD-54, NFR-AUD-06)
   **And** tests live in a **new** file `test/core/services/background_collector_factory_test.dart` — do not fold into WM/FGS wrapper tests

2. **Given** in-memory SQLite (`setUpSqfliteFfi` + `openAstraDatabase(databasePath: inMemoryDatabasePath)`) and injected `_FakeStepSource` readings
   **When** `createIsolateBackgroundCollector(db: db, sources: [...], clock: FakeTimeProvider(...))` runs then `collector.collectOnce()`
   **Then** the test asserts functional bootstrap wiring end-to-end:
   - bucket written via factory-wired `StepIngestionRepository` / `StepAggregationRepository` (assert `getLastIngestionUtc()` or bucket count)
   - `UserSettingsRepository` / `UserHealthMetricsRepository` session path works (e.g. read/write goal prefs after factory bootstrap)
   **And** no real device isolate, `PhonePedometerSource`, or `AdpBleSource` required when `sources` is injected

3. **Given** `sources: null` and `includePhonePedometerSource: false`
   **When** factory builds default sources (BLE-only path — no fake phone readings)
   **Then** `collectOnce()` completes without throw
   **And** no ingestion buckets are written (empty BLE stream in test env)
   **And** test name references `includePhonePedometerSource` or `omits phone source`

4. **Given** goal already near target in SQLite and `_FakeStepSource` crosses daily goal on collect
   **When** factory receives a `NotificationService` whose `initializeForBackground()` **succeeds** and injected `notificationPermissionGranted: () async => true`
   **Then** `collectOnce(enableGoalNotification: true)` triggers goal notification side effect (presenter spy count or `getGoalNotificationShownDate()`)
   **And** asserts factory wired notification deps when init succeeds (regression guard for `spec-notification-startup-init.md`)

5. **Given** `NotificationService` with `platformInitializer` delay + short `backgroundInitTimeout` (same fault pattern as `workmanager_callback_test.dart` L174–186)
   **When** factory bootstrap runs then `collectOnce(enableGoalNotification: true)` with goal-crossing readings
   **Then** collection **still succeeds** (bucket written)
   **And** goal notification is **skipped** (presenter count 0) — factory nulls notification path when `initializeForBackground()` returns false

6. **Given** existing indirect coverage in `workmanager_callback_test.dart` and `fgs_step_collection_test.dart`
   **When** this story ships
   **Then** coverage is **extended, not duplicated** — new named group owns AUD-54 factory contract; WM/FGS integration tests remain green unchanged
   **And** no production changes unless a test exposes a real bug

7. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** split into reviewable sub-tasks (gap analysis + happy path + source flag + notification branches + verify) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 26 closes

**Covers:** AUD-54 · diagnostic-couverture-structurelle.md Top #4 · NFR-AUD-03 (preserve isolate DB model)

**Depends on:** Story 2-8 (shared factory), Story 18-2/18-3 (repo split in factory). Independent of 26-6.

**Out of scope:** `runStepCollectionWorkmanagerTask` / `runFgsStepCollectionCycle` orchestration (already tested); `openIsolateAstraDatabase` WAL tests (`isolate_database_factory_test.dart`); UI-path `AppDependencies` collector wiring; version bump; real isolate spawn.

## Tasks / Subtasks

- [x] **Sub-task A — Baseline + gap analysis** (AC: #1, #6)
  - [x] Read `lib/core/services/background_collector_factory.dart` fully (56 LOC — entire file)
  - [x] Grep `test/` for `createIsolateBackgroundCollector` — confirm **zero** named hits (AUD-54)
  - [x] Note indirect coverage: `workmanager_callback_test.dart`, `fgs_step_collection_test.dart` call factory via wrappers only
  - [x] Confirm `background_collector_test.dart` manually constructs deps — **not** via factory
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (plan-only commit optional)

- [ ] **Sub-task B — New test file + happy-path bootstrap** (AC: #1, #2)
  - [ ] Create `test/core/services/background_collector_factory_test.dart`
  - [ ] `setUpAll(() => setUpSqfliteFfi())`; per-test in-memory DB open/close
  - [ ] Add `group('createIsolateBackgroundCollector', () { ... })`
  - [ ] Test: `createIsolateBackgroundCollector wires repos and collects via injected source` — direct factory call + `collectOnce()` + `getLastIngestionUtc()` assertion
  - [ ] Reuse `_FakeStepSource` pattern from `fgs_step_collection_test.dart` / `workmanager_callback_test.dart` (local copy in new file OK)
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task C — Default source flag branch** (AC: #3)
  - [ ] Test: `createIsolateBackgroundCollector omits phone source when includePhonePedometerSource is false` — `sources: null`, flag false, assert no buckets
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task D — Notification bootstrap branches** (AC: #4, #5)
  - [ ] Test: `createIsolateBackgroundCollector enables goal notification when background init succeeds` — seed near-goal bucket + fake source crossing goal + presenter spy
  - [ ] Test: `createIsolateBackgroundCollector skips notification when background init times out but still collects` — delayed `platformInitializer` + short timeout; bucket written, show count 0
  - [ ] Mirror WM test setup for goal prefs (`setDailyStepGoal`, `setGoalNotificationsEnabled`) via UI DB before factory call on same in-memory connection
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task E — Regression verification** (AC: #6, #7)
  - [ ] Run `flutter test test/core/services/background_collector_factory_test.dart --exclude-tags slow`
  - [ ] Run `flutter test test/core/services/workmanager_callback_test.dart test/core/services/fgs_step_collection_test.dart --exclude-tags slow`
  - [ ] Run `flutter test --exclude-tags slow`
  - [ ] Grep confirms test name or group contains `createIsolateBackgroundCollector`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Named unit tests for `createIsolateBackgroundCollector` | WM/FGS wrapper task orchestration |
| Repo/session/notification wiring via behavioral asserts | Spawning real Dart isolates |
| `includePhonePedometerSource` default-source branch | Testing `PhonePedometerSource` / `AdpBleSource` hardware |
| Notification init success vs timeout paths | `maybeNotifyGoalReachedIfGoalMet` direct tests (26-3 done) |
| New dedicated test file | Production logic changes unless bug found |
| OK-commit sub-task gate | Version bump (Epic 26 close) |

### Root cause (read before editing)

**Coverage gap (AUD-54):** `diagnostic-couverture-structurelle.md` Top #4 flags `createIsolateBackgroundCollector` as **never targeted by method name** in `test/`. WM and FGS integration tests exercise the wiring **indirectly** through `runStepCollectionWorkmanagerTask` / `runFgsStepCollectionCycle`, but CI/audit grep for the symbol fails.

**Why it matters:** This 56-line factory is the **single shared bootstrap** for all background ingestion isolates (WM + FGS). It wires 5 repositories, `AstraDatabaseSession`, default sources, and conditional notification deps. Divergence from UI-path `AppDependencies` collector config caused historical bugs (Story 2-8). A regression here breaks passive step collection silently.

### Production implementation (MUST preserve — do not change in this story)

**File:** `lib/core/services/background_collector_factory.dart`

```dart
Future<BackgroundCollector> createIsolateBackgroundCollector({
  required Database db,
  String? databasePath,
  List<DataIngestionSource>? sources,
  TimeProvider? clock,
  NotificationService? notificationService,
  Future<bool> Function()? notificationPermissionGranted,
  bool includePhonePedometerSource = true,
}) async {
  final timeProvider = clock ?? const SystemTimeProvider();
  final session = AstraDatabaseSession(
    databasePath: databasePath ?? db.path,
    initial: db,
  );
  final resolvedSources = sources ??
      [
        if (includePhonePedometerSource) PhonePedometerSource(),
        const AdpBleSource(),
      ];
  final notifications = notificationService ?? NotificationService();
  final notificationsReady = await notifications.initializeForBackground();
  return BackgroundCollector(
    sources: resolvedSources,
    normalizer: StepNormalizer(clock: timeProvider),
    repository: StepIngestionRepository(db),
    stepAggregation: StepAggregationRepository(db, clock: timeProvider),
    baselineRepository: IngestionBaselineRepository(db),
    userSettings: UserSettingsRepository(session),
    userHealthMetrics: UserHealthMetricsRepository(session, clock: timeProvider),
    clock: timeProvider,
    notificationService: notificationsReady ? notifications : null,
    notificationPermissionGranted: notificationsReady
        ? (notificationPermissionGranted ??
              notifications.hasNotificationPermission)
        : null,
  );
}
```

**Callers (READ ONLY — keep green):**

| Caller | Factory args |
|--------|--------------|
| `workmanager_callback.dart` L109–116 | No `includePhonePedometerSource` override (default true); injectable `sources`, `clock`, `notificationService` |
| `fgs_step_collection.dart` L27–36 | `includePhonePedometerSource: sources == null && !skipPhoneSourceWhenUiActive` |

**UI contrast (NFR-AUD-03):** `AppDependencies` builds `BackgroundCollector` with `MonitorDrainSource` + `AdpBleSource` — **not** via this factory. Do not conflate paths in tests.

### Current test landscape (UPDATE — read before writing)

| File | Factory coverage | AUD-54 gap |
|------|------------------|------------|
| `workmanager_callback_test.dart` | Indirect via `runStepCollectionWorkmanagerTask` (6 tests) | No symbol grep |
| `fgs_step_collection_test.dart` | Indirect via `runFgsStepCollectionCycle` (2 tests); phone-omit via wrapper flag | No symbol grep |
| `background_collector_test.dart` | Direct collector tests; manual `_goalNotificationCollector` helper | Bypasses factory |
| `isolate_database_factory_test.dart` | DB opener only | N/A |
| **`background_collector_factory_test.dart`** | **Does not exist** | **Target** |

### Reuse patterns — do not reinvent

**Harness (from WM/FGS tests):**

```dart
setUpAll(() async {
  await setUpSqfliteFfi();
});

// Per test:
db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
repository = StepAggregationRepository(db, clock: clock);
// tearDown: await db.close();
```

**`_FakeStepSource`** — copy from `fgs_step_collection_test.dart` L15–28 or `workmanager_callback_test.dart` (same shape).

**`_testNotificationService()`** — from WM/FGS tests:

```dart
NotificationService(
  goalNotificationPresenter: ({required id, required title, body}) async {},
  permissionChecker: () async => PermissionStatus.granted,
);
```

**Init timeout fault injection** (WM L181–186):

```dart
NotificationService(
  platformInitializer: (_) =>
      Future<void>.delayed(const Duration(seconds: 5)),
  backgroundInitTimeout: const Duration(milliseconds: 10),
  permissionChecker: () async => PermissionStatus.granted,
);
```

**Goal-crossing seed** (WM L85–114 pattern): pre-seed bucket at 4900, fake source adds +200, goal 5000.

**Suggested test file skeleton:**

```dart
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/background_collector_factory.dart';
// ... repos, models, fakes ...

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('createIsolateBackgroundCollector', () {
    test('createIsolateBackgroundCollector wires repos and collects via injected source',
        () async {
      // open db, factory with sources + clock, collectOnce, assert lastIngestionUtc
    });

    test('createIsolateBackgroundCollector omits phone source when includePhonePedometerSource is false',
        () async {
      // sources: null, includePhonePedometerSource: false → no buckets
    });

    test('createIsolateBackgroundCollector enables goal notification when background init succeeds',
        () async {
      // seed prefs + near-goal bucket, presenter spy, collectOnce(enableGoalNotification: true)
    });

    test('createIsolateBackgroundCollector skips notification when background init times out but still collects',
        () async {
      // timeout NotificationService, bucket written, showCount 0
    });
  });
}
```

**Testing nuance:** Factory returns opaque `BackgroundCollector` — assert wiring **behaviorally** via `collectOnce()` side effects on shared DB, not by inspecting private fields. `AstraDatabaseSession` uses same `db` handle passed in — in-memory tests need no file path juggling unless testing explicit `databasePath` param (optional stretch).

### Architecture compliance

- **Single-writer ingestion:** Only `BackgroundCollector.collectOnce` writes buckets — tests seed pre-existing buckets via repository, never bypass collector for new writes
- **NFR-AUD-03:** Factory uses raw `Database` for step repos + `AstraDatabaseSession` for settings/health — preserve dual wiring; do not refactor to single session in this story
- **NFR-AUD-06:** Unit tests with SQLite FFI fakes — no widget tree, no real isolate spawn
- **Notification init contract:** `initializeForBackground() == false` → `notificationService: null` on collector ([Source: spec-notification-startup-init.md])
- **Clock injection:** Always pass `FakeTimeProvider` — never rely on `SystemTimeProvider` in tests
- **Layering:** Factory in `core/services/` — test file mirrors path under `test/core/services/`

### File structure requirements

| Action | Path |
|--------|------|
| **CREATE** | `test/core/services/background_collector_factory_test.dart` |
| **READ ONLY** | `lib/core/services/background_collector_factory.dart` |
| **READ ONLY** | `lib/core/services/background_collector.dart` (collectOnce contract) |
| **READ ONLY** | `lib/core/services/workmanager_callback.dart` (caller) |
| **READ ONLY** | `lib/core/services/fgs_step_collection.dart` (caller + includePhonePedometerSource) |
| **READ ONLY** | `test/core/services/workmanager_callback_test.dart` (reuse patterns) |
| **READ ONLY** | `test/core/services/fgs_step_collection_test.dart` (reuse patterns) |
| **DO NOT** | Modify WM/FGS tests unless shared import extraction needed (prefer local `_FakeStepSource` copy) |

### Testing requirements

**Default verify command:**

```bash
flutter test test/core/services/background_collector_factory_test.dart --exclude-tags slow
flutter test test/core/services/workmanager_callback_test.dart test/core/services/fgs_step_collection_test.dart --exclude-tags slow
flutter test --exclude-tags slow
```

**AUD-54 verification grep:**

```bash
rg "createIsolateBackgroundCollector" test/core/services/background_collector_factory_test.dart
```

Expect: group name + multiple test bodies calling `createIsolateBackgroundCollector(`.

**Assertions checklist:**

- [ ] Direct factory call is the **explicit** test entry (not WM/FGS wrapper)
- [ ] Injected fake source → bucket written (repos wired)
- [ ] `includePhonePedometerSource: false` → no buckets with null sources
- [ ] Notification success path → goal notification fires on cross
- [ ] Notification timeout path → collection succeeds, notification skipped
- [ ] `db.close()` in tearDown (avoid leaks)

### Previous story intelligence (26-4)

- Sub-task A→E + OK-commit gate pattern — mirror for 26-5
- AUD-53/54 same class: **indirect wrapper coverage vs named audit contract**
- New dedicated test file (not extending cubit test) — factory belongs in `test/core/services/`
- Tests-only expectation — no production changes unless bug exposed
- Full fast suite was green after 26-4 (956 passed) — extend without breaking WM/FGS/collector tests

### Git intelligence

Recent commits (Story 26-4):

- `a6becaa` — close story 26-4 after code review
- `d5e98be` / `1940d48` / `1820c78` — named `refreshAfterDayRollover` tests
- `dc91cc3` — gap analysis commit pattern

Factory unchanged since Epic 18-3 repo split — safe to add named tests only. WM notification-timeout test (`ccd04bf` era 26-3) validates same `initializeForBackground` contract at wrapper level — 26-5 owns factory-level grep.

### Latest tech information

- **sqflite 2.x + sqflite_common_ffi:** In-memory DB (`inMemoryDatabasePath`) sufficient for factory unit tests — no isolate spawn needed to validate wiring
- **NotificationService.backgroundInitTimeout:** Already tested in `notification_service_test.dart`; factory test reuses short timeout pattern, does not re-test `NotificationService` internals
- **WorkManager 0.9.x / health FGS:** Production entry points unchanged — factory tests decouple bootstrap from platform plugins

### Project context reference

- OK-commit gate mandatory per sub-task — `docs/project-context.md`
- Default test command: `flutter test --exclude-tags slow`
- Version bump at **Epic 26 close** only (patch+1, build+1) — current `0.11.2+27`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (not legacy `sprint-status.yaml`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` § Story 26-5 · AUD-54]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-couverture-structurelle.md` § Top #4 · background_collector_factory table]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-dependance.md` § isolate repo `new` pattern]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-acces-concurrents.md` § separate isolate connections]
- [Source: `_bmad-output/implementation-artifacts/spec-notification-startup-init.md` § init failure → null notification deps]
- [Source: `_bmad-output/implementation-artifacts/stories/2-8-android-fgs-health-passive-pipeline.md` § shared factory]
- [Source: `_bmad-output/implementation-artifacts/stories/26-3-cover-goal-notification-evaluation-and-rollback-path.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/26-4-cover-refresh-after-day-rollover-contract.md` § story structure]
- [Source: `lib/core/services/background_collector_factory.dart`]
- [Source: `test/core/services/workmanager_callback_test.dart` — bucket + notification patterns]
- [Source: `test/core/services/fgs_step_collection_test.dart` — `_FakeStepSource` + phone omit]
- [Source: `docs/project-context.md` § Test commands, OK-commit gate]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- AUD-54 gap confirmed: `rg createIsolateBackgroundCollector test/` → 0 hits before this story
- Indirect coverage only via WM/FGS wrappers; `background_collector_test.dart` bypasses factory

### Completion Notes List

- Sub-task A: 56 LOC factory read; zero named test hits; indirect WM/FGS + manual collector construction documented

### File List

- `_bmad-output/implementation-artifacts/stories/26-5-cover-isolate-background-collector-factory-bootstrap.md` (updated)
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (updated)

## Change Log

- 2026-07-19: Story context created — AUD-54 factory bootstrap test guide (ready-for-dev).
- 2026-07-19: Sub-task A gap analysis — AUD-54 zero named hits confirmed.
