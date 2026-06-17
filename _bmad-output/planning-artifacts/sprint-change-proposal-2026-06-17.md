# Sprint Change Proposal — Onboarding Redesign (Epic 13)

**Project:** astra-app  
**Author:** Correct Course workflow  
**Date:** 2026-06-17  
**Trigger:** New Figma mockups — onboarding flow redesign (intro → weight → height)  
**Status:** **Approved** (2026-06-17 — Baptiste)  
**Mode:** Batch (user supplied full intent + mockups)

**Mockup assets (workspace):**

| Screen | Asset |
|--------|-------|
| Intro | `assets/c__Users_Baptiste_..._onboarding-light-fe809f6a-*.png` |
| Weight | `assets/c__Users_Baptiste_..._Weight-light-ee767d67-*.png` |
| Height | `assets/c__Users_Baptiste_..._Height-light-2ccf1294-*.png` |

---

## 1. Issue Summary

After Epics 8–12 (post-beta UX tranche), Baptiste produced **high-fidelity onboarding mockups** that replace the shipped 4-step flow (Trust → Permissions → Goal → Display name) with a **3-step profile-first flow**:

1. **Intro** — trust/privacy card (“Your Health. Your Phone. Period.”)
2. **Weight** — `AstraSegmentedControl` (kg / lb) + horizontal ruler picker
3. **Height** — `AstraSegmentedControl` (cm / inches) + horizontal ruler picker

