# Sprint Change Proposal — Post-Beta UX Tranche (Epics 8–12)

**Project:** astra-app  
**Author:** Correct Course workflow  
**Date:** 2026-06-15  
**Trigger:** Post–Epic 7 beta closure — data integrity bug, UX navigation redesign, analytics expansion  
**Status:** **Approved** (2026-06-15 — Baptiste)  
**Amendment (2026-06-15):** Merged former **Epic 13** into **Epic 10** — one **moyen** bump for shell + secondary surfaces + Units (nav-only is not a standalone version phase).

**Implementation order (locked):** Epic 8 → (Epic 9 ∥ Epic 10) → (Epic 11 ∥ Epic 12)  
**Out of sprint (backlog):** Achievements, Help menu entries  

### Versioning policy (Epics 8–12)

**Source of truth:** `pubspec.yaml` → `version: 0.minor.patch+build`  
**Pre-1.0 rule:** Stay on **`0.x.y`** — reserve **`1.0.0`** for public launch; never bump major to `1` in this tranche.

**Mandatory:** At the **end of each work phase** (each epic close, or story when shipped alone), bump version **before** marking the phase done. Always update:

1. `pubspec.yaml` — `version:` line  
2. `README.md` — Project status version row  

Always increment **`+build`** (`versionCode` on Android). Do not edit Gradle manually.

| Phase type | When | Semver bump | Example (from `0.2.0+2`) |
|------------|------|-------------|----------------------------|
| **Fix** (bug, hotfix, no new user capability) | Epic/story close | `patch+1`, `+build+1` | `0.2.0+2` → `0.2.1+3` |
| **Mineur** (fixes only batch, no feature) | Same as Fix | `patch+1`, `+build+1` | same |
| **Moyen** (new feature, UX tranche, new screen/nav) | Epic close | `minor+1`, `patch=0`, `+build+1` | `0.2.1+3` → `0.3.0+4` |

**Epic 8–12 mapping:**

| Epic | Type | Bump at epic close |
|------|------|-------------------|
| **8** Goal Time Semantics | **Fix** (data bug) | patch |
| **9** FGS Notification | **Fix** | patch |
| **10** App Shell, Navigation & Settings Surfaces | **Moyen** | minor (once — includes nav, menu, Profile, Settings, Data, About, Units) |
| **11** Steps Dashboard | **Moyen** | minor |
| **12** Trends Analytics | **Moyen** | minor |

**Projected tranche progression** (starting `0.2.0+2`):

| After epic | Version |
|------------|---------|
| Epic 8 | `0.2.1+3` |
| Epic 9 | `0.2.2+4` |
| Epic 10 | `0.3.0+5` |
| Epic 11 | `0.4.0+6` |
| Epic 12 | `0.5.0+7` |

Verify: About screen (`package_info_plus`) and release APK `aapt dump badging` must match `pubspec.yaml`.  
Full policy: `docs/project-context.md` § Versioning · `.cursor/rules/app-versioning.mdc`.

**Mockup assets (workspace):**

| Screen | Asset |
|--------|-------|
| Steps | `assets/c__Users_Baptiste_..._Today-light-*.png` |
| Trends | `assets/c__Users_Baptiste_..._History-light-*.png` |
| Menu hub | `assets/c__Users_Baptiste_..._Menu-light-*.png` |
| Data | `assets/c__Users_Baptiste_..._Data-light-*.png` |
| Profile | `assets/c__Users_Baptiste_..._Profil-light-*.png` |
| Settings | `assets/c__Users_Baptiste_..._Settings-light-*.png` |
| About | `assets/c__Users_Baptiste_..._About-light-*.png` |

---

## 1. Issue Summary

After Phase 0 beta readiness (Epic 7 **done**), Baptiste identified a **critical data-model bug** and a **structural UX tranche** before public beta users:

1. **Goal retroactivity bug** — `daily_step_goal` is a single global preference; changing it re-evaluates past days (`WeekDayStatus.goalMet`, History goal line, celebration semantics).
2. **Steps experience** — Rename Today → Steps; week card first; day selection drives all indicators; trophy X/7.
3. **Trends analytics** — Average kcal/steps cards, peak day, 12-month monthly chart; goal line per day.
4. **Navigation shell** — 4 tabs → 3 tabs (STEPS · TRENDS · MENU); secondary screens via full-screen list + push stack.
5. **Profile / Settings split** — Theme, accent, notifications → Settings; Units for global display; Profile slim.
6. **FGS notification** — Reduce intrusive visibility while preserving Android health FGS collection.

**Discovery context:** Planned post-beta tranche — not a failed story. Epics 1–7 remain **done**; superseded UX patterns documented below.

