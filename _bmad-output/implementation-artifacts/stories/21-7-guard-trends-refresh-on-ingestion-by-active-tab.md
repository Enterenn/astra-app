# Story 21.7: Guard Trends Refresh on Ingestion by Active Tab

Status: done

<!-- Post-audit Epic 21 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 21-7 · diagnostic-cold-start.md §C2 · AUD-08 · NFR-AUD-02 -->
<!-- Prerequisite: Stories 21-1…21-6 — done -->
<!-- Version bump: deferred to Epic 21 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want background ingestion completion not to refresh Trends while I am on Today,
So that invisible tab work does not steal CPU after catch-up.

## Acceptance Criteria

1. **Given** `_onIngestionComplete` runs after ingestion upserts (`upsertedCount > 0`)
   **When** `_selectedIndex != 1` (Today or Menu tab)
   **Then** `_historyCubit.refresh` is **not** invoked (AUD-08)
   **And** `_todayCubit.refreshMetadata()` still runs (unchanged)

2. **Given** Trends tab is selected (`_selectedIndex == 1`)
   **When** ingestion completes
   **Then** `_historyCubit.refresh(silent: true)` still runs

3. **Given** user was on Today during ingestion (Trends refresh skipped)
   **When** user later opens Trends (`_onDestinationSelected` with `index == 1`)
   **Then** existing `openingTrends` path still calls `_historyCubit.refresh()` — data stays fresh on tab entry (no regression)

4. **Given** `_onIngestionComplete` behaviour for other cubits
   **When** this story ships
   **Then** `_myDataCubit.refresh(silent: true)` remains unchanged (AC targets History only; diagnostic C2 guards Trends)

5. **Given** unit/widget tests
   **When** story verification runs
   **Then** tests prove History refresh is skipped on Today tab and runs on Trends tab after ingestion callback
   **And** `flutter test test/presentation/screens/app_scaffold_test.dart` passes
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-08 · NFR-AUD-02 (reduces invisible Trends work on cold-start catch-up) · diagnostic-cold-start §C2

**Depends on:** Stories 21-1…21-6 — **done**

