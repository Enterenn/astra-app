# Deferred Work

## Deferred from: code review of 1-1-flutter-project-initialization (2026-05-25)

- **Plugin manifest permissions not wired** — workmanager, pedometer, flutter_local_notifications require manifest/Gradle/iOS capability changes; intentionally out of scope for Story 1.1 (Epic 2).

- **Legacy Kotlin Gradle Plugin warnings** — **Resolved in Epic 5 Story 5.5** (2026-06-03). Workaround flags removed; three plugins patched via `scripts/patch_kgp_plugins.*` until upstream releases. See `docs/DEPENDENCIES.md` § Android Built-in Kotlin / KGP.

## Deferred from: code review of 1-2-design-tokens-and-theme-system (2026-05-28)

- **Unrelated `.gitignore` JetBrains entries** — `.idea/` and `*.iml` bundled with story 1-2; useful housekeeping but out of story scope.

- **Preview screen safe-area / text-scale / overflow edge cases** — temporary screen until Story 1.3; fixed 48dp button height may clip at high text scale; scroll body lacks bottom safe-area inset.

- **Partial Material 3 ColorScheme role mapping** — only primary/surface/error/outline set; secondary/tertiary/surfaceContainer roles use framework defaults until M3 stock widgets are used.

- **`copyWith` and mid-range `lerp` tests** — ThemeExtension boilerplate; t=0/t=1 lerp covered; mid-range and wrong-type paths deferred.

- **No widget tests asserting bundled font families** — fonts registered in pubspec but not verified in widget tests.

- **No dedicated unit tests for `astra_theme`, `astra_spacing`, `astra_typography`** — coverage via colors/cubit/widget smoke tests only.

- **AC #2 OS brightness toggle automated test** — spec explicitly requires manual verification; no widget test for platformBrightness changes.

## Field feedback triage (2026-06-03) — Baptiste device pass

### Sequencing decision (2026-06-03, Baptiste)

**Order:** Epic **5** (polish) → Story **6.3** beta acceptance checklist (surface more issues) → **consolidated debug/hotfix pass** (Epic 2/4 regressions below).

Do **not** open hotfix stories before 6.3 unless a blocker prevents running the checklist on release APK.

### Mapped to Epic 5 (polish — ship before hotfix)

| Item | Target story | Notes |
|------|--------------|-------|
| ~~Hello greeting too small / not bold~~ | **Superseded (5.9, 2026-06-04)** | Greeting removed — ring is sole hero; do not restore |
| Donut + chart bars green when goal met | **5.8** (+ AC in epics.md) | Semantic `status.ok` for goal-met days — **done in 5.8** |

### Deferred hotfix batch (post–6.3) — checklist + debug pass

| Item | Suggested track | Notes |
|------|-----------------|-------|
| No goal notification when goal reached in background | **2.7** re-open or **2.x hotfix** | See repro below; onboarding must request notification permission (Baptiste); **verify grant status** on 6.3 checklist run |
| Today steps: reopen OK, then **decrease after kill+reopen** | **2.x hotfix** (e.g. 2-11) | See repro below; P0 for post-6.3 pass |
| Purge fails (2/2 attempts) | **4.5** re-open or **4.x hotfix** | "Purge could not be completed. Try again." |
| "Last sync 30 minutes ago" vs 60s persist | **6.3** checklist item + optional **4.2** copy | Educate: last **ingestion**, not 60s timer |

### Device repro — walk session (2026-06-03)

1. **During walk:** app **fully killed** (swipe away / force stop).
2. **Mid-walk reopen:** opened app to check progress → UI showed **goal already passed** → **no goal local notification** (FR25 failure; permission granted).
3. **End of walk:** phone **screen off**, app **still running** (process alive, not killed) → **no spurious step inflation** (good).
4. **At home:** **killed app again** and reopened → **displayed step count went down** (monotonicity / cold-start regression).

**Implications for investigation (post-6.3):**

- Notification: goal visible in SQLite on reopen but notify path (WM/FGS/cold-start `enableGoalNotification: true`) did not fire when goal crossed while killed; may also need eval on first collect after kill.
- Step decrease: failure on **second** kill+reopen after a session that included foreground + screen-off — not only "stale until refresh"; overlaps 2.9 truth model / reconcile / cold-start ordering.

### Discuss only (not a beta-user story)

| Item | Notes |
|------|-------|
| History FAB "KPI-01 running (50 iterations…)" | **Debug-only** (`kDebugMode` + `ChartBenchmarkDevFab`). Not in release APK. `Database_closed` = dev benchmark touching DB while app lifecycle closes DB — ignore for beta; optional dev-tool hardening later |

## Deferred from: remove-today-stale-banner one-shot (2026-06-05)

- **`TodayState.isStale` computed but not surfaced in UI** — stale ingestion still tracked in cubit; no in-app stale UX after banner removal. Needs product decision (ring hint, snackbar, Profile, or restore a Data surface).

- **`StatusBannerVariant.staleCompact` / `staleFull` unused in production** — enum variants and widget tests remain as stubs; delete or wire when stale UX is redesigned.

- **Story AC / UX docs still reference Today compact stale → My Data** — stories 5.9, 4.2 and UX §2.3 need amendment to match 5.10 sovereignty layout pivot.
