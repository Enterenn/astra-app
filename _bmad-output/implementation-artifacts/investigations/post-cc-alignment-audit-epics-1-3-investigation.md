# Investigation: Post-CC Alignment Audit — Epics 1–3

## Hand-off Brief

1. **What happened.** Post-CC audit of Epics 1–3 confirms `lib/` implements the corrected passive pipeline (FGS, WM, truth model, evaluator); gaps are documentation drift (Story 2.2 AC), missing device evidence (FR-4, KPI-01), and intentional Epic 4+ deferrals (My Data UI).
2. **Where the case stands.** **Blocked on evidence** — code traceability is sound; Epic 2 cannot close until FR-4 same-day field tests pass on physical Android.
3. **What's needed next.** Execute the FR-4 reproduction plan below on Oppo/reference device; on pass, set `epic-2: done` and resume Epic 4.

## Case Info

| Field            | Value                                                                 |
| ---------------- | --------------------------------------------------------------------- |
| Ticket           | N/A — ad-hoc alignment audit                                          |
| Date opened      | 2026-06-02                                                            |
| Status           | Blocked on evidence                                                   |
| System           | astra-app Phase 0, Flutter, Android reference platform                |
| Evidence sources | PRD, epics.md, UX spec, architecture.md, sprint-change-proposal, sprint-status.yaml, stories 1-1–3-4, lib/, test/ |

## Problem Statement

Verify traceability FR/NFR/UX-DR → stories → `lib/` for Epics 1–3 after Correct Course 2026-06-02. Classify each gap as **intentional (CC)**, **drift**, or **missing**.

## Evidence Inventory

| Source                              | Status    | Notes                                                          |
| ----------------------------------- | --------- | -------------------------------------------------------------- |
| sprint-change-proposal-2026-06-02   | Available | Approved CC; FR-4/SM-2 amended; Stories 2.8–2.10 added       |
| epics.md (Epics 1–3)                | Available | Post-CC Epic 2 intro + 2.8–2.10 AC present                   |
| prd.md                              | Available | FR-4 same-day primary acceptance                                 |
| architecture.md                     | Available | Today Display Truth Model + MonitorDrainSource derogation      |
| sprint-status.yaml                  | Available | epic-2 `in-progress`; 2-8–2-10 `done`; epic-3 `done`           |
| stories 1-1–3-4                     | Available | Story 2-2 Status `review`; Story 2-10 Sub-task F incomplete    |
| lib/                                | Available | 94 Dart files; CC pipeline present                             |
| Physical FR-4 field test results    | Missing   | CC Section 5 success criteria all unchecked                    |

## Alignment Matrix — Epics 1–3

Legend: ✅ aligned | ⚠️ gap (see classification)

### Epic 1 — Trust Onboarding & App Shell

| Req ID   | Story        | lib/ anchor                                      | Verdict | Gap class   | Notes |
| -------- | ------------ | ------------------------------------------------ | ------- | ----------- | ----- |
| FR-9     | 1-4          | `user_preferences_repository.dart`, migrations   | ✅      | —           | |
| FR-22    | 1-5          | `onboarding_flow.dart`                           | ✅      | —           | |
| FR-23    | 1-5          | `onboarding_goal_page.dart`                      | ✅      | —           | Goal edit on My Data → Epic 4 (intentional) |
| FR-24    | 1-5          | `onboarding_permissions_page.dart`               | ✅      | —           | |
| UX-DR1–3 | 1-2          | `astra_colors.dart`, typography, spacing, theme  | ✅      | —           | |
| UX-DR4   | 1-3          | `app_scaffold.dart`                              | ✅      | —           | |
| UX-DR16  | 1-5          | `onboarding_flow.dart`                           | ✅      | —           | |
| UX-DR17  | 1-5          | `astra_button.dart`                              | ✅      | —           | |
| UX-DR18  | 1-3          | `app_scaffold.dart` cross-fade                   | ✅      | —           | |
| UX-DR22  | — (Epic 4.7) | `theme_cubit.dart` tokens only; no selector UI | ⚠️      | **CC**      | ThemeSelector deferred Epic 4; tokens + system default in Epic 1 |
| NFR-2    | 1-1          | —                                                | ⚠️      | **missing** | No release artifact size measurement in repo |
| NFR-3    | 1-1          | offline by design                                | ✅      | —           | FR-18 manifest test is Epic 7 |
| NFR-5    | 1-2          | tokens + reduce-motion in widgets                | ⚠️      | **CC**      | WCAG AA verification deferred Epic 5 / beta checklist |
| NFR-6    | 1-5          | English UI                                       | ✅      | —           | |
| My Data tab | 1-3       | `my_data_screen.dart` placeholder                | ⚠️      | **CC**      | Epic 4 scope; not a drift |

