# Sprint Change Proposal — Figma Navigation & Surface Redesign

**Project:** astra-app  
**Author:** Correct Course workflow  
**Date:** 2026-06-04  
**Trigger:** Pre–Epic 5 Figma design pass (Baptiste)  
**Status:** **Approved** (2026-06-04 — Baptiste)  
**Amendment (2026-06-04):** Profil → Appearance adds **bi-tone accent circles** (see §4.2 / FR-32).

**Implementation order (locked):** 5.6 → 5.7 → 5.8 → 5.9 → 5.10 → 5.11 → 5.12 → Epic 6 → (5.13 optional after).  
**Renumbering (2026-06-04):** Story IDs aligned to that sequence (5.5 done unchanged). Legacy map in `epics.md`.  
**Copy locks:** tab **TRENDS** / **DATA** / **PROFIL**; Data screen title **My Data**; Profil section **Informations**; Today stats row visible, empty until Epic 6.

---

## 1. Issue Summary

Before starting design-polish epics, Baptiste produced high-fidelity Figma mockups that reorganize the Phase 0 shell from **three tabs** (Today · History · My Data) to **four tabs** (Today · Trends · Data · Profil), resplit screen responsibilities, refresh Today’s layout, extend appearance controls (accent presets), and standardize on **Phosphor Icons**.

**Discovery context:** Strategic UX refinement during Figma work—not a failed implementation story. Epics 1–4 are **done**; Epic 5 (design polish) is **in-progress** with 5.5 complete and 5.1–5.4 in backlog.

**Evidence:** Written change list (2026-06-04) + mockups (Today, Trends, Data, Profil light/dark, accent matrix, **Profil Appearance bi-tone circles**).

**User decisions (2026-06-04):**

| Topic | Decision |
|-------|----------|
| Daily step goal | **Today** — “Set goal” pill below donut (not Profile) |
| Data → “Your data” | **Unchanged** — Export CSV, Import CSV, Delete all local data |
| Trends content | **Same as current History** — 7d/30d bar chart, goal line, weekly trend chip |
| Kcal / distance / walking time | **Deferred** — new epic later (formulas TBD) |
| Today greeting `Hello, {name}` | **Removed** for now |
| Theme mode | **Profile → Appearance** — System / Light / Dark |
| Accent presets | **6 presets** — **bi-tone circles** on Profil (base light/dark half + accent half); **Epic 5** stories **5.8** + **5.10** |
| Icons | **Phosphor** — add dependency |

---

## 2. Impact Analysis

### Epic impact

| Epic | Status | Impact |
|------|--------|--------|
| **1** Trust & Shell | done | Story 1.3 AC obsolete (3-tab); document as superseded by 5.2 |
| **2** Today | done | Story 2.5 layout obsolete; greeting removed; “Set goal” on Today; week strip new |
| **3** History & Trends | done | Tab label **Trends**; screen title may stay “History” or align to “Trends” (TBD in 5.3); chart logic unchanged |
| **4** My Data | done | **Split:** Data tab = 4.2 footprint/background + 4.3–4.5 data actions; Profile tab = 4.6 goal editor N/A (goal on Today), 4.7 theme → Profile, 4.8 name → Profile, 4.9 initials → Profile header |
| **5** Design polish | in-progress | **Major rewrite** of 5.1–5.4 AC; **add** stories 5.6–5.11; mockups become source of truth |
| **6** OSS / Beta | backlog | Beta checklist surfaces: 4 tabs, Profile, accent presets |
| **7** (new) Derived activity metrics | **new backlog** | Kcal, distance, walking time row on Today — blocked until formulas/spec |

### Story impact (completed work → correction via Epic 5)

| Old story | Change |
|-----------|--------|
| 1.3 App scaffold | Superseded by **5.2** (4-tab floating nav) |
| 2.5 Today dashboard | Superseded by **5.6** (Figma Today layout) |
| 3.3 History screen | Relabel tab only; optional title copy in **5.3** |
| 4.2 My Data footprint | Move UI to **Data** screen (**5.7**) |
| 4.6 Goal editor on My Data | **Today “Set goal”** (**5.6**); remove from Data |
| 4.7 Theme on My Data | **Profile Appearance** (**5.8**) |
| 4.8 Today greeting | **Remove** (**5.11**) |
| 4.9 Profile initials on My Data | **Profile** header (**5.8**) |
| 5.2 Nav polish | Rewrite for floating pill + 4 tabs |
| 5.3 Cohesion audit | Update surfaces; **delete** greeting hero AC |
| 5.1 Accent tokens | Extend for **6 accent presets** (**5.10**) |