Each step shows a **3-segment progress bar**, **Back** (steps 2–3), primary CTA (**Continue** / **Let's Go**), and **skip** on body-metric steps. An **optional disclaimer** (expandable) is shown on intro.

**Discovery context:** UX polish tranche — not a failed story. Story **1.5** (Trust-First Onboarding) remains **done**; this epic **supersedes presentation** while preserving local-first principles and canonical storage (`height_cm`, `weight_kg`).

**Evidence:**

| Current (code) | Target (mockups) |
|----------------|------------------|
| 4 steps: Trust, Permissions, Goal, Display name | 3 steps: Intro, Weight, Height |
| Dot progress indicator | 3-segment bar (filled = current) |
| Text field goal editor | No goal step — ruler pickers |
| Dedicated permissions page (step 2) | **No permission screen** — OS dialog on intro **Continue** (bridge to weight) |
| `OnboardingDisplayNamePage` as final step | No display name in flow |

---

## 2. Impact Analysis

### Epic impact

| Epic | Impact |
|------|--------|
| **Epic 13 (new)** | **Onboarding Redesign** — primary delivery vehicle |
| Epic 1 (done) | Story 1.5 superseded at UX level; no re-open of epic status |
| Epic 6 (done) | Benefits immediately — height/weight collected earlier → better derived metrics defaults |
| Epic 10 (done) | Profile editors remain source of truth for later edits; display-unit formatters reused |
| Epic 9 (in-progress) | No blocker; intro permission bridge is independent of FGS visibility |
| Epics 1–12 | No structural dependency changes |

### Story impact (new Epic 13)

| Story | Title | Scope |
|-------|-------|-------|
| **13.1** | Onboarding shell & intro screen | 3-segment progress, footer chrome (Back / CTA), intro card copy, optional disclaimer |
| **13.2** | `AstraHorizontalRuler` widget | Reusable scrollable ruler; major/minor ticks; haptic optional; unit label |
| **13.3** | Weight & height onboarding steps | Segmented unit toggle, ruler binding, skip → `null` prefs, canonical cm/kg persist |
| **13.4** | Flow completion & cleanup | Intro→weight permission bridge; remove goal/display-name/old permission page; tests + docs |

### Artifact conflicts

| Artifact | Conflict | Resolution |
|----------|----------|------------|
| **PRD** FR-22 | Trust before permissions — mockups omit permission *screen* | Amend: trust copy on intro; **activity permission OS dialog on intro Continue** (bridge before weight step) — no separate permission page |
| **PRD** FR-23 | Goal setup in onboarding | Amend: **default 8000 at completion**; explicit setup via **Set goal** on Steps (already shipped) |
| **PRD** FR-24 | Notification opt-in in onboarding | Amend: opt-in via **Settings → Receive Goal notifications** toggle (Epic 10); first enable triggers OS dialog |
| **UX §2.7** | 3-step Trust/Permissions/Goal | Replace with §2.7 onboarding table (intro/weight/height) |
| **UX-DR16** | Onboarding 3-step stack definition | Supersede with new DR for ruler + segmented onboarding |
| **epics.md** Story 1.5 | 4-step acceptance criteria | Add Epic 13; annotate 1.5 as superseded by 13.x |
| **architecture.md** | `onboarding/` pages list | Update module list; add `AstraHorizontalRuler` |
| **BETA_CHECKLIST** FUNC-10 | “grant permissions during onboarding” | Keep repro: grant activity on intro Continue; notification via Settings |
| **sprint-status.yaml** | Ends at Epic 12 | Add `epic-13` + stories 13.1–13.4 |

### Technical impact

- **New widget:** `lib/presentation/widgets/astra_horizontal_ruler.dart` (no existing ruler in codebase)
- **Reuse:** `AstraSegmentedControl`, `display_unit_formatter.dart`, `UserPreferencesRepository.setHeightCm/setWeightKg`
- **OnboardingCubit:** Simplify state (remove goal/notification UI from flow); **keep** `requestActivityPermission()` — invoked on intro Continue before `nextStep()`; add `weightKg`, `heightCm`, unit display prefs for session
- **Permission bridge:** No dedicated permission page; no post-onboarding Steps gate — hub advances to weight/height even if activity denied (existing empty-state / banner patterns apply)
- **Tests:** Rewrite `test/presentation/onboarding/onboarding_flow_test.dart`; widget tests for ruler
- **No schema migration** — `height_cm` / `weight_kg` keys already exist
- **Version bump:** **moyen** at Epic 13 close → `0.5.2+10` → **`0.6.0+11`** (`pubspec.yaml` + `README.md`)

---

## 3. Recommended Approach

**Selected path: Option 1 — Direct Adjustment** (new Epic 13 within existing plan)

| Option | Viable? | Notes |
|--------|---------|-------|
| Direct adjustment | **Yes** | Add Epic 13; supersede onboarding UI; amend FR-22–24 wording |
| Rollback | No | Story 1.5 foundation (prefs, cubit, gate) stays; only UI/steps change |
| MVP review | No | Scope is UX refinement, not MVP cut |

**Effort:** Medium (3–4 stories, ~1 new shared widget)  
**Risk:** Low (permission bridge on intro Continue preserves FR-22; reuses existing `OnboardingCubit.requestActivityPermission`)  
**Timeline:** After Epic 9 review merge; parallel-safe with any hotfixes

### Locked decisions — permissions / goal / display name

| Topic | Decision | Rationale |
|-------|----------|-----------|
| **Permissions** | **Bridge on intro Continue** (no dedicated screen) | Intro card explains sensors (“built-in sensors…”). **Continue** → OS **activity recognition / pedometer** dialog → advance to weight **whether granted or denied**. Notifications stay in **Settings** (FR-24 relocated). Re-tap Continue after Back only re-prompts if still not granted. |
| **Goal** | **Remove from onboarding** | Mockups omit goal; default **8000** applied on `completeOnboarding()`. User sets goal via **Set goal** on Steps (FR-14/FR-23 already support post-onboarding edit). |
| **Display name** | **Remove from onboarding** | Mockups omit; PRD already excludes Today greeting. Profile → Display name editor remains (Epic 10.4). Skip = `null` pref. |

### Skip & disclaimer behavior

| Element | Behavior |
|---------|----------|
| **Skip (weight/height)** | Ghost/text control; stores `null` for that field; proceeds to next step |
| **Skip all metrics** | User can skip both → derived metrics use defaults (stride 0.76 m, weight 70 kg) |
| **Disclaimer (intro)** | Optional **“Learn more”** expandable below card — local-only storage, sensor use, no account; does not block Continue |
| **Final CTA** | Height step: **“Let's Go”** → `onboarding_complete=true` → Steps tab |

---

## 4. Detailed Change Proposals

### 4.1 PRD (`prd-astra-app-2026-05-22/prd.md`)

#### FR-22: Trust-first onboarding

**OLD:**
> First launch presents local-only privacy explanation before requesting permissions.

**NEW:**
> First launch presents local-only privacy explanation on the **intro onboarding screen** before any OS permission dialog. When the user taps **Continue** on intro, the app requests **activity recognition** (pedometer) via the system dialog, then advances to the weight step — **without** a separate full-screen permission page. Trust copy must be read before the dialog (FR-22). Optional expandable disclaimer on intro. Hub continues onboarding if permission is denied.

**Rationale:** Baptiste intent — permission sits *between* onboarding pages (intro → dialog → weight), not deferred to Steps and not a standalone permission screen.

---

#### FR-23: Goal setup

**OLD:**
> Onboarding collects **daily_step_goal** with set-once philosophy (editable later via **Set goal** on Today).

**NEW:**
> Onboarding **does not** collect daily step goal. On completion, **`daily_step_goal` defaults to FR-9 (8000)**. User may set or change goal via **Set goal** on the Steps screen at any time (set-once philosophy applies to first explicit edit, not onboarding).

**Rationale:** Mockups remove goal step; Steps already has Set goal control.

---

#### FR-24: Notification opt-in

**OLD:**
> Onboarding offers optional local notification permission with explanation tied to goal-celebration use case.

**NEW:**
> **Settings → Receive Goal notifications** offers optional local notification permission with explanation tied to goal-celebration use case. Enabling the toggle triggers the OS permission dialog when not yet granted.

**Rationale:** Notifications already live in Settings post–Epic 10; onboarding no longer includes permission step.

---

### 4.2 UX Design Specification (`ux-design-specification.md` §2.7)

**OLD (§2.7 table):**

| Step | Screen | Content |
|------|--------|---------|
| 1 Trust | OnboardingTrust | … |
| 2 Permissions | OnboardingPermissions | … |
| 3 Goal | OnboardingGoal | … |

**NEW:**

| Step | Screen | Content | Primary CTA |
|------|--------|---------|-------------|
| **1 Intro** | `OnboardingIntroPage` | Headline: “Your Health. Your Phone. Period.” Card copy (locked): *“Astra tracks your movement, habits, and health metrics using only your device's built-in sensors. No accounts, no cloud leakage. Your personal evolution belongs to you—and only you.”* Optional expandable disclaimer | Continue → **activity permission OS dialog** → weight |
| **2 Weight** | `OnboardingWeightPage` | `AstraSegmentedControl` kg/lb; `AstraHorizontalRuler`; default 70 kg; skip → null | Continue |
| **3 Height** | `OnboardingHeightPage` | `AstraSegmentedControl` cm/inches; ruler; default 170 cm; skip → null | Let's Go |

**Rules (replace existing §2.7 rules):**
- 3-segment progress bar (not dots); back on steps 2–3 only
- Canonical storage: `weight_kg` (double), `height_cm` (int) — same validation ranges as Profile
- Unit toggles affect display only during onboarding; persist display-unit prefs if already set, else session-local until Settings
- Intro **Continue** triggers activity permission request (reuse `OnboardingCubit.requestActivityPermission`) then navigates to weight; onboarding never blocks on denial
- On complete → Steps tab
- Never show account/email or goal numeric field in onboarding

**New UX-DR (add to design decisions):**

> **UX-DR27:** Build `AstraHorizontalRuler` — horizontal scroll picker with center indicator, major/minor ticks, large value readout, unit label; used in onboarding weight/height and available for Profile editors in a follow-up if desired.

---

### 4.3 Epics (`epics.md`)

**Add after Epic 12:**

```markdown
## Epic 13: Onboarding Redesign

Replace trust/permissions/goal/display-name stack with intro → weight → height flow per Figma mockups. Activity permission requested on intro Continue (OS dialog bridge). Collect optional body metrics for derived activity estimates.

**Depends on:** Epics 1, 6, 10 done.
**Version bump:** **moyen** once when entire epic closes (`0.6.0+11` from `0.5.2+10`).

### Story 13.1: Onboarding Shell & Intro Screen
… (acceptance criteria per §4.4 below)

### Story 13.2: AstraHorizontalRuler Widget
…

### Story 13.3: Weight & Height Onboarding Steps
…

### Story 13.4: Flow Completion & Cleanup
…
```

**Annotate Story 1.5** header:

> **Superseded (2026-06-17):** UX replaced by Epic 13. Persistence keys and onboarding gate pattern remain valid.

---

### 4.4 Story acceptance criteria (Epic 13)

#### Story 13.1: Onboarding Shell & Intro Screen

**Given** first launch (`onboarding_complete` false)  
**When** onboarding renders  
**Then** 3-segment progress bar shows step 1 active  
**And** intro matches mockup copy (headline + locked card paragraphs per §4.2)  
**And** optional disclaimer expands/collapses without blocking Continue  
**And** footer shows primary Continue (no Back on step 1)  
**Given** user taps Continue on intro  
**When** permission has not been granted  
**Then** system activity recognition dialog appears **before** weight step is shown  
**And** flow advances to weight after dialog dismisses (grant or deny)  
**And** Continue shows loading/disabled state while request is in flight

#### Story 13.2: AstraHorizontalRuler Widget

**Given** ruler with min/max/step configured  
**When** user scrolls horizontally  
**Then** centered value updates with snap-to-tick behavior  
**And** major labels render at configured intervals  
**And** semantics announce value + unit  
**And** widget test covers snap and bounds

#### Story 13.3: Weight & Height Onboarding Steps

**Given** weight step  
**When** user selects kg or lb via `AstraSegmentedControl`  
**Then** ruler range and labels update; stored value is canonical kg  
**Given** height step  
**When** user selects cm or inches  
**Then** stored value is canonical cm  
**Given** Skip on either step  
**When** user continues  
**Then** corresponding pref is `null` (not written or explicitly cleared)  
**Given** Let's Go on height step  
**When** onboarding completes  
**Then** `onboarding_complete=true`, `daily_step_goal=8000`, metrics saved

#### Story 13.4: Flow Completion & Cleanup

**Given** user denied activity on intro Continue  
**When** they complete weight + height and land on Steps  
**Then** existing permission-denied / empty-state patterns apply (no second onboarding gate)  
**Given** removed pages  
**When** codebase is searched  
**Then** `OnboardingPermissionsPage`, `OnboardingGoalPage`, `OnboardingDisplayNamePage` are not in active flow (delete or archive)  
**Given** tests  
**When** `flutter test` runs  
**Then** onboarding flow tests reflect 3 steps  
**Given** beta checklist FUNC-10  
**When** updated  
**Then** repro steps: trust copy on intro → Continue → grant activity → complete onboarding

---

### 4.5 Architecture (`architecture.md`)

**Update presentation module list:**

```diff
- │   ├── onboarding/       # trust, permissions, goal pages
+ │   ├── onboarding/       # intro, weight, height pages
+ │   └── widgets/          # …, astra_horizontal_ruler.dart
```

**Update onboarding flow description:** 3 visible steps (intro/weight/height); activity permission on intro Continue bridge.

---

### 4.6 sprint-status.yaml

Add:

```yaml
  epic-13: backlog
  13-1-onboarding-shell-and-intro-screen: backlog
  13-2-astra-horizontal-ruler-widget: backlog
  13-3-weight-and-height-onboarding-steps: backlog
  13-4-flow-completion-and-cleanup: backlog
  epic-13-retrospective: optional
```

---

## 5. Implementation Handoff

| Field | Value |
|-------|-------|
| **Scope classification** | **Moderate** — new epic, PRD/UX amendments, 4 stories, 1 new widget, test rewrites |
| **Route to** | Developer agent (`bmad-dev-story` / `bmad-quick-dev`) after story files created |
| **PO action** | Approve this proposal; run `create-story` for 13.1 → 13.4 |
| **Version** | Bump at Epic 13 close only: `0.6.0+11` |

### Success criteria

- [ ] 3-step onboarding matches mockups (progress bar, segmented units, ruler, skip, disclaimer)
- [ ] `height_cm` / `weight_kg` persist correctly; skip leaves nulls
- [ ] Activity permission requested on intro Continue, after trust copy (OS dialog bridge)
- [ ] Default goal 8000 on complete; Set goal on Steps still works
- [ ] No display name step; Profile editor unchanged
- [ ] FUNC-10 updated and passing
- [ ] `pubspec.yaml` + `README.md` at `0.6.0+11` when epic closes

### Suggested implementation order

1. **13.2** ruler widget (isolated, testable)
2. **13.1** shell + intro (uses progress bar)
3. **13.3** weight + height pages (uses ruler + segmented control)
4. **13.4** wire-up, remove old steps, intro permission bridge, tests, checklist

---

## Checklist status (Correct Course)

| Section | Status |
|---------|--------|
| 1. Trigger & context | [x] Done |
| 2. Epic impact | [x] Done |
| 3. Artifact conflicts | [x] Done |
| 4. Path forward | [x] Done — Option 1 Direct Adjustment |
| 5. Proposal components | [x] Done |
| 6. Final review | [x] Done |
| 6.4 sprint-status update | [x] Done |
| 6.3 User approval | [x] Approved 2026-06-17 |

---

## Approval

**Approved 2026-06-17** — Baptiste.

**Scope:** Moderate → backlog reorganization + Developer agent implementation.

**Next:** Create story files 13.1–13.4, then `bmad-dev-story` starting with **13.2** (ruler) or **13.1** (shell).