### Epic 2 — Passive Step Tracking & Today Dashboard

| Req ID        | Story   | lib/ anchor                                           | Verdict | Gap class   | Notes |
| ------------- | ------- | ----------------------------------------------------- | ------- | ----------- | ----- |
| FR-1          | 2-2     | `data_ingestion_source.dart`, sources                 | ⚠️      | **drift**   | AC says `PhonePedometerSource` in `AppDependencies.ingestionSources`; runtime uses `MonitorDrainSource` — **architecture.md:444 documents CC derogation; story/epics AC not updated** |
| FR-2          | 2-2     | `phone_pedometer_source.dart`, `step_normalizer.dart` | ✅      | —           | Used in FGS/WM isolates + LiveStepMonitor |
| FR-3          | 2-2     | `adp_ble_source.dart`                                 | ✅      | —           | |
| FR-4          | 2-4,2-8 | FGS + WM + collector                                  | ⚠️      | **missing** | Code present; **same-day passive field test not evidenced** (CC Section 5 unchecked) |
| FR-6          | 2-4,2-8 | manifest + FGS health                                 | ✅      | —           | |
| FR-7, FR-8    | 2-1     | migrations, schema                                    | ✅      | —           | |
| FR-10         | 2-1     | migrations                                            | ✅      | —           | |
| FR-14, FR-15  | 2-5,2-6 | `goal_ring.dart`, `goal_celebration.dart`            | ✅      | —           | |
| FR-25         | 2-7     | `notification_service.dart`, collector hook           | ✅      | —           | |
| UX-DR5–7      | 2-5     | goal ring, source chip                                | ✅      | —           | |
| UX-DR6        | 2-6     | `goal_celebration.dart`                               | ✅      | —           | |
| UX-DR8        | 2-5     | `status_banner.dart` compact on Today                 | ⚠️      | **CC**      | Full + iOS info variants deferred Epic 4.2; `staleFull` stub exists unused |
| ARCH-TDTM     | 2-9     | `today_cubit.dart`, `app.dart`                        | ✅      | **CC**      | Threshold persist reverted (confirmed absent in lib/) |
| Story 2-8     | 2-8     | `fgs_step_collection.dart`, `health_foreground_*`     | ✅      | **CC**      | New CC story; implemented |
| Story 2-9     | 2-9     | `live_step_monitor.dart`, `monitor_drain_source.dart`   | ✅      | **CC**      | Tests: `today_cubit_test.dart`, `app_live_pipeline_lifecycle_test.dart` |
| Story 2-10    | 2-10    | `background_health_capability_evaluator.dart`         | ⚠️      | **drift**   | Evaluator wired in DI; **Sub-task F physical WM/OEM verification open** in story file but sprint-status `done` |
| FR-5 exposure | 2-10    | evaluator in DI, no presentation consumer             | ⚠️      | **CC**      | Intentional — Epic 4.2 `BackgroundStatusCard` |
| Story 2-2 status | 2-2  | —                                                     | ⚠️      | **drift**   | Story file `Status: review`; sprint-status `done` |
| epic-2 status | —       | sprint-status `in-progress`                           | ⚠️      | **CC**      | All stories `done` but CC success criteria + field tests pending |

### Epic 3 — History & Trends