### Artifact conflicts

| Artifact | Sections to update |
|----------|-------------------|
| **PRD** | §10 three surfaces → four tabs; FR-14 Today layout; FR-31 location (Profile); FR-9 drop Today greeting; add FR-32 (accent preset), FR-33 placeholder (derived metrics epic) |
| **UX spec** | §2.1 shell (4 tabs, floating nav, Phosphor); §2.3 Today; rename §2.4 Trends; §2.5 Data; new §2.6 Profile; ThemeSelector + **AccentPresetSelector**; attach mockup refs |
| **epics.md** | Epic list, UX-DR4/11/22, stories 5.x, new Epic 6; scope amendments |
| **architecture.md** | Navigation (4 destinations); `user_preferences` keys: `height_cm`, `weight_kg`, `accent_preset`, `goal_notifications_enabled`; `DerivedActivityMetrics`; Phosphor in dependencies |
| **sprint-status.yaml** | Add 5.6–5.11, epic-6 backlog (after approval) |

### Technical impact (code)

- `AppScaffold`: 4th tab, floating `NavigationBar` styling, Phosphor icons
- New `ProfileScreen`; slim `DataScreen` (rename from `MyDataScreen`)
- `TodayScreen`: remove greeting; add stats row (placeholder until Epic 6), week pills, Set goal CTA
- `ThemeCubit` / `UserPreferencesRepository`: `theme_mode` + `accent_preset` + profile fields + notification toggle
- `AccentPresetSelector` widget on `ProfileScreen` (bi-tone circles, FR-32)
- `pubspec.yaml`: `phosphor_flutter` (or agreed package)
- Tests: navigation, theme preset, purge/export paths on Data tab

**No rollback** of ingestion, SQLite, BackgroundCollector, or CSV pipelines.

---

## 3. Recommended Approach

**Selected: Option 1 — Direct adjustment** within Epic 5 + one new backlog epic.

| Criterion | Assessment |
|-----------|------------|
| Effort | **Medium–high** (nav shell + 3 screen layouts + theme presets + dependency) |
| Risk | **Medium** (regression on export/purge/theme persistence) |
| Timeline | Epic 5 extends before 6.3 beta checklist; Epic 6 non-blocking for shell redesign |
| MVP | **Preserved** — same capabilities, new IA; metrics row can show placeholders until Epic 6 |

**Not viable:** Rollback of Epics 1–4.  
**Not required:** PRD MVP scope reduction.

**Scope classification:** **Moderate** — backlog reorganization + developer implementation; no full PM/Architect replan.

---

## 4. Detailed Change Proposals

### 4.1 PRD

**§10 Hub surfaces**

```text
OLD:
- Three surfaces: Today, History, My Data
- Bottom navigation or tab bar with three tabs

NEW:
- Four surfaces: Today, Trends, Data, Profil
- Bottom navigation: four tabs (Today · Trends · Data · Profil); floating pill style per UX mockups
```

**FR-14 (Today)**

```text
OLD:
Today displays circular progress ring; step source label; optional display_name greeting (FR-9)

NEW:
Today displays:
- Screen title "Today's activity" (or i18n key)
- Donut step progress (current / goal) with steps icon in center
- "Set goal" control below donut (opens goal editor; same validation 1,000–100,000)
- Row: kcal, distance, walking time — PLACEHOLDER or "—" until Epic 6 (derived metrics)
- Row: "This week" — 7 day pills with goal-met (green) / missed (red) / today (accent) / future (muted)
- NO Hello {name} greeting in Phase 0 redesign
- Source chip: retain or relocate per 5.3 audit (mockups omit — defer to cohesion story)
```

**FR-31 (Theme)**

```text
OLD:
User chooses System / Light / Dark from My Data

NEW:
User chooses System / Light / Dark from Profil → Appearance
```