**User decisions (2026-06-15):**

| Topic | Decision |
|-------|----------|
| Goal change timing | **Immediate** on current local day; past days **frozen** |
| Pre-migration users | **None** — clean v3 migration; seed one effective row for today |
| Menu pattern | **Full-screen list** (mockup title **My Data** = menu hub, not Data screen) |
| Achievements / Help | **Out of sprint** — no menu rows until future epic |
| Units (Settings) | **Editable** display prefs app-wide (distance, weight, height); canonical storage stays metric |
| Trends kcal average | **Bucket-based** per day via `DerivedActivityMetrics` (consistent with Steps) |
| Peak day | **Both** 7d and 30d per existing period toggle |
| Maquettes | Attached to this proposal; referenced in story AC |
| Epic structure | **Epic 13 merged into Epic 10** — nav + surfaces = one moyen bump; no core/ingest changes |

---

## 2. Impact Analysis

### Epic impact

| Epic | Status | Impact |
|------|--------|--------|
| **1–7** | done | Baseline preserved; selected AC superseded (see below) |
| **8** Goal Time Semantics | **new** | DB v3, goal history table, consumer migration |
| **9** Android FGS Notification | **new** | Kotlin notification channel / copy only |
| **10** App Shell, Navigation & Settings Surfaces | **new** | 3-tab nav, menu hub, Profile/Settings split, Units, Data, About |
| **11** Steps Dashboard | **new** | Layout, day picker, live guards, trophy |
| **12** Trends Analytics | **new** | Stats cards, peak day, 12mo chart, per-day goal line |

### Story supersession (completed work)

| Old story / pattern | Superseded by |
|---------------------|---------------|
| 5.7 Four-tab floating nav | **10.1** Three-tab nav |
| 5.9 Today Figma layout | **11.1–11.4** Steps dashboard |
| 4.6 Goal on My Data (removed earlier) | **8.x** goal history + **11.x** Set goal on Steps |
| 4.7 / 5.11 Theme on Profile | **10.5** Settings |
| 5.10 Data tab in bottom nav | **10.2** Menu hub + **10.8** Data screen |
| 5.11 Profile tab in bottom nav | **10.2** Menu → **10.4** Profile |
| 3.3 History / Trends (single goal line) | **8.2** + **12.4** per-day goal line |
| FR-9 single `daily_step_goal` semantics | **8.x** effective-dated goal journal |

### Artifact conflicts

| Artifact | Sections to update |
|----------|-------------------|
| **epics.md** | Epics 8–12, scope amendment 2026-06-15 |
| **architecture.md** | `daily_goal_effective` table; display unit keys; 3-tab shell; goal resolution API |
| **ux-design-specification.md** | §2.1 shell (3 tabs); Steps layout; Trends stats; Menu hub; Settings Units |
| **PRD addendum** | Goal historization FR; display units FR; navigation FR |
| **sprint-status.yaml** | Epics 8–12 entries |
| **BETA_CHECKLIST.md** | Add cases: goal retroactivity, 3-tab nav, units toggle (at Epic 10 close) |

### Technical impact (code)

| Area | Change |
|------|--------|
| `migrations.dart` | v3: `daily_goal_effective` |
| `user_preferences_repository.dart` | Goal history CRUD + unit prefs |
| `today_cubit.dart` | Selected day, historical goal, live guards |
| `history_cubit.dart` | Aggregates, stats, 12mo, per-day goals |
| `step_repository.dart` | Window queries, monthly aggregates, per-day buckets |
| `app_scaffold.dart` / `app_bottom_nav.dart` | 3 tabs + nested Navigator |
| `profile_screen.dart` | Slim Informations |
| New screens | `menu_hub_screen`, `settings_screen`, `about_screen` |
| `activity_metrics_formatter.dart` | Unit-aware formatting |
| `HealthStepForegroundService.kt` | Notification visibility |

**Non-goals:** No refactor of ingestion pipeline, WorkManager orchestration, or timeseries schema beyond goal table.

---

## 3. Recommended Approach

**Path:** Direct Adjustment — new Epics 8–12 appended; no rollback of Epics 1–7.

| Attribute | Assessment |
|-----------|------------|
| **Scope** | Moderate — 5 epics, 18 stories |
| **Risk** | Medium — goal migration touches multiple cubits; FGS/OEM sensitivity |
| **Timeline** | Epic 8 first; Epics 9+10 parallel; then 11+12 |
| **Regression guard** | Existing step-collection tests must pass every story |

**Rationale:** Goal bug is foundational; Epic 10 delivers full UX shell as one cohesive **moyen** tranche (nav alone does not touch app core).