| Req ID   | Story | lib/ anchor                                      | Verdict | Gap class | Notes |
| -------- | ----- | ------------------------------------------------ | ------- | --------- | ----- |
| FR-16    | 3-2,3-3 | `step_repository.dart`, `step_bar_chart.dart` | ✅      | —         | |
| FR-17    | 3-3   | `trend_chip.dart`                                | ✅      | —         | |
| FR-28    | 3-1   | `dev/data_inject_service.dart`, lifecycle sim    | ✅      | —         | kDebugMode only |
| NFR-1    | 3-4   | `dev/chart_benchmark.dart`                       | ⚠️      | **missing** | Harness exists; **no CI/device p95 record** attached to beta checklist |
| NFR-7/8  | 3-1   | dev compaction simulator                         | ⚠️      | **CC**    | Production `DataLifecycleService` is Epic 4; dev preview intentional |
| UX-DR9   | 3-3   | `period_toggle.dart`, `step_bar_chart.dart`      | ✅      | —         | |
| UX-DR10  | 3-3   | `trend_chip.dart`                                | ✅      | —         | |
| UX-DR19  | 3-3   | Semantics on chart + toggle                      | ✅      | **CC**    | Explicitly "partial" per story AC — full a11y Epic 5 |

## Confirmed Findings

### Finding 1: CC pipeline implemented in lib/

**Evidence:** `lib/core/services/fgs_step_collection.dart:13`, `background_health_capability_evaluator.dart:8`, `today_cubit.dart:198-218`, no `onPersistRequested` in lib/

**Detail:** Stories 2.8–2.10 deliverables exist. Threshold RAM persist explicitly absent (CC revert).

### Finding 2: MonitorDrainSource replaces PhonePedometerSource in UI collector DI

**Evidence:** `lib/core/di/app_dependencies.dart:106-107`; `architecture.md:444`

**Detail:** Approved CC derogation for live pipeline. Story 2.2 AC #1 and epics.md Story 2.2 AC still describe old registration — documentation drift, not code regression.

### Finding 3: Sprint-status vs story-file inconsistencies

**Evidence:** `sprint-status.yaml:72-74` all `done`; `stories/2-2-*.md:3` Status `review`; `stories/2-10-*.md:80-84` Sub-task F open

**Detail:** Tracking artifacts disagree on closure criteria.

### Finding 4: FR-4 field validation not recorded

**Evidence:** `sprint-change-proposal-2026-06-02.md:155-159` — all success criteria unchecked

**Detail:** Cannot confirm passive contract at product level despite code implementation.

## Deduced Conclusions

### Deduction 1: Epic 2 should remain in-progress until field tests pass

**Based on:** Finding 4, CC Section 5

**Reasoning:** CC explicitly pauses Epic 4+ until Epic 2 correction validated on device. All stories marked done reflects dev completion, not product acceptance.

**Conclusion:** `epic-2: in-progress` in sprint-status is correct; marking epic done now would be premature.

### Deduction 2: Most Epic 1–3 "gaps" in My Data / theme selector / full stale UI are intentional CC deferrals

**Based on:** CC proposal Section 2 artifact conflicts; epics FR Coverage Map

**Conclusion:** Not missing implementation errors — scope boundaries to Epic 4+.

## Hypothesized Paths

### Hypothesis 1: FR-4 same-day passive works on Baptiste's Oppo device post 2.8–2.10

**Status:** Open

**Would confirm:** CC Section 5 walk test ≥30 min app closed → Today increases within 15 min

**Would refute:** Steps flat after FGS+WM cycle; visible backward jump within local day

### Hypothesis 2: Story 2-2 remains in `review` because AC #1 text was never amended post-CC

**Status:** Confirmed

**Resolution:** architecture.md documents derogation; story AC stale.

## Missing Evidence

| Gap                         | Impact                          | How to Obtain                          |
| --------------------------- | ------------------------------- | -------------------------------------- |
| FR-4 same-day field test    | Epic 2 product closure          | CC Section 5 protocol on physical device |
| Story 2-10 Sub-task F       | WM spike + OEM evaluator log    | Run on Oppo CPH2663 per story checklist |
| KPI-01 p95 on reference device | NFR-1 / FR-16 acceptance   | `lib/dev/chart_benchmark.dart` on mid-range Android |
| NFR-2 APK size              | Epic 1 NFR                      | Release build measurement              |

## Final Conclusion

**Confidence:** **Medium** (traceability audit) · **Low** (FR-4 product acceptance until field tests run)

### Confirmed