**FR-9 (user_preferences)**

```text
OLD:
Optional display_name for Today greeting

NEW:
display_name stored for Profil → Informations only (no Today greeting)
ADD (Profil): height_cm (int), weight_kg (num) — local-only, optional. **No** age or sex/gender (2026-06-04).
ADD: accent_preset enum (orange|red|green|cyan|purple|pink), default orange
ADD: goal_notifications_enabled bool (Profil toggle)
```

**NEW FR-32: Accent color preset (bi-tone selector)**

User selects one of six accent presets from **Profil → Appearance**, below the System/Light/Dark control.

**Control design (locked per Figma 2026-06-04):**
- Horizontal row of **six circular chips** (~40–48dp touch target).
- Each chip is **bi-tone**: diagonal split (top-left → bottom-right).
  - **Bottom-left half** = effective **surface base** for the current appearance mode (white / near-white on light UI; dark charcoal on dark UI).
  - **Top-right half** = the **accent color** for that preset (orange, red, green, cyan, purple, pink).
- Chips **re-render** when the user changes System/Light/Dark (or when OS theme changes under System) so the preview always matches the active base + accent pairing.
- **Selected** preset: visible border/ring on the active circle (per light/dark mockups).
- Selection applies immediately to ring, nav bar, chart emphasis, week “today” pill, and primary CTAs.

Persisted in `user_preferences.accent_preset`. Default: **orange** (aligned with current `#EAD55E` family).

**Independent controls:** `theme_mode` (System/Light/Dark) and `accent_preset` (six colors) are separate preferences; both live in Appearance.

**FR-33 (Epic 6 — locked 2026-06-04):** Distance = steps × stride (height×0.414 or 0.76 m default); walking time = sum active bucket durations; kcal = MET 3.5 × weight (70 kg default) × walking hours. No age/gender.

---

### 4.2 UX specification (summary deltas)

| Area | Change |
|------|--------|
| Navigation | 4 tabs; floating orange pill; active tab = white squircle; Phosphor icons (Footprints, ChartBar, Database, User) |
| Today §2.3 | Full layout per mockups; Set goal; week strip; no greeting |
| History → **Trends §2.4** | Tab label Trends; content unchanged; header copy TBD History vs Trends |
| My Data → **Data §2.5** | Three cards only: Background, Footprint, Your data |
| **Profile §2.6 (new)** | Informations rows + chevron; Notifications toggle; **Appearance** card with stacked controls (see below) |
| **Appearance (locked)** | (1) `ThemeModeSelector` — segmented System / Light / Dark, orange underline on active segment. (2) `AccentPresetSelector` — row of **six bi-tone circles** (surface half + accent half); selection border; chips reflect effective light/dark base. Ref: Profil light/dark mockups 2026-06-04. |
| Today theming matrix | Separate Figma grid (6 accents × light/dark full screens) remains reference for token QA — not a second picker on Today |
| Icons §1.x | Lock Phosphor regular; remove Material Symbols default |

---

### 4.3 Epics & stories

#### Epic 3 title (optional)

```text
OLD: Epic 3: History & Trends
NEW: Epic 3: Trends (History charts)  [documentation only — epic already done]
```

#### Epic 4 description

```text
OLD: Data Sovereignty & Lifecycle (My Data)
NEW: Data Sovereignty & Lifecycle — primary UI on Data tab; profile prefs on Profil tab
```

#### Epic 5 — replace / add stories

**5.1** — Revise title/AC: token system supports **six accent presets** in light and dark (not only amber contrast pass).

**5.2** — Revise: **four-tab floating** `NavigationBar`, Phosphor icons, mockup spacing (not cramped 3-tab Material bar).

**5.3** — Revise: audit **Today, Trends, Data, Profil**; remove Today greeting AC; add mockup sign-off V-14+.

**5.4** — Unchanged intent (overflow animation).

**5.5** — done (Kotlin plugin).

**5.6 (NEW) Today screen — Figma layout**

- Donut + Set goal + week strip
- Stats row UI present; values placeholder until Epic 6
- Remove `Hello, {name}`
- Stale compact banner behavior preserved (link to Data)

**5.7 (NEW) Data screen — sovereignty layout**

