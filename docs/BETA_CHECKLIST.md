# ASTRA Phase 0 Beta Acceptance Checklist

**Purpose:** Objective verification of Phase 0 exit criteria before sharing the OSS beta.  
**Rule:** **100% pass** required on **release APK** for Phase 0 exit (SM-7). Failures are logged — do not waive silently.  
**Owner:** Baptiste (builder) + ≥1 external beta tester for airplane-mode protocol.  
**Prerequisite:** Stories 7.1–7.2 done; Epic 5.12 visual cohesion sign-off done. Story 6.6 (midnight rollover) should be **done** before field execution.

**Related:** [README airplane protocol](../README.md#airplane-mode-protocol-privacy-proof) · [deferred-work.md](../_bmad-output/implementation-artifacts/deferred-work.md) · [kpi-01-regression-log.md](../_bmad-output/implementation-artifacts/kpi-01-regression-log.md)

---

## How to run

1. **Build release APK:** `flutter build apk --release`  
   Artifact: `build/app/outputs/flutter-apk/app-release.apk`
2. **Automated gates first** (section below) — all must pass before device session.
3. **Install on physical Android** reference device; grant `ACTIVITY_RECOGNITION` + `POST_NOTIFICATIONS` during onboarding.
4. Work through **Functional**, **Visual**, **Field regressions**, and **OSS / release** sections in order.
5. Mark **Pass** / **Fail** in the **Notes** column; log device model, Android version, build type, and APK version for every failure.
6. Copy KPI-01 row from [kpi-01-regression-log.md](../_bmad-output/implementation-artifacts/kpi-01-regression-log.md) when V-7 benchmark is run.
7. On **100% pass:** Phase 0 exit gate satisfied. On any fail: list failed IDs → consolidated hotfix pass per deferred-work (do **not** mark Phase 0 exit).

**Phase 0 closed 2026-06-08 (Baptiste):** Story 7.3 and Epic 7 **done**. Field pass **36/39** with documented waivers (REL-01 size, AUTO-03/04 flakes, FUNC-12/REL-03 deferred). OSS sideload beta gate satisfied.

---

## Automated gates

Run from repo root on the same commit as the release build.

| ID | Check | FR / UX / SM | How to verify | Pass | Notes |
|----|-------|--------------|---------------|------|-------|
| AUTO-01 | Release manifest — no INTERNET | FR-18 | `flutter test test/release_manifest_test.dart` | ✅ | 3/3 pass (2026-06-08, CI) |
| AUTO-02 | Step counter reset handling | FR-2 | `flutter test test/data/datasources/step_normalizer_test.dart` (case: `handles counter reset`) | ✅ | 11/11 pass (2026-06-08, CI) |
| AUTO-03 | Full regression suite | SM-7 | `flutter test` — triage pre-existing flakes in execution log | ✅ | 627 pass, 6 pre-existing flakes — **waived** non-blocking Phase 0 beta (Baptiste 2026-06-08) |
| AUTO-04 | Static analysis | NFR-6 | `flutter analyze` — zero issues | ✅ | Info/warnings préexistants — **waived** non-blocking Phase 0 beta (Baptiste 2026-06-08) |

---

## Functional (release APK, manual)

| ID | Check | FR / UX / SM | How to verify | Pass | Notes |
|----|-------|--------------|---------------|------|-------|
| FUNC-01 | Background persistence without opening app | FR-4, FR-6, SM-2 | Walk with app in background or force-stopped after first launch; reopen without foreground-only session → steps advanced vs baseline. See Story 2.4/2.8 deferred acceptance notes in [DEPENDENCIES.md](./DEPENDENCIES.md). | ✅ | Baptiste 2026-06-08 |
| FUNC-02 | Goal local notification once/day | FR-25 | See **REG-01** for full repro. Toggle on Profile; OS notification permission granted. **No notification when app is open** (celebration only); notify in background before reopen. | ✅ | Baptiste 2026-06-08 — pass après hotfix `4a92db0` (dedup séparé, toggle Profile, background-only) |
| FUNC-03 | Storage footprint visible + reasonable | FR-5, FR-13, NFR-7 | Dev inject 90d (`lib/dev/`) or natural use → **Data** tab shows footprint; value plausible (< 50 MB/year design target). | ✅ | Baptiste 2026-06-08 |
| FUNC-04 | CSV export OW-aligned columns | FR-19 | **Data** → Export CSV → open file; columns match [SERIES_TYPES.md](./SERIES_TYPES.md) / [OPEN_WEARABLES_ALIGNMENT.md](./OPEN_WEARABLES_ALIGNMENT.md). | ✅ | Baptiste 2026-06-08 |
| FUNC-05 | CSV import idempotency spot-check | FR-30 | Import same file twice → no duplicate bucket explosion; Today/Trends stable. | ✅ | Baptiste 2026-06-08 |
| FUNC-06 | Purge → 0 samples, goal retained | FR-20, FR-21, D-11 | **Data** → Delete all local data → confirm dialog mentions export (V-12); samples = 0; daily goal still on Profile/Today. | ✅ | Baptiste 2026-06-08 |
| FUNC-07 | 24h airplane mode | FR-18, SM-3 | Follow [README § Airplane mode protocol](../README.md#airplane-mode-protocol-privacy-proof) on **release** APK. Re-use Story 7.2 Task D evidence or re-run. | ✅ | Baptiste 2026-06-08 |
| FUNC-08 | CSV round-trip | FR-30 | Export → purge samples → import → Today + Trends reconcile with pre-purge totals. | ✅ | Baptiste 2026-06-08 |
| FUNC-09 | Theme survives purge; system default on fresh install | FR-31, V-1, V-9 | After purge: theme/accent unchanged. Fresh install: follows system theme, no wrong-theme flash. | ✅ | Baptiste 2026-06-08 |
| FUNC-10 | Onboarding once only | FR-22–24, V-10 | Fresh install → intro headline **Your Health. Your Phone. Period.** visible → tap **Continue** → OS activity dialog (grant or deny) → weight step (optional Skip) → height **Let's Go** → app shows Steps tab → force-stop → relaunch → onboarding does not reappear. If denied: Steps shows permission empty state, not onboarding. | ✅ | Baptiste 2026-06-08 · **Epic 13 redesign — re-verify on release APK before next beta gate** |
| FUNC-11 | Derived metrics on Today | FR-33 | Today shows distance / walking time / kcal when steps > 0 (Epic 6). | ✅ | Baptiste 2026-06-08 |
| FUNC-12 | Midnight day rollover | Story 6.6 | Steps flush at local midnight; UI resets for new day; no ghost prior-day total on Today ring. Manual if not covered by automated tests. | ⏳ | **Post-close verification** — test minuit ce soir (Baptiste); hotfix si échec — hors gate story 7.3 |
| FUNC-13 | Last sync copy vs persist cadence | deferred-work | **Data** "last sync" reflects last **ingestion**, not 60s UI timer — footnote only, not a pass/fail blocker unless copy is misleading. | ✅ | Baptiste 2026-06-08 — **Data last sync removed** (copy N/A) |

---

## Visual polish (UX §4.7 — Epic 5.12 prerequisite)

Epic 5.12 cohesion sign-off is **done** — this section is the beta re-verification pass (FR-29, UX-DR21).

| ID | Check | FR / UX | Pass criteria | Pass | Notes |
|----|-------|---------|---------------|------|-------|
| VIS-01 | V-1 Theme default | FR-31, V-1 | System on first launch; no wrong-theme flash; light and dark palettes verified | ✅ | Baptiste 2026-06-08 |
| VIS-02 | V-2 Token consistency | V-2 | All screens use `AstraColors` tokens — no hardcoded hex in widgets | ✅ | Baptiste 2026-06-08 |
| VIS-03 | V-3 Typography | V-3 | Figtree + Darker Grotesque only; no system font fallback unless bundle fail | ✅ | Baptiste 2026-06-08 |
| VIS-04 | V-4 Tab cohesion | V-4 | 4 tabs (TODAY, TRENDS, DATA, PROFILE) — same floating pill bar, accent active squircle | ✅ | Baptiste 2026-06-08 |
| VIS-05 | V-5 Today hero | V-5 | Ring + count + chip aligned center; no layout jump on sync | ✅ | Baptiste 2026-06-08 |
| VIS-06 | V-6 GoalCelebration | V-6 | Plays once/day; reduce-motion variant tested | ✅ | Baptiste 2026-06-08 |
| VIS-07 | V-7 History perf | V-7, KPI-01 | Chart bind p95 < 100 ms with 90d inject — copy row from [kpi-01-regression-log.md](../_bmad-output/implementation-artifacts/kpi-01-regression-log.md) | ✅ | Baptiste 2026-06-08 — subjective pass on device; KPI-01 formal row still empty |
| VIS-08 | V-8 My Data hierarchy | V-8 | Background → Footprint → Your data; goal/theme/display name on Today/Profile | ✅ | Baptiste 2026-06-08 — **Data et Profile sont 2 onglets différents** (4-tab shell; goal/theme/display name on Profile, not Data) |
| VIS-09 | V-9 Purge empty state | V-9, D-11 | 0 samples, goal retained, no ghost data on Today | ✅ | Baptiste 2026-06-08 |
| VIS-10 | V-10 Onboarding once | V-10 | Intro trust copy before OS activity dialog on Continue; 3-step flow (intro → weight → height); no re-show after complete; if permission denied, Steps empty state not onboarding | ✅ | Baptiste 2026-06-08 · **Epic 13 redesign — re-verify on release APK before next beta gate** |
| VIS-11 | V-11 Stale banner | V-11 | **Exception:** Today compact stale banner removed; Data may show full stale banner when >12h | ✅ | Baptiste 2026-06-08 |
| VIS-12 | V-12 Destructive clarity | V-12 | Purge dialog mentions export; danger color on confirm only | ✅ | Baptiste 2026-06-08 |
| VIS-13 | V-13 Screenshot readiness | V-13, SM-7 | Today + My Data framable for README GIF — see **REL-03** | ⏳ | **Deferred** — GIF non requis pour clôture story 7.3; capture quand prêt |

---

## Field regressions (2026-06-03 device pass)

Explicit repro cases from Baptiste field session. Log **Device | Android | Build | APK version** on every failure.

| ID | Check | FR / UX | How to verify | Pass | Notes |
|----|-------|---------|---------------|------|-------|
| REG-01 | E1 Notification — killed during walk | FR-25 | App **killed** during walk → reopen after goal crossed → **notification permission granted in OS** → exactly **one** notification same day | ✅ | Baptiste 2026-06-08 — **résolu** vs session 2026-06-03; aligné FUNC-02 post-hotfix |
| REG-02 | E2 Walk monotonicity | FR-2, Story 2.9 | Kill mid-walk → reopen OK (goal may show met). Screen-off with app alive → **no spurious steps**. **Kill+reopen at home** → count must **not decrease** | ✅ | Baptiste 2026-06-08 — **résolu** vs session 2026-06-03 |
| REG-03 | E3 Purge reliability | FR-20 | **Two consecutive** "Delete all local data" succeed on release build after typical session | ✅ | Baptiste 2026-06-08 — **résolu** vs session 2026-06-03 |
| REG-04 | E4 Post-purge empty state | FR-20, D-11 | Today ring 0, Trends empty, Data footprint 0, goal preference retained on Profile | ✅ | Baptiste 2026-06-08 |

---

## OSS / release gates

| ID | Check | FR / SM / NFR | How to verify | Pass | Notes |
|----|-------|---------------|---------------|------|-------|
| REL-01 | Install size < 50 MB | NFR-2, SM-6 | `Get-Item build/app/outputs/flutter-apk/app-release.apk \| Select Length` — threshold **< 52_428_800 bytes (50 MB)**. Story 7.2 logged **51.0 MB** — record actual bytes; if ≥ 50 MB, fail unless explicit waiver in execution log + open size-reduction follow-up | ✅ | Baptiste 2026-06-08 — **53_508_011 bytes (~52 MB)** fat APK; **waived** acceptable for Phase 0 OSS beta. Post-beta optimization deferred (see below). |
| REL-02 | Version baseline | AC-7 | `pubspec.yaml` `version: 0.1.0+1`; Profile footer shows `ASTRA v0.1.0 (1)`; matches `aapt dump badging build/app/outputs/flutter-apk/app-release.apk` → `versionName='0.1.0'` `versionCode='1'` | ✅ | Baptiste 2026-06-08 |
| REL-03 | README demo GIF | SM-7, V-13 | Capture steps documented below; embed `docs/assets/demo.gif` (or README-relative path). **Capture is manual** — checklist item passes when GIF exists and is README-embeddable | ⏳ | **Deferred** — steps documentés (AC #6); capture README hors gate story 7.3 |
| REL-04 | External tester — airplane mode | SM-7 | ≥1 proche completes [airplane mode protocol](../README.md#airplane-mode-protocol-privacy-proof) on **release** APK; log tester alias + device in execution log | ✅ | Baptiste 2026-06-08 |
| REL-05 | OSS docs bundle linked | FR-27, FR-29 | README + [docs/README.md](./README.md) link this checklist, LICENSE, DEPENDENCIES, REGULATORY_POSITION | ✅ | Baptiste 2026-06-08 |

### REL-03 Demo GIF capture steps (manual)

1. Release or profile build with representative data (dev inject 7d visible on Trends).
2. Record: Today ring approaching/filling goal → optional celebration → **Data** → Export CSV.
3. Target: < 5 MB GIF, width ~360–400px for README embed.
4. Save to `docs/assets/demo.gif` (create folder if needed).
5. Note reduce-motion variant if celebration animation differs.

### REL-01 Size check commands

**PowerShell:**

```powershell
(Get-Item build/app/outputs/flutter-apk/app-release.apk).Length
```

**Badging (version verify):**

```bash
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | findstr version
```

**REL-01 waiver rationale (Baptiste 2026-06-08):** ~52 MB universal APK is acceptable for sideload beta. NFR-2 strict under-50 MB target deferred — not a Phase 0 exit blocker.

**Post-beta size optimization (deferred follow-up story):**

| Lever | Command / action | Expected gain |
|-------|------------------|---------------|
| ABI split (sideload) | `flutter build apk --release --split-per-abi` — distribute **arm64-v8a** only | −15 to −25 MB vs fat APK |
| R8 + shrink | `isMinifyEnabled` + `isShrinkResources` in `android/app/build.gradle.kts` release | −1 to −5 MB |
| App Bundle | `flutter build appbundle` (Play Store later) | Per-device optimized delivery |
| Obfuscate + split debug info | `--obfuscate --split-debug-info=build/symbols` | Minor APK reduction |

---

## Execution log

| Date | Runner | Device | Android | Build | APK version | Pass rate | Failed IDs | Blockers / waivers |
|------|--------|--------|---------|-------|-------------|-----------|------------|-------------------|
| 2026-06-08 | Baptiste | Oppo CPH2663 (reference) | Android 14+ | release | 0.1.0 (1) | **36/39** — **Phase 0 exit** | — | Story 7.3 + Epic 7 **done**. Waivers: REL-01 ~52 MB, AUTO-03/04 flakes. Post-close: FUNC-12, REL-03 GIF. Hotfixes `4a92db0`, `19240bc`. |

### KPI-01 (VIS-07) device row

Copy from [kpi-01-regression-log.md](../_bmad-output/implementation-artifacts/kpi-01-regression-log.md) when benchmark completes:

| Date | Device | Android | Profile | Rows | p50 (ms) | p95 (ms) | Pass | Git SHA | Notes |
|------|--------|---------|---------|------|----------|----------|------|---------|-------|
| — | — | — | — | — | — | — | — | — | VIS-07 pass subjectif device; benchmark formel pas encore loggé |

---

## Phase 0 exit criteria summary (SM-7)

- [x] **Story 7.3 deliverable** — `BETA_CHECKLIST.md`, version baseline, field execution log (2026-06-08) — **done**
- [x] ≥1 external tester completed airplane mode on release build (REL-04)
- [x] Install size recorded; NFR-2 waived (REL-01) — 53_508_011 B (~52 MB)
- [x] **Phase 0 OSS beta gate** — signed off 2026-06-08 (waivers documented; FUNC-12/REL-03 post-close)
- [ ] README demo GIF (REL-03) — **post-close** (not blocking Phase 0 exit)

**Epic 7:** **done** 2026-06-08 — optional `epic-7-retrospective`.  
**Post-close follow-ups (Baptiste):**

| ID | Action | Note |
|----|--------|------|
| FUNC-12 | Midnight rollover test ce soir | Hotfix si échec |
| REL-03 + VIS-13 | README demo GIF | Quand prêt |
| REL-01 | APK size optimization | ABI split, R8 — post-beta |
| AUTO-03/04 | CI flake triage | Hygiene |
