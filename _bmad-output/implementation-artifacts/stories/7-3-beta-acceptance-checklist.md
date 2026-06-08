# Story 7.3: Beta Acceptance Checklist

Status: review

<!-- Epic 7 finale — Phase 0 exit gate: BETA_CHECKLIST.md, version baseline, 100% manual pass, demo GIF, install size. -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **builder**,
I want a comprehensive beta checklist tracing to FRs and visual polish items,
so that Phase 0 exit criteria are objectively verifiable before sharing the OSS beta.

## Acceptance Criteria

1. **Given** `docs/BETA_CHECKLIST.md`  
   **When** reviewed  
   **Then** items cover background persistence, notifications, footprint, export, import, purge, airplane mode, counter-reset unit test, CSV round-trip, and reference Epic 5 visual cohesion sign-off (FR29, UX-DR21)

2. **Given** each checklist item  
   **When** traced  
   **Then** at least one FR, UX-DR, SM, or NFR reference is cited

3. **Given** checklist execution on release APK  
   **When** run by Baptiste or ≥1 external beta tester  
   **Then** 100% pass is required for Phase 0 exit (SM-7)

4. **Given** field regression items from 2026-06-03 device pass  
   **When** checklist is authored and executed on release APK  
   **Then** explicit manual cases exist for: (1) goal local notification — app **killed** during walk, reopen after goal crossed, **notification permission granted in OS settings** → one notification same day (FR25); (2) walk repro — kill mid-walk → reopen shows goal met; screen-off with app alive → no spurious steps; **kill+reopen at home** → count must **not decrease**; (3) Delete all local data — **2 consecutive** attempts succeed (FR20); (4) purge + footprint empty state on all tabs  
   **And** failures are logged with device model / Android version / build type for the consolidated debug pass after checklist

5. **Given** install size check  
   **When** release APK built  
   **Then** artifact size is <50MB (NFR2, SM-6)

6. **Given** README demo GIF capture  
   **When** checklist is complete  
   **Then** GIF capture steps are documented as a checklist item (SM-7, UX V-13)

7. **Given** Phase 0 beta versioning (Baptiste request — session wrap-up)  
   **When** release APK is built  
   **Then** `pubspec.yaml` declares a semver baseline (`version: x.y.z+build`) as the **single source of truth** for Android `versionName` / `versionCode`  
   **And** the app displays the version on **Profile** (e.g. footer row "ASTRA v0.1.0 (1)")  
   **And** `docs/project-context.md` documents when to bump patch vs build number  
   **And** checklist includes a row to verify displayed version matches the built APK

**Depends on:** Story 7.1 (docs bundle), Story 7.2 (release manifest gate + release APK path). Epic 5.12 (visual cohesion sign-off). Story 6.6 (midnight rollover) should be **done** before field execution — not blocking checklist **authoring**.  
**Out of scope:** Fixing deferred regressions (notification, step decrease, purge) — checklist **surfaces** them; hotfix stories follow 100% pass attempt. Play Store release. SQLCipher / BLE.

---

## Tasks / Subtasks