- Only Background, Footprint, Your data (export/import/purge)
- Remove goal row, theme, display name, profile badge from this screen

**5.8 (NEW) Profile screen**

- Informations: display name, height, weight (editable rows + chevron)
- Notifications: goal notifications toggle (maps FR-24/FR-25 permission UX)
- Appearance card (stacked):
  - `ThemeModeSelector` — System / Light / Dark (migrate Story 4.7)
  - `AccentPresetSelector` — six **bi-tone circles** per FR-32 (depends **5.10** tokens)
- Section title: **Informations** (light) / harmonize with **Profile** card title in dark mockup → single copy key `profile.section.info`
- Migrate profile initials from 4.9 if still desired (mockups omit avatar — optional in 5.3)

**5.9 (NEW) Phosphor icons dependency**

- Add `phosphor_flutter` to `pubspec.yaml` and `docs/DEPENDENCIES.md`
- Replace tab (and primary screen) icons per mockups

**5.10 (NEW) Accent color presets & bi-tone selector widget**

- Define six accent token sets (light + dark semantic mappings) per Astra-theming matrix
- Build `AccentPresetSelector`: diagonal bi-tone `CustomPainter` or stacked clips per chip; base half from **effective** `ThemeMode` (respects System)
- Persist `accent_preset`; wire `AstraColors` / `ThemeCubit` — changing preset or theme mode updates chips and app chrome without restart
- Widget tests: selection persistence, chip colors per preset, base half swaps when theme mode toggles

**5.11 (NEW) Navigation & greeting cleanup**

- Remove Today greeting widget and tests asserting Hello copy
- `display_name` edit only from Profile

#### Epic 6 (NEW backlog): Derived Activity Metrics

**Goal:** Populate Today stats row (kcal, km, duration) from steps + user biometrics.

**Status:** backlog — spec workshop required before stories.

**Dependencies:** Profile height/weight (5.11); step repository today total.

---

### 4.4 sprint-status.yaml (after approval)

```yaml
  # Epic 5 backlog (IDs match execution order — see sprint-status.yaml)
  5-6-phosphor-icons-dependency: backlog
  5-7-four-tab-floating-navigation: backlog
  5-8-accent-preset-theme-tokens: backlog
  5-9-today-figma-layout-no-greeting: backlog
  5-10-data-screen-sovereignty-layout: backlog
  5-11-profil-informations-and-appearance: backlog
  5-12-cross-screen-visual-cohesion-audit: backlog
  5-13-goal-overflow-animation-polish: backlog  # optional after 5.12

  epic-6: backlog
  6-1-derived-activity-metrics: backlog

  epic-7: backlog
  7-1-open-source-license-and-documentation-bundle: backlog
  7-2-release-manifest-hardening-and-privacy-audit: backlog
  7-3-beta-acceptance-checklist: backlog
```

**Approved implementation order:** **5.6 → 5.7 → 5.8 → 5.9 → 5.10 → 5.11 → 5.12 → Epic 6 → 5.13** (optional). Former 5.10/5.11 scope merged into 5.8/5.9/5.11 (accent / Today / Profil).

---

## 5. Implementation Handoff

| Role | Responsibility |
|------|----------------|
| **Baptiste** | Approve proposal; optional: History vs Trends screen title |
| **Developer agent** | Implement Epic 5 stories in order above; placeholders on stats row |
| **PM (light)** | Merge PRD/UX/epics edits after approval |

**Success criteria**

- Four tabs match mockups (icons, floating bar, active state)
- Today: donut, Set goal, week strip, no greeting
- Trends: same chart behavior as today’s History
- Data: three cards; export/import/purge work
- Profil: infos + notifications + appearance + accent presets persist across restart
- Purge preserves profile prefs + theme + accent per FR-20 amended list
- `flutter analyze` + existing tests green (updated for navigation)

---

## 6. Approval

**Approved:** 2026-06-04 by Baptiste with locked sequence and copy rules above.

**Artifacts updated:** `epics.md`, `sprint-status.yaml`, `prd.md`, `architecture.md`, `ux-design-specification.md`.

**Handoff:** Developer agent — start **Story 5.6** (`phosphor_flutter`).

---

*Mockup assets stored under workspace `assets/` (2026-06-04 upload).*