- Epics 1–3 requirements trace to implemented `lib/` code for all dev-delivered stories.
- CC deliverables (Stories 2.8–2.10, Today Display Truth Model, threshold persist revert) are present in code with unit/widget test coverage for lifecycle/monotonic paths.
- Epic 1 and Epic 3 are **implementation-complete** for their scoped FR/NFR/UX-DR; deferred items (My Data, ThemeSelector, full stale UI, production lifecycle) are **intentional CC scope boundaries** to Epic 4+.

### Open (blocks Epic 2 closure)

- FR-4 same-day passive accumulation — no recorded field test result.
- Story 2-10 Sub-task F — physical WM spike + OEM evaluator log not evidenced.
- KPI-01 p95 on reference device — harness exists, no archived pass log.

### Drift (non-blocking, fix in docs)

- Story 2.2 AC #1 / epics.md still describe `PhonePedometerSource` in UI `AppDependencies.ingestionSources`; runtime uses `MonitorDrainSource` per `architecture.md:444`.
- Story 2.2 file `Status: review` vs sprint-status `done`; Story 2-10 Sub-task F open vs sprint `done`.

## Fix Direction

| Category | Item | Mechanism |
| -------- | ---- | --------- |
| **Drift** | Story 2.2 + epics AC #1 | Amend AC to document UI `MonitorDrainSource` + FGS/WM `PhonePedometerSource` split; set story status `done` |
| **Drift** | Story 2-10 tracking | Complete Sub-task F on device or reopen story in sprint-status |
| **Missing** | FR-4 acceptance | Run reproduction plan below; record in CC proposal + story 2-4/2-8 Dev Agent Records |
| **Missing** | KPI-01 / NFR-1 | Run `lib/dev/chart_benchmark.dart` on mid-range Android; archive p95 log |
| **CC (defer)** | My Data, FR-5/31, UX-DR8/11/12/22 | Epic 4 — no action in Epics 1–3 scope |

## Diagnostic Steps (if FR-4 fails)

1. **Check FGS notification** visible in shade when app backgrounded (Story 2.8) — if absent, inspect battery optimization / OEM kill.
2. **Run evaluator** — temporary debug log of `AppDependencies.backgroundHealthCapabilityEvaluator.evaluate()` → check `likelyOemBatteryDeferral`, `batteryOptimizationExempt`.
3. **Inspect SQLite** via dev tools or `adb` — confirm `timeseries_samples` rows written during background walk (WM/FGS isolate writes).
4. **Check monotonic display** — if DB grows but Today flat, bug is in truth model (Story 2.9); if DB flat, bug is passive pipeline (Stories 2.8/2.10).
5. **Force-stop test** — expect lag until foreground backfill; **not** a beta failure per CC.

## Reproduction Plan — FR-4 Same-Day Passive (Epic 2 closure gate)

**References:** `sprint-change-proposal-2026-06-02.md` Section 5, `prd.md` FR-4, `epics.md` Story 2.4 AC, CC field tests A/B/C from discovery context.

**Device:** Physical Android (reference: Oppo CPH2663 or equivalent). **Build:** debug or release with activity permission granted. **Do not** force-stop from Settings during primary test.

### Prerequisites

- [ ] Onboarding complete; activity recognition granted
- [ ] Note baseline Today step count **T₀** and local time
- [ ] Optional: enable `adb logcat` filter on `astra_app` / WorkManager / FGS tags for failure diagnosis
- [ ] Battery optimization: note whether app is exempt (affects Story 2-10 OEM path, not primary pass/fail if FGS runs)

### Test P1 — Same-day passive (FR-4 primary · CC success criterion #1)

| Step | Action | Record |
| ---- | ------ | ------ |
| 1 | Open app → Today tab; record **T₀** | |
| 2 | Home button or recents — **background** app (do **not** swipe away aggressively if that force-stops on your OEM) | |
| 3 | Walk **≥500 steps** over **≥30 minutes** without reopening app | wearable/phone step counter as ground truth |
| 4a | Wait **≤15 min** after walk ends; reopen Today | record **T₁**, Δ = T₁−T₀ |
| 4b | *Or* reopen immediately after walk | record **T₁** on next open |
| **Pass** | Δ ≥ **80%** of walked steps (PRD FR-4 OEM variance allowance) **and** no visible backward jump vs last seen Today count | |
| **Fail** | Δ ≈ 0 with confirmed walk; or count decreases within same local day | → Diagnostic Steps |