- [x] **A — App version baseline** (AC: #7)
  - [x] Add `version: 0.1.0+1` to `pubspec.yaml` (Phase 0 OSS beta baseline; `0.x` = pre-1.0)
  - [x] **Preferred:** add `package_info_plus` (local-only, reads native bundle from pubspec — no manual sync). Update `docs/DEPENDENCIES.md` if added.
  - [x] **Alternative (zero new deps):** `lib/core/constants/app_version.dart` with comment `// keep in sync with pubspec.yaml version`
  - [x] Display version on `ProfileScreen` — subtle footer below sections (not hero); use `AstraTypography.caption` + `colors.textMuted`
  - [x] Add **Versioning** subsection to `docs/project-context.md`:
    - `+build` (after `+`) → every sideload APK / checklist run
    - patch `z` → bugfix-only hotfix batch
    - minor `y` → post–Phase 0 feature tranche
    - major `x` → reserved for 1.0 public launch narrative
  - [x] Verify: `flutter build apk --release` → `aapt dump badging` or file size path shows `versionName='0.1.0'` `versionCode='1'` — **confirmed** 2026-06-08; APK **53_508_011 bytes (~51.0 MB)** — REL-01 will fail NFR2 until size-reduction follow-up

- [x] **B — Create `docs/BETA_CHECKLIST.md`** (AC: #1, #2)
  - [x] Structure: intro (purpose, Phase 0 exit, 100% pass rule) → **How to run** → **Automated gates** → **Functional** → **Visual (V-1–V-13)** → **Field regressions (2026-06-03)** → **OSS / release** → **Execution log**
  - [x] Link from `docs/README.md` and README §Project status
  - [x] Cross-link `test/release_manifest_test.dart`, `test/data/datasources/step_normalizer_test.dart` (`handles counter reset`), KPI-01 log

- [x] **C — Functional checklist items** (AC: #1, #2)
  - [x] Background persistence without opening app (FR4, FR6, SM-2) — reference Story 2.4/2.8 deferred acceptance notes
  - [x] Goal local notification once/day (FR25) — link field repro Task E
  - [x] Footprint visible + reasonable after 90d inject (FR5, FR13, NFR7) — dev inject path `lib/dev/`
  - [x] CSV export OW-aligned columns (FR19) — `docs/SERIES_TYPES.md`
  - [x] CSV import idempotency spot-check (FR30)
  - [x] Purge → 0 samples, goal retained (FR20, FR21, D-11)
  - [x] 24h airplane mode — Today, Trends, Data/export (FR18, SM-3) — defer to Story 7.2 Task D evidence or re-run
  - [x] Release manifest: no INTERNET (FR18) — `flutter test test/release_manifest_test.dart`
  - [x] Counter reset unit test (FR2) — `flutter test test/data/datasources/step_normalizer_test.dart`
  - [x] CSV round-trip: export → purge samples → import → Today/Trends reconcile (FR30)
  - [x] Theme survives purge; system default on fresh install (FR31, UX V-1, V-9)
  - [x] Onboarding once only (FR22–24, UX V-10)
  - [x] Derived metrics on Today (FR33, Epic 6)
  - [x] Midnight day rollover — steps flush, UI resets (Story 6.6) — manual if not covered by automated tests

- [x] **D — Visual polish section** (AC: #1, UX-DR21)
  - [x] Copy table from `ux-design-specification.md` §4.7 (V-1 through V-13) into checklist with Pass/Fail columns
  - [x] Honor V-11 exception: Today compact stale banner removed; Data may show full stale banner >12h
  - [x] Reference Epic 5.12 cohesion sign-off as prerequisite note (already done)

- [x] **E — Field regression manual cases** (AC: #4)
  - [x] **E1 Notification (FR25):** kill during walk → reopen after goal crossed → exactly one notification (permission granted)
  - [x] **E2 Walk monotonicity:** kill mid-walk OK; screen-off no spike; **kill+reopen at home → count must not decrease** (FR2/2.9 truth model)
  - [x] **E3 Purge reliability:** two consecutive "Delete all local data" succeed on release build after typical session (FR20)
  - [x] **E4 Post-purge empty state:** Today ring 0, Trends empty, Data footprint 0, goal preference retained on Profile
  - [x] Include execution log columns: Device | Android | Build | APK version | Pass/Fail | Notes

- [x] **F — OSS / release gates** (AC: #5, #6)
  - [x] Install size: document command `Get-Item build/app/outputs/flutter-apk/app-release.apk | Select Length` — threshold **< 52_428_800 bytes (50 MB)**
  - [x] **Known risk:** Story 7.2 build logged **51.0 MB** — may fail NFR2; checklist must record actual size; if over, open follow-up size-reduction story (do not silently waive)
  - [x] Demo GIF item (SM-7, V-13): capture Today goal ring + Data export flow; embed path `docs/assets/demo.gif` or README relative path; reduce-motion variant noted
  - [x] External tester row: ≥1 proche completes airplane mode protocol on **release** APK (SM-7)

- [x] **G — Execution & sprint hygiene**
  - [x] Baptiste runs checklist on release APK; log results in checklist **Execution log** section (not only Dev Agent Record)
  - [x] Copy KPI-01 row from `kpi-01-regression-log.md` when device benchmark run — **deferred** (VIS-07 subjective pass logged in checklist; formal row optional)
  - [x] Update story Dev Agent Record with pass rate and blockers
  - [x] On 100% pass: mark story done; consider epic-7 → done + optional epic-7-retrospective — **closed 2026-06-08** per Baptiste (GIF + FUNC-12 post-close non-blocking)
  - [x] On failures: list failed IDs → consolidated hotfix pass per `deferred-work.md` (notification hotfix `4a92db0` applied)

---

## Dev Notes

### Current state — gap analysis

| Artifact | Status | Action |
|----------|--------|--------|
| `docs/BETA_CHECKLIST.md` | ❌ Missing | **Create** (Task B) |
| `pubspec.yaml` `version:` | ❌ Missing | Add `0.1.0+1` (Task A) |
| In-app version display | ❌ None | Profile footer (Task A) |
| `test/release_manifest_test.dart` | ✅ Story 7.2 | Reference in checklist |
| `step_normalizer_test.dart` reset test | ✅ Exists | Reference in checklist |
| `kpi-01-regression-log.md` | ⚠️ Empty table | Manual device run before V-7 sign-off |
| Story 7.2 airplane mode field test | ⚠️ Pending Baptiste | Checklist item uses 7.2 evidence or re-run |
| Release APK size | ⚠️ 51.0 MB (7.2) | May fail NFR2 — record, do not hide |
| Deferred regressions (2.7, 2.x, 4.5) | ⚠️ Open | Explicit E1–E3 cases |
| README demo GIF | ❌ Not captured | Task F documents capture |

### Architecture compliance

- **FR-29:** Checklist lives at `docs/BETA_CHECKLIST.md` per architecture tree [Source: `architecture.md` §Project Structure]
- **FR-18 manifest gate:** Automated via `test/release_manifest_test.dart` — checklist cites, does not duplicate test code
- **Documentation bundle:** Do not duplicate full `DEPENDENCIES.md` / `REGULATORY_POSITION.md` — link only
- **English UI** for checklist labels in app; checklist doc may use English (matches NFR-6, story deliverables convention)
- **Review-before-commit** gate per sub-task [Source: `docs/project-context.md`]

### Version integration (Baptiste session request)

**Baseline recommendation:** `0.1.0+1`

| Component | Semver part | When to bump |
|-----------|-------------|--------------|
| `0.1.0` | pre-1.0 beta | Feature tranches post–Phase 0 |
| `+1` build | Android `versionCode` | Each sideload APK / beta drop |

**Implementation pattern (preferred):**

```yaml
# pubspec.yaml
version: 0.1.0+1
```

```dart
// Profile footer — package_info_plus (reads from built manifest)
final info = await PackageInfo.fromPlatform();
Text('ASTRA v${info.version} (${info.buildNumber})');
```

`android/app/build.gradle.kts` already maps `versionCode` / `versionName` from Flutter — **no Gradle edit** needed when pubspec is set.

**Checklist row:** "Displayed Profile version matches `pubspec.yaml` and `aapt dump badging` output."

### BETA_CHECKLIST.md content outline

Use markdown tables with columns: `ID | Check | FR/UX/SM | How to verify | Pass | Notes`

**Suggested ID prefixes:**

| Prefix | Section |
|--------|---------|
| `AUTO-` | CI / `flutter test` gates |
| `FUNC-` | Functional manual on device |
| `VIS-` | V-1 … V-13 from UX §4.7 |
| `REG-` | 2026-06-03 regression repros (E1–E4) |
| `REL-` | Release / OSS (size, GIF, version, external tester) |

**Minimum automated gates to cite (not re-implement):**

| Test / command | Covers |
|----------------|--------|
| `flutter test test/release_manifest_test.dart` | FR18 |
| `flutter test test/data/datasources/step_normalizer_test.dart` | FR2 counter reset |
| `flutter test` (full suite) | Regression safety before field pass |
| `flutter analyze` | Clean analyze gate |

### Field regression intelligence (deferred-work.md)

These are **expected to fail** until post-checklist hotfix batch — checklist must still include them so Phase 0 exit is honest:

| Issue | Source | Checklist ID |
|-------|--------|--------------|
| No notification when killed during walk | Story 2.7 field feedback | REG-01 |
| Step count decreases on kill+reopen | deferred-work / 2.x | REG-02 |
| Purge fails 2/2 | Story 4.5 field feedback | REG-03 |
| Last sync copy vs 60s persist | deferred-work | FUNC footnote only |

**Sequencing (Baptiste 2026-06-03):** Checklist execution **before** hotfix batch is intentional — surfaces all issues for consolidated debug pass.

### Install size (NFR2 / SM-6)

Story 7.2 recorded **51.0 MB** release APK — **over 50 MB threshold**.

Checklist must:
1. Record exact byte size per build
2. Fail REL-install-size if ≥ 50 MB unless Baptiste documents explicit waiver in execution log
3. Suggest follow-up levers (not in this story): ProGuard/R8 audit, asset compression, ABI splits — **do not** implement size work in 7.3 unless Baptiste expands scope

### Demo GIF (SM-7)

Document steps only in this story — capture is manual:

1. Release or profile build with representative data (dev inject 7d visible on Trends)
2. Record: Today ring approaching/filling goal → optional celebration → Data → Export CSV
3. Target: <5 MB GIF, README-embeddable width (~360–400px)
4. Store: `docs/assets/demo.gif` (create folder) or `assets/` if README references — prefer `docs/assets/` for OSS docs bundle

### File structure requirements

**Create:**
- `docs/BETA_CHECKLIST.md`
- `docs/assets/` (if GIF captured in same story session — optional until capture)
- `lib/core/constants/app_version.dart` (only if skipping package_info_plus)

**Update:**
- `pubspec.yaml` — `version:` field (+ `package_info_plus` if chosen)
- `lib/presentation/screens/profile_screen.dart` — version footer
- `docs/README.md` — link BETA_CHECKLIST
- `docs/project-context.md` — versioning policy
- `docs/DEPENDENCIES.md` — only if `package_info_plus` added
- `README.md` — optional: version in Project status table; link checklist

**Do not touch:**
- Health pipeline / collector logic (unless fixing checklist failures in separate hotfix stories)
- `test/release_manifest_test.dart` — already done in 7.2

### Testing requirements

| Check | Command / action | Expect |
|-------|------------------|--------|
| Version wiring | `flutter build apk --release` + badging | versionName 0.1.0, code 1 |
| Profile UI | Open Profile tab | Version visible, muted typography |
| Manifest gate | `flutter test test/release_manifest_test.dart` | Pass (cite in checklist) |
| Counter reset | `flutter test test/data/datasources/step_normalizer_test.dart` | Pass |
| Full suite | `flutter test` | Green before field session (note 7.2 had 6 pre-existing flakes — triage in execution log) |
| Field checklist | Release APK manual | 100% for Phase 0 exit |

### Cross-story boundaries

| Story | Owns |
|-------|------|
| **7.1 (done)** | LICENSE, FR-27 docs, README airplane copy |
| **7.2 (done)** | `release_manifest_test.dart`, privacy audit, release build path |
| **7.3 (this)** | `BETA_CHECKLIST.md`, version baseline, 100% pass gate, GIF docs, install size row |
| **Post-7.3 hotfix** | REG failures → re-open 2.7 / 2.x / 4.5 per deferred-work |

### Previous story intelligence (7.2)

- Release APK path: `build/app/outputs/flutter-apk/app-release.apk`
- Package name: `com.astraapp`
- README uses **Trends** and **Data** tab labels (not History)
- Task D (24h airplane) still pending in 7.2 Dev Agent Record — checklist FUNC-airplane item should reference or re-run
- `notification_service.dart` at `lib/core/services/notification_service.dart`
- Do not remove `android.builtInKotlin=false` flags without Baptiste approval

### Git intelligence summary

Recent commits focus on Epic 6 midnight rollover hardening (6.6):

| Commit | Relevance |
|--------|-----------|
| `9220e04` | Midnight boundary detection — include REG/midnight manual case |
| `37387e0` | Live steps flush at midnight — checklist FUNC item |
| `19f672e` | Story 7.2 done — manifest tests stable |
| Epic 7 docs commits | DEPENDENCIES, README airplane protocol ready |

### Latest technical information

**Flutter app versioning:** `pubspec.yaml` `version: major.minor.patch+build` is the canonical source; Flutter Gradle plugin propagates to Android automatically [Flutter build and release](https://docs.flutter.dev/deployment/android).

**package_info_plus:** Local platform channel only; no network; reads `version`/`buildNumber` from built artifact — preferred over manual constant duplication.

**Phase 0 exit (SM-7):** 100% checklist pass + README GIF + ≥1 external tester on release build — checklist is the audit trail, not a substitute for tester recruitment.

### Project context reference

- One commit per sub-task after Baptiste review [Source: `docs/project-context.md`]
- Field evidence in checklist execution log + Dev Agent Record
- Communication: French with Baptiste; **deliverables in English**
- This is the **last planned Phase 0 story** — successful execution closes Epic 7 and the BMad implementation arc for Sandbox

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 7.3 AC]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-29, SM-6, SM-7, NFR2]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §4.7 V-1–V-13]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — docs tree, FR-29 verification]
- [Source: `_bmad-output/implementation-artifacts/stories/7-2-release-manifest-hardening-and-privacy-audit.md`]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md` — field repro sequencing]
- [Source: `_bmad-output/implementation-artifacts/kpi-01-regression-log.md`]
- [Source: `test/data/datasources/step_normalizer_test.dart` — counter reset]
- [Source: `test/release_manifest_test.dart` — FR-18 gate]

---

## Dev Agent Record

### Agent Model Used

Claude (Cursor Agent)

### Debug Log References

- `flutter test test/presentation/screens/profile_screen_test.dart` — 6/6 pass (incl. version footer)
- `flutter test test/release_manifest_test.dart` — 3/3 pass
- `flutter test test/data/datasources/step_normalizer_test.dart` — 11/11 pass
- `flutter test` full suite — 627 pass, **6 pre-existing failures** (FGS lifecycle, app_scaffold, widget_test — same flakes noted in Story 7.2; not introduced by 7.3)
- Release APK build 2026-06-08: `versionName='0.1.0'` `versionCode='1'`; size **53_508_011 bytes** (~51.0 MB, over NFR2 50 MB threshold)

### Completion Notes List

- Tasks **A–G** complete. Version baseline `0.1.0+1`, `package_info_plus`, Profile footer, `docs/BETA_CHECKLIST.md`, docs/README links.
- Field pass **2026-06-08:** 36/39 checklist items pass/waived; REG-01–04 pass; FUNC-02 pass after hotfix `4a92db0`; REL-01 waived (~52 MB).
- **Ready for review** per Baptiste — GIF (REL-03/VIS-13) and FUNC-12 midnight test **post-close** (hotfix if needed).
- Strict SM-7 100% OSS share gate deferred for FUNC-12 + optional GIF.

### File List

- `pubspec.yaml` — version `0.1.0+1`, `package_info_plus` dependency
- `pubspec.lock` — lockfile update
- `lib/presentation/screens/profile_screen.dart` — `_ProfileVersionFooter`
- `test/presentation/screens/profile_screen_test.dart` — version footer widget test
- `docs/BETA_CHECKLIST.md` — **created**
- `docs/README.md` — active docs table link
- `docs/project-context.md` — Versioning subsection
- `docs/DEPENDENCIES.md` — `package_info_plus` row
- `README.md` — version + beta gate in Project status
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 7-3 review, epic-7 in-progress
- `docs/BETA_CHECKLIST.md` — field execution log + post-close follow-ups

### Change Log

- 2026-06-08: Tasks A–F — beta checklist authoring, version baseline, Profile footer
- 2026-06-08: Task G field pass + checklist updates; notification hotfix `4a92db0` (separate commit)
- 2026-06-08: Story → review — GIF deferred, FUNC-12 post-close midnight test

---

## Story Completion Status

- **Status:** review
- **Epic 7:** in-progress — awaiting 7.3 code review → done
- **Post-close:** FUNC-12 midnight verification; REL-03 GIF optional; strict 100% SM-7 when sharing OSS publicly
- **Completion note:** Checklist authored, executed, and logged; version baseline shipped