**Out of scope:** Lazy `HistoryCubit` instantiation (diagnostic C1 — separate story), deferring `_buildDayMetricsCache` (C3), changing `BackgroundCollector` callback contract, guarding `MyDataCubit.refresh`, version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Guard History refresh in `_onIngestionComplete`** (AC: #1, #2, #4)
  - [x] Read fully: `lib/presentation/screens/app_scaffold.dart` — `_onIngestionComplete` (L230–234), `_onDestinationSelected` (L236–253), tab index constants via `AppBottomNav` (0=Steps, 1=Trends, 2=Menu)
  - [x] Wrap `_historyCubit.refresh(silent: true)` with `if (_selectedIndex == 1)`
  - [x] Keep `_todayCubit.refreshMetadata()` and `_myDataCubit.refresh(silent: true)` unconditional
  - [x] Optional clarity: add file-local `static const _trendsTabIndex = 1;` if it improves readability (match existing style — no new shared constant file)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Widget tests for ingestion tab guard** (AC: #1, #2, #3, #5)
  - [x] Extend `test/presentation/screens/app_scaffold_test.dart` using existing `_RefreshCountingCubit` / `_RefreshCountingHistoryCubit`
  - [x] Trigger ingestion callback via `deps.backgroundCollector.collectOnce()` with a one-shot fake `DataIngestionSource` that yields a step reading (callback fires only when `upsertedCount > 0` — see `background_collector.dart` L138–140)
  - [x] Test **Today tab**: after `collectOnce`, `historyCubit.refreshCallCount == 0`, `todayCubit.refreshMetadataCallCount >= 1`
  - [x] Test **Trends tab**: tap chart icon first, baseline `refreshCallCount` from `openingTrends`, then `collectOnce` → history refresh count increases by 1
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Regression** (AC: #5)
  - [x] Run: `flutter test test/presentation/screens/app_scaffold_test.dart`
  - [x] Run: `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `_onIngestionComplete` History guard | Lazy `HistoryCubit` creation (C1) |
| Widget tests for tab-guard behaviour | `HistoryCubit._buildDayMetricsCache` deferral (C3) |
| Preserve Today metadata + My Data refresh | Changing when callback fires |
| Preserve `openingTrends` refresh on tab switch | Version bump (Epic 21 close) |

### Current state (read before editing)

**Problem — invisible Trends work on Today tab:**

```230:234:lib/presentation/screens/app_scaffold.dart
  void _onIngestionComplete() {
    unawaited(_todayCubit.refreshMetadata());
    unawaited(_historyCubit.refresh(silent: true));
    unawaited(_myDataCubit.refresh(silent: true));
  }
```

After cold-start backfill upserts buckets, this runs even when the user stays on Today — triggering 30d/12mo aggregates, goal resolution, and chart cache work off-screen [Source: diagnostic-cold-start L49, §C2].

**Tab index map (do not invert):**

| `_selectedIndex` | Tab | `AppBottomNav` icon |
|------------------|-----|---------------------|
| `0` | Today / Steps | `sneakerMove` |
| `1` | Trends | `chartBar` |
| `2` | Menu | `list` |

**Existing Trends refresh on tab open (must not break):**

```241:252:lib/presentation/screens/app_scaffold.dart
    final openingTrends = index == 1 && _selectedIndex != 1;
    // ...
    if (openingTrends) {
      unawaited(_historyCubit.refresh());
    }
```

If ingestion skipped History refresh on Today, user still gets fresh Trends data when opening the tab.

**Ingestion callback contract:**

```138:140:lib/core/services/background_collector.dart
    if (upsertedCount > 0) {
      _onIngestionComplete?.call();
    }
```

Tests must upsert at least one bucket (fake source or DB seed) — empty `collectOnce()` does not invoke the callback.

### Target implementation (guidance)

```dart
void _onIngestionComplete() {
  unawaited(_todayCubit.refreshMetadata());
  if (_selectedIndex == 1) {
    unawaited(_historyCubit.refresh(silent: true));
  }
  unawaited(_myDataCubit.refresh(silent: true));
}
```

Matches diagnostic C2 pseudo-code exactly [Source: diagnostic-cold-start.md L276–288].

### Regression cautions

| Risk | Mitigation |
|------|------------|
| Guarding wrong tab index | Use `1` for Trends; verify against `AppBottomNav` order |
| Breaking stale banner on Today | Keep `refreshMetadata()` unconditional |
| Trends stale after catch-up on Today | `openingTrends` refresh on tab switch covers deferred load |
| Test false negative (callback never fires) | Ensure `collectOnce` upserts > 0 via fake `DataIngestionSource` |
| Replacing ingestion callback in tests | Do not call `registerOnIngestionComplete` after scaffold mount — use `collectOnce` |

### Architecture compliance

- **Presentation orchestration:** Change stays in `AppScaffold` — no cubit/repository API changes [Source: epics-post-audit target files].
- **Lazy Trends principle:** Partial lazy loading already defers initial History refresh; this completes the ingestion path guard (C2) without full C1 lazy instantiation.
- **Display Truth Model:** Today metadata refresh unchanged — stale banner / last-ingestion still update after ingestion.
- **OK-commit gate:** One commit per sub-task [Source: `docs/project-context.md`].

### Project structure notes

| Path | Role |
|------|------|
| `lib/presentation/screens/app_scaffold.dart` | **UPDATE** — guard in `_onIngestionComplete` |
| `lib/core/services/background_collector.dart` | **READ** — callback fires only on upsert |
| `lib/presentation/widgets/app_bottom_nav.dart` | **READ** — tab index order |
| `lib/presentation/cubits/history_cubit.dart` | **READ** — understand refresh cost (30d aggregates) |
| `test/presentation/screens/app_scaffold_test.dart` | **UPDATE** — ingestion tab-guard tests |

### Testing requirements

- **Primary:** `flutter test test/presentation/screens/app_scaffold_test.dart`
- **Full:** `flutter test --exclude-tags slow`
- **Fake source pattern for ingestion tests:**
  ```dart
  class _OneShotStepSource implements DataIngestionSource {
    @override
    Stream<StepReading> watchStepReadings() async* {
      yield StepReading(
        cumulativeSteps: 100,
        observedAtUtc: DateTime.utc(2026, 6, 3, 11),
      );
    }
    // implement remaining DataIngestionSource members (providerId, etc.)
  }
  ```
  Pass via `AppDependencies.test(..., ingestionSources: [_OneShotStepSource()])` — rebuild `backgroundCollector` or pass custom `backgroundCollector` if test factory re-wraps sources.
- Reuse `_RefreshCountingCubit.refreshMetadataCallCount` and `_RefreshCountingHistoryCubit.refreshCallCount` (already in file L56–117).
- Existing test `'opening Trends tab triggers history refresh'` validates AC #3 baseline — do not remove.

### Previous story intelligence (21-6)

- **Scope discipline:** Single concern per story — 21-6 was schema-only; 21-7 is presentation guard only.
- **Deferred enrichment pattern:** Story 21-1 moved heavy work off fast path; this story stops off-tab History work after ingestion catch-up.
- **Test rigor:** 21-6 added migration upgrade assertions after review — ensure widget tests actually fire ingestion callback (upsert > 0).
- **Epic tracker:** Use `sprint-status-post-audit.yaml`, not legacy `sprint-status.yaml`.

### Git intelligence

Recent Epic 21 commits:
- `0cb5f34` — story 21-6 review + done (database index)
- `550f4b2` — migration v4 implementation
- `84a3495` — story 21-5 review + done (cubit batch goals)

Pattern: small targeted diff + focused tests; sub-task OK-commit gate; commit prefix `feat(cold-start):` or `fix(cold-start):` for orchestration guards.

### Latest tech notes

- **flutter_bloc ^8.x** — no API change; guard is pure Dart conditional before `unawaited`.
- **IndexedStack** keeps Trends widget mounted — guard prevents refresh **calls**, not widget presence (C1 lazy init is future work).
- No new packages.

### Project context reference

- OK-commit gate: sub-task → review brief → Baptiste OK → commit
- Tests: `flutter test --exclude-tags slow`
- Commit convention example: `fix(cold-start): guard Trends refresh on ingestion by active tab (story 21-7)`
- No version bump until Epic 21 closes

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 21-7, AUD-08]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` — §C2 guard pseudo-code, L49 exception]
- [Source: `_bmad-output/implementation-artifacts/stories/21-6-add-end-time-index-for-last-ingestion-query.md` — epic patterns, scope discipline]
- [Source: `_bmad-output/implementation-artifacts/stories/21-1-fast-path-today-refresh-for-cold-start.md` — deferred enrichment context]
- [Source: `lib/presentation/screens/app_scaffold.dart`]
- [Source: `lib/core/services/background_collector.dart`]
- [Source: `test/presentation/screens/app_scaffold_test.dart`]
- [Source: `docs/project-context.md`]

## Dev Agent Record

### Agent Model Used

Claude Sonnet 4.6

### Debug Log References

- `_OneShotStepSource` nécessite 2 lectures (baseline + delta) pour générer ≥1 bucket et déclencher le callback

### Completion Notes List

- AC#1 ✅ — `_historyCubit.refresh` skippé quand `_selectedIndex != 1`
- AC#2 ✅ — refresh maintenu quand `_selectedIndex == 1`
- AC#3 ✅ — `openingTrends` path inchangé, vérifié par test existant + nouveau test Trends
- AC#4 ✅ — `_myDataCubit.refresh` et `_todayCubit.refreshMetadata` restent inconditionnels
- AC#5 ✅ — 853/853 tests passent (`flutter test --exclude-tags slow`)

### File List

- `lib/presentation/screens/app_scaffold.dart`
- `test/presentation/screens/app_scaffold_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

## Change Log

- 2026-07-16: Story context created (ready-for-dev) — ultimate context engine analysis completed
- 2026-07-16: Implementation complete (review) — guard + widget tests, 853/853 ✓
- 2026-07-16: Code review passed — story done