---

## 4. Detailed Change Proposals

### 4.1 Data model — goal historization

**NEW table (migration v3):**

```sql
CREATE TABLE daily_goal_effective (
  effective_from_local_day TEXT PRIMARY KEY,
  goal INTEGER NOT NULL CHECK (goal > 0)
);
```

**Resolution:** `getGoalForLocalDay(day)` → latest row where `effective_from_local_day ≤ day`.

**Write rule:** On `setDailyStepGoal(goal)`:
- If row exists for **today** → UPDATE
- Else → INSERT with `effective_from_local_day = today`
- Sync `user_preferences.daily_step_goal` cache

**Migration:** Insert one row `(today, current daily_step_goal)`.

### 4.2 Navigation

**OLD:** 4 tabs — TODAY · TRENDS · DATA · PROFILE  
**NEW:** 3 tabs — STEPS · TRENDS · MENU  

**Menu hub (tab 2):**

- **Informations:** Profile, Data  
- **Other:** Settings, About  
- **Excluded this sprint:** Achievements, Help  

Secondary screens: `Navigator.push` with back arrow; remove DATA/PROFILE from `IndexedStack` tabs.

### 4.3 Steps screen

**OLD order:** Title → ring → stats → week  
**NEW order:** Title → **This week** (picker + X/7 trophy) → ring → stats → Set goal  

**State:** `selectedLocalDay`; default today on cold start and app resume.

**Live pipeline:** Celebration, catch-up, live step overlay **only when** `selectedLocalDay == today`.

### 4.4 Trends

**Add under chart (mockup):**
- Average kcal burned per day (window = 7d or 30d)
- Average steps per day (same window)

**Add (no mockup — spec retained):**
- Peak performance day card (max steps, relabeled date)
- 12-month chart: monthly **average** steps (not daily bars)

**Goal line:** Per-day resolved goal on bar chart (Epic 8 dependency).

### 4.5 Settings & Units

**Move from Profile to Settings:**
- Goal notifications toggle
- Theme mode segmented control
- Accent preset bi-tone circles

**NEW Units section (editable):**
- Distance: Metric (km) / Imperial (mi)
- Weight: Kg / lb
- Height: cm / ft+in

**Storage:** Canonical values remain cm, kg, km internally. Display formatters read unit prefs. Profile editors accept input in chosen unit, convert on save.

### 4.6 FGS notification

**Keep:** FGS health type, collection loop, channel id `astra_health_tracking`.  
**Tune:** `IMPORTANCE_MIN` where compatible, shorter copy, verify `PRIORITY_MIN`, no badge.  
**Do not:** Disguise as sync; remove FGS entirely.

---

## 5. Implementation Handoff

### Scope classification

**Moderate** — backlog reorganization (Epics 8–12) + coordinated multi-file changes.

### Handoff

| Recipient | Responsibility |
|-----------|----------------|
| **Baptiste** | Review brief per sub-task; approve commits |
| **Dev agent (`bmad-dev-story`)** | Implement stories in locked order |
| **CR agent (`bmad-code-review`)** | Adversarial review after each story |

### Success criteria

- [ ] Changing goal does not alter `goalMet` for past local days
- [ ] Today immediately reflects new goal
- [ ] Steps day picker drives ring, stats, goal for selected day
- [ ] Trends averages and peak day respect 7d/30d toggle
- [ ] 12-month monthly chart renders without KPI-01 regression on 30d view
- [ ] 3-tab nav + menu push stack matches mockups
- [ ] Units change updates Profile + Steps stats display
- [ ] Step collection tests green; FGS still collects in background
- [ ] Version bumped per epic (see § Versioning policy) — tranche target `0.5.0+7` from `0.2.0+2`

### Next BMad steps

1. ✅ Sprint Change Proposal (this document) — **Approved 2026-06-15**
2. ✅ Epics 8–12 appended to `planning-artifacts/epics.md`
3. ✅ `sprint-status.yaml` updated
4. → `[CS]` Create Story **8.1** → `[DS]` Dev Story

---

## Appendix A — Epic & story inventory

| Epic | Stories |
|------|---------|
| **8** Goal Time Semantics | 8.1, 8.2 |
| **9** Android FGS Notification | 9.1 |
| **10** App Shell, Navigation & Settings Surfaces | 10.1–10.8 |
| **11** Steps Dashboard | 11.1–11.4 |
| **12** Trends Analytics | 12.1–12.4 |

**Total:** 18 stories across 5 epics.

## Appendix B — Future backlog (not in sprint)

- **Achievements** screen + menu row
- **Help** screen + menu row