### Test P2 — Live bonus (CC success criterion #2 · field test A)

| Step | Action | Pass |
| ---- | ------ | ---- |
| 1 | App foreground on Today | |
| 2 | Walk ~100 steps with screen on | Step count updates in **real time** (LiveStepMonitor overlay) within ~5s |

### Test P3 — App-switch resume (CC field test B · Story 2.9)

| Step | Action | Pass |
| ---- | ------ | ---- |
| 1 | Note **T₀** on Today | |
| 2 | Switch to another app 2–5 min; walk ~200 steps | |
| 3 | Return to ASTRA Today within 5s | **T₁ ≥ T₀**; live stream recovers without force-stop |

### Test P4 — No backward jump (CC success criterion #3)

| Step | Action | Pass |
| ---- | ------ | ---- |
| 1 | Throughout P1–P3 same local day | Today count **never decreases** except local midnight rollover |

### Test P5 — FGS active when backgrounded (CC success criterion #4 · Story 2.8)

| Step | Action | Pass |
| ---- | ------ | ---- |
| 1 | Background app after P1 step 2 | Persistent notification visible (health FGS) **or** SQLite buckets written within 15 min (Test P1 pass implies this) |

### Test P6 — Evaluator operational (CC success criterion #5 · Story 2.10)

| Step | Action | Pass |
| ---- | ------ | ---- |
| 1 | Debug: log `evaluate()` snapshot once | All fields populated; `likelyOemBatteryDeferral` plausible for device |

### Test S1 — Force-stop limit (documented · not beta failure)

| Step | Action | Expected |
| ---- | ------ | -------- |
| 1 | Force-stop from Settings | |
| 2 | Walk ≥200 steps | |
| 3 | Reopen app | Steps **eventually** recover via foreground backfill; lag acceptable per CC |

### Test S2 — Morning check (FR-4 secondary)

| Step | Action | Pass |
| ---- | ------ | ---- |
| 1 | Do not open app overnight; walk before first open | |
| 2 | First open of local day | Today **> 0** if sensor recorded steps overnight |

### Test S3 — 24h stress (SM-2 long-run · optional, not Epic 2 closure gate)

| Step | Action | Pass |
| ---- | ------ | ---- |
| 1 | App not opened 24h; normal background (no force-stop) | Step count increases vs prior day baseline |

### Evidence to capture

- Screenshot Today T₀ / T₁ with timestamps
- Walk ground truth (phone health app or pedometer)
- Pass/fail table copied into `sprint-change-proposal-2026-06-02.md` Section 5 checkboxes
- On failure: logcat excerpt + evaluator snapshot + last `timeseries_samples` row timestamp

### Closure criteria

When **P1–P6 pass** on reference Android:

1. Check CC proposal Section 5 boxes
2. Set `epic-2: done` in `sprint-status.yaml`
3. Remove PAUSE note for Epic 4+
4. Resume Epic 4 story creation

If **P1 fails** but P2–P4 pass → reopen Stories 2.8 and/or 2.10 (`bmad-quick-dev`), not Epic 3.

## Recommended Next Steps

| Priority | Action | Skill |
| -------- | ------ | ----- |
| **1** | Execute FR-4 reproduction plan on physical device | Manual (Baptiste) |
| **2** | On pass: close Epic 2, resume Epic 4 | `bmad-correct-course` or sprint-status update |
| **3** | Patch Story 2.2 / epics AC drift | `bmad-quick-dev` (docs-only) or manual edit |
| **4** | Archive KPI-01 benchmark log | `bmad-quick-dev` + dev FAB harness |
| **5** | Optional: adversarial review of passive pipeline | `bmad-code-review` |

## Side Findings

- `BackgroundHealthCapabilityEvaluator` is constructed in `AppDependencies` but has **zero presentation-layer consumers** — expected pre-Epic 4.2.
- `StatusBannerVariant.staleFull` implemented but only Today compact variant is used — stub ready for Epic 4.2.
