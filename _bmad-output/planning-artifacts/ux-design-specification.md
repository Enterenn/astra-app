---
stepsCompleted: [1, 2, 3, 4, 5]
workflowMode: fast-pass
status: complete
completed: 2026-05-22
fastPassBlocksCompleted:
  - visual-foundation
  - components-and-states
  - screen-flows
  - accessibility-polish
inputDocuments:
  - prds/prd-astra-app-2026-05-22/prd.md
  - prds/prd-astra-app-2026-05-22/addendum.md
  - prds/prd-astra-app-2026-05-22/.decision-log.md
  - ../brainstorming/brainstorming-session-2026-05-22-1521.md
fastPassBlocks:
  - visual-foundation
  - components-and-states
  - screen-flows
  - accessibility-polish
---

# UX Design Specification astra-app

**Author:** Baptiste
**Date:** 2026-05-22
**Scope:** Phase 0 Sandbox — Flutter Hub App (Today / History / My Data + onboarding)
**Mode:** Fast pass (PRD-heavy inputs; skips full BMad 14-step discovery)

---

## 1. Visual Foundation (Bloc 1)

### 1.1 Design Direction

**One-line:** *Quiet instrument panel — not a coach, not a clinic.*

ASTRA Phase 0 reads as a **precision tool for personal data**, not a fitness game. Visual hierarchy favors **legibility of numbers and proof** (footprint, last sync, export) over decoration. Dark mode is the default canvas; light mode is out of scope for Phase 0.

| Attribute | Direction |
|-----------|-----------|
| Mood | Calm, confident, transparent |
| Density | Airy — one hero metric per screen |
| Motion | Subtle, purposeful (goal pulse once/day max) |
| Brand | Working OSS palette — no proprietary assets in repo (Phase 1 official brand) |

**References (tone, not copy):**
- **Things 3 / Linear** — restrained dark UI, clear hierarchy
- **Apple Health (Activity ring)** — ring metaphor without gamification chrome
- **Signal / Proton** — privacy-as-product, sober trust copy

**Anti-references (explicit):**
- Strava orange aggression, streak flames, leaderboards
- WHOOP recovery scores, red/green "strain" dashboards
- Hospital/clinical blue + dense tables
- Wearable companion upsell clutter (subscription banners, coach cards)

---

### 1.2 Color Tokens

Phase 0 uses a **token-lite** set mappable to Flutter `ThemeData` + a small `AstraColors` extension. Semantic names over raw hex in components.

#### Surfaces (dark default)

| Token | Hex | Usage |
|-------|-----|-------|
| `color.bg.base` | `#0F1114` | App scaffold, full-screen backgrounds |
| `color.bg.elevated` | `#1A1D23` | Cards, bottom sheet, onboarding panels |
| `color.bg.subtle` | `#252830` | Secondary panels, chart plot area |
| `color.border.default` | `#2E3340` | Dividers, card outlines (1px) |
| `color.border.focus` | `#4A5568` | Focus rings, active tab indicator track |

#### Text

| Token | Hex | Usage |
|-------|-----|-------|
| `color.text.primary` | `#F4F5F7` | Headlines, step count hero |
| `color.text.secondary` | `#9CA3AF` | Labels, captions, source tag |
| `color.text.muted` | `#6B7280` | Timestamps, footnotes, disabled |
| `color.text.inverse` | `#0F1114` | Text on accent fills (buttons) |

#### Accent candidates (on `#0F1114` charcoal)

| Hex | Name | Dark-mode feel | ASTRA fit | Risk |
|-----|------|----------------|-----------|------|
| `#5EEA78` | Mint green | Fresh, readable | ⚠️ Proche fitness "success/go" — gamification involontaire | Connotation Strava/Health "green = good" |
| `#EAD55E` | Warm amber | **Doux, chaleureux, faible fatigue visuelle** | ✅ Instrument calme, premium discret, pas coach | Peut rapprocher "gold achievement" si trop saturé en grand format |
| `#7C5EEA` | Violet | Distinctif, tech/privacy | ✅ Identité forte, loin des codes fitness | Saturation élevée sur grands pleins (ring entier) |
| `#5EEAD4` | Teal | Lumineux, moderne | ✅ Clair et tech | ⚠️ **Vibration chromatique** sur fond sombre — votre intuition est juste |

**Recommandation (D-1):** `#EAD55E` (amber) — meilleur compromis dark-mode first + ton calme ASTRA.  
**Alternative identité:** `#7C5EEA` (violet) si vous voulez une signature plus "privacy-tech" et moins wellness chaleureux.

**Usage anti-fatigue (toutes accents):** réserver l'accent plein au **stroke du ring actif + CTA + tab active** ; éviter grands aplats saturés. Utiliser `-muted` à 20–30% opacité pour tracks et chart bars.

#### Accent & data — **locked: amber `#EAD55E`**

| Token | Hex | Usage |
|-------|-----|-------|
| `color.accent.primary` | `#EAD55E` | Goal ring stroke fill, primary CTA, active tab |
| `color.accent.primary-muted` | `#EAD55E` @ 28% | Ring track, chart bar fill, subtle highlights |
| `color.accent.secondary` | `#94A3B8` | Trend neutral, inactive chart elements |
| `color.data.positive` | `#A3E635` @ 80% | Weekly trend up (informational, not celebratory) |
| `color.data.negative` | `#FCA5A5` | Weekly trend down (informational only) |
| `color.data.goal-line` | `#EAD55E` @ 35% | History chart goal reference line (dashed) |

**Rationale:** Amber on charcoal avoids teal halation and green "fitness success" cues. Chart bars use **accent-muted fill** so History ties visually to Today without overwhelming the screen.

#### Semantic (My Data / status)

| Token | Hex | Usage |
|-------|-----|-------|
| `color.status.ok` | `#86EFAC` | Background collection healthy |
| `color.status.stale` | `#FBBF24` | Stale-data warning (>12h, A-4) |
| `color.status.danger` | `#F87171` | Purge confirm destructive actions |
| `color.status.info` | `#93C5FD` | Neutral info banners (iOS backfill explainer) |

#### Flutter mapping note

```dart
// Phase 0: ThemeData.dark() base + AstraColors extension
// colorScheme.primary = accent.primary
// colorScheme.surface = bg.elevated
// colorScheme.error = status.danger
```

---

### 1.3 Typography

**Families (via `google_fonts`):**
- **Figtree** — UI shell: body, labels, captions, buttons, My Data metadata
- **Darker Grotesque** — Data hero: step count, large KPI numbers, screen titles

| Token | Family | Size | Weight | Line height | Usage |
|-------|--------|------|--------|-------------|-------|
| `type.display` | Darker Grotesque | 52sp | 600 | 1.05 | Today step count (center of ring) |
| `type.title` | Darker Grotesque | 24sp | 600 | 1.15 | Screen titles (History, My Data) |
| `type.headline` | Figtree | 18sp | 600 | 1.3 | Section headers on My Data |
| `type.body` | Figtree | 16sp | 400 | 1.5 | Body copy, onboarding trust text |
| `type.label` | Figtree | 14sp | 500 | 1.4 | Tab labels, button text |
| `type.caption` | Figtree | 12sp | 400 | 1.4 | Source tag, goal sublabel, timestamps |
| `type.data` | Darker Grotesque | 20sp | 500 | 1.2 | Footprint KB, sample count (My Data KPI row) |

**Rules:**
- Hero numbers always **Darker Grotesque** — max legibility at a glance.
- Figtree for everything conversational (trust copy, explanations, stale warnings).
- Never ALL CAPS for body; sentence case everywhere (calm tone).
- Max 2 font families on any screen (display + body).

---

### 1.4 Spacing & Layout

**Base unit:** 4px grid. Default padding multiples: 8, 12, 16, 24, 32.

| Token | Value | Usage |
|-------|-------|-------|
| `space.xs` | 4 | Icon gaps, tight inline |
| `space.sm` | 8 | List item internal padding |
| `space.md` | 16 | Screen horizontal padding |
| `space.lg` | 24 | Section gaps |
| `space.xl` | 32 | Hero ring vertical breathing room |
| `space.2xl` | 48 | Onboarding panel padding |

| Token | Value | Usage |
|-------|-------|-------|
| `radius.sm` | 8 | Chips, small buttons |
| `radius.md` | 12 | Cards, chart container |
| `radius.lg` | 16 | Bottom sheets, onboarding cards |
| `radius.full` | 999 | Goal ring (stroke), pills |

**Layout constraints:**
- Screen horizontal padding: `space.md` (16) minimum; 20 on large phones optional.
- Bottom tab bar height: 56dp + safe area.
- Goal ring diameter: ~220–260 logical px (scales with `LayoutBuilder`; hero centered above fold).
- Touch targets: minimum 48×48dp (NFR-5 aspirational).

#### Goal ring layout (D-3 — locked)

**Pattern:** Stroke ring + **center step count** (best readability and overflow handling).

```
        ╭──────────────╮
       ╱   10 847      ╲     ← type.display (Darker Grotesque)
      │    steps today   │   ← type.caption (Figtree)
      │    goal 8 000    │   ← type.caption muted (always visible)
       ╲                ╱
        ╰──────────────╯
         ring stroke 8–10px
```

| State | Ring fill | Center content |
|-------|-----------|----------------|
| **0–99%** | Arc proportional to `steps / goal` | Actual step count + "steps today" |
| **100%** | Full ring (360°) | Count + goal line; triggers once/day pulse (FR-15) |
| **>100% (overflow)** | Ring **stays full** — no second lap, no spiral | Count shows **actual total** (e.g. 10 847); goal line unchanged ("goal 8 000") — user sees overflow in the number, not a distorted ring |

**Why not filled donut:** inner hole reduces number size; overflow as "second lap" is harder to read and feels gamified.

**Chart bars (D-4 — locked):** Vertical bar chart, 7d/30d toggle. Bars = `color.accent.primary-muted` ; goal reference = dashed `color.data.goal-line`. Selected/hovered bar (if any) = `color.accent.primary` at 80%.

---

### 1.5 Motion & Feedback

| Pattern | Spec | PRD link |
|---------|------|----------|
| Goal celebration | `GoalCelebration` composite — see §2.3.1 | FR-15 |
| Tab switch | Cross-fade content, 200ms | — |
| Chart toggle 7d/30d | Horizontal slide or fade, 250ms | FR-16 |
| Pull-to-refresh | Not in Phase 0 (background autonomy) | §1.1 #7 |
| Haptics | Light impact on goal complete (optional, Android) | — |

**No:** confetti, streak animations, shake-on-miss, sound effects, Lottie overload.

---

### 1.6 Iconography

- **Style:** Outlined, 24dp default, 1.5px stroke — Material Symbols Outlined or Phosphor `regular`.
- **Tab icons:** Today = circle/ring outline; History = chart-bar; My Data = shield or database (sovereignty cue).
- **Actions:** Export = upload/share; Import = download; Purge = trash (danger color only in confirm dialog).

---

### 1.7 Decisions Log (Bloc 1)

| # | Decision | Status | Resolution |
|---|----------|--------|------------|
| D-1 | Accent hue | **Locked** | `#EAD55E` amber (Baptiste confirmed) |
| D-2 | Fonts | **Locked** | Figtree (UI) + Darker Grotesque (data hero) |
| D-3 | Ring style | **Locked** | Stroke ring + center count; fill caps 100%; overflow via number |
| D-4 | Chart bars | **Locked** | Bar charts; accent-muted fill + dashed goal line |
| D-5 | Surfaces | **Locked** | Charcoal `#0F1114` base (Baptiste confirmed) |

---

## 2. Components & Screen States (Bloc 2)

### 2.1 Global Shell

#### `AppScaffold`

Persistent frame for all post-onboarding surfaces.

| Element | Spec |
|---------|------|
| Background | `color.bg.base` |
| Bottom tab bar | 3 tabs: Today · History · My Data |
| Tab bar surface | `color.bg.elevated` + top border `color.border.default` |
| Active tab | Icon + label `color.accent.primary` |
| Inactive tab | `color.text.muted` |
| Safe area | Respect bottom inset (Android gesture nav) |

**States:** default only. No drawer, no hamburger, no settings tab (goal edit lives on My Data per A-9).

---

### 2.2 Shared Components

#### `AstraButton`

| Variant | Style | Usage |
|---------|-------|-------|
| **Primary** | Filled `color.accent.primary`, text `color.text.inverse` | Onboarding continue, confirm dialogs (non-destructive) |
| **Secondary** | Outline `color.border.default`, text `color.text.primary` | Skip, cancel |
| **Ghost** | Text only `color.text.secondary` | Tertiary actions |
| **Danger** | Filled `color.status.danger` | Purge confirm only |

Min height 48dp. Radius `radius.sm`. Label = Figtree `type.label`.

#### `StatusBanner`

Inline card for informational / warning states. Padding `space.md`, radius `radius.md`.

| Variant | Left accent | Copy tone | Usage |
|---------|-------------|-----------|-------|
| **ok** | 3px `color.status.ok` | Neutral factual | "Last collected 14 min ago" |
| **stale** | 3px `color.status.stale` | Explains, never blames user | **Today:** compact one-liner. **My Data:** full banner with detail |
| **info** | 3px `color.status.info` | Platform honesty (iOS) | "Steps update when you open the app on this device." |
| **error** | 3px `color.status.danger` | Actionable | Import failed — see §2.6 |

#### `StatusBanner` variants by surface

| Surface | Variant | Copy example |
|---------|---------|--------------|
| **Today** | `stale-compact` | "Steps may be delayed — see My Data" (padding `space.sm`, single line, height ~40dp) |
| **My Data** | `stale-full` | "No new steps in 12+ hours. Background collection may be delayed on this device." |

Both visible when stale threshold exceeded (A-4, FR-5). Today compact avoids duplicating full explanation; My Data owns diagnostic detail.

---

#### `SourceChip`

Small pill under Today hero: `"Phone sensor"` / future `"ASTRA ring"`.

- Figtree `type.caption`, padding 6×10, radius `radius.full`
- Bg `color.bg.subtle`, text `color.text.secondary`
- Icon 14dp optional (smartphone outline)

#### `SectionCard`

Grouped content on My Data. Bg `color.bg.elevated`, radius `radius.md`, padding `space.md`, optional headline (Figtree `type.headline`).

#### `ConfirmDialog`

Modal for destructive or irreversible actions.

- Purge: title "Delete all local data?", body mentions export (FR-21), buttons **Export first** (secondary) · **Delete anyway** (danger) · Cancel (ghost)
- Import overwrite: if existing data present — "Replace all data?" with row count preview

---

### 2.3 Today Surface

**FR refs:** FR-14, FR-15 · **UJ:** UJ-2

#### Layout (top → bottom)

1. Optional `StatusBanner` **compact stale** (see §2.2 — single line, no dismiss)
2. `GoalRing` (hero, vertically centered in upper 55%)
3. `SourceChip` below ring
4. Bottom tab bar

#### `GoalRing`

| Prop | Value |
|------|-------|
| Diameter | 240dp (clamp 220–260) |
| Stroke | 9dp |
| Track | `color.accent.primary-muted` |
| Progress arc | `color.accent.primary`, round caps |
| Center count | Darker Grotesque `type.display`, locale-formatted (`10 847`) |
| Sublabels | "steps today" + "goal 8 000" — Figtree `type.caption` / muted |

| State | Visual | Behavior |
|-------|--------|----------|
| **loading** | Skeleton ring (muted track pulse) | First launch before first sample |
| **empty** | Ring at 0%, count `0` | Post-purge or pre-permission |
| **progress** | Arc 0–99% | Live update on foreground + background sync |
| **goal met** | Full ring + **`GoalCelebration` playing** | Once per local calendar day — see §2.3.1 |
| **overflow** | Full ring unchanged | Count shows actual > goal |
| **no permission** | Ring dashed track, count `--` | CTA link → system settings (not blocking whole app) |

**Copy rules:** Never "You're crushing it!" — no coach language.

#### 2.3.1 `GoalCelebration` (FR-15)

Dedicated celebration moment when daily steps **first reach or exceed** `daily_step_goal` each local calendar day. Calm acknowledgment — not gamification.

**Trigger conditions:**
- Fires when `todaySteps >= daily_step_goal` and celebration not yet shown for current local day
- May trigger in **background** (notification path FR-25) or **foreground** (user on Today)
- If triggered in background: animation plays on **next Today visit** that day (single play, not repeated on every tab switch)
- Persist flag: `celebration_shown_date` in local prefs (same day boundary as step aggregation §1.3)

**Visual layers (simultaneous, 900ms total):**

| Layer | Animation | Timing | Easing |
|-------|-----------|--------|--------|
| **Ring scale** | 1.0 → 1.05 → 1.0 | 0–600ms | `Curves.easeOutCubic` |
| **Ring glow** | Halo `color.accent.primary` @ 0% → 18% → 0%, blur 24dp, behind ring | 0–800ms | ease-out |
| **Stroke shimmer** | Progress stroke opacity 1.0 → 1.25 → 1.0 (not hue shift) | 200–700ms | ease-in-out |
| **Center count** | Scale 1.0 → 1.02 → 1.0 | 100–500ms | subtle, optional |

**No:** confetti, particles, full-screen overlay, sound, streak badge, "Goal reached!" modal, coach copy toast.

**Optional micro-copy (below ring, 2s fade):**  
Single line Figtree `type.caption` `color.text.secondary`: **"Daily goal reached"** — appears once, fades out, does not stack with notifications.

**Haptics (Android):** `HapticFeedback.lightImpact()` at animation peak (~300ms). iOS: optional `HapticFeedback.mediumImpact()` if not conflicting with notification.

**Overflow (>100%):** Same celebration at first crossing of goal; subsequent steps same day do **not** re-trigger.

**Reduced motion:** If OS "reduce motion" enabled → skip scale/glow; show static full ring + micro-copy only (500ms fade).

**Flutter implementation sketch:**

```dart
// GoalCelebrationController
// - listen: todaySteps, dailyGoal, celebrationShownDate
// - onThresholdCrossed: if !shownToday → playCelebration()
// Widget: Stack(GoalRing, CelebrationGlow(opacity: anim))
```

**Relation to notification (FR-25):** Notification and celebration are independent — user may get notification while app closed; celebration plays on next Today open. No duplicate modal if both occur.

---

### 2.4 History Surface

**FR refs:** FR-16, FR-17 · **UJ:** UJ-3

#### Layout

1. Screen title "History" (Darker Grotesque `type.title`) — optional if tab label suffices
2. `PeriodToggle` — segmented control: **7 days** | **30 days**
3. `TrendChip` — e.g. "↑ 12% vs last week" — informational, small, not hero
4. `StepBarChart` — flex remaining height, min 200dp
5. Tab bar

#### `PeriodToggle`

- Segmented pill on `color.bg.subtle`, selected segment `color.bg.elevated` + accent underline
- 48dp touch height

#### `StepBarChart`

| Element | Spec |
|---------|------|
| Bars | `color.accent.primary-muted`, radius top 4dp |
| Goal line | Horizontal dashed `color.data.goal-line` at daily goal × 1 day equivalent for aggregated bar |
| X-axis | Day labels (Mon, Tue… / date short) — Figtree `type.caption` muted |
| Y-axis | Minimal — 0 + max only, no grid clutter |
| Empty state | Single message: "No history yet. Walk a bit — data stays on this device." |

| State | Visual |
|-------|--------|
| **loading** | 7 gray bar skeletons |
| **sparse** | Bars for days with data; gaps = zero-height or absent bar |
| **dense (90d+)** | KPI-01 must hold <100ms — no animation on data bind |

#### `TrendChip`

- Icon arrow + percentage vs prior week
- Up → `color.data.positive`, down → `color.data.negative`, flat → `color.text.muted`
- Copy: "Up 12% from last week" — not "Great progress!"

---

### 2.5 My Data Surface

**FR refs:** FR-5, FR-13, FR-19–21, FR-23, FR-30 · **UJ:** UJ-1, UJ-4  
**Primary differentiator** — most structured screen.

#### Layout (scrollable)

1. **Background status** — `SectionCard` + `StatusBanner` variant
2. **Footprint** — `SectionCard` with KPI row
3. **Daily goal** — inline edit (A-9 locked)
4. **Data actions** — Export · Import · Purge

*No README / external doc footer in Phase 0 (D-7).*

#### Footprint KPI row

| KPI | Typography | Example |
|-----|------------|---------|
| Sample count | Darker Grotesque `type.data` | `12 480` |
| Label | Figtree `type.caption` | samples stored |
| DB size | Darker Grotesque `type.data` | `2.4 MB` |
| Last optimized | Figtree `type.caption` | optimized 2 days ago |

Three columns or stacked pairs on narrow screens.

#### `BackgroundStatusCard`

| State | Indicator | Copy |
|-------|-----------|------|
| **healthy** | Dot `color.status.ok` | "Background collection active · Last sync {relative time}" |
| **stale (>12h)** | Dot `color.status.stale` + banner | "No new data in 12+ hours…" (FR-5, A-4) |
| **ios_backfill** | Dot `color.status.info` | Info banner: steps update on app open (FR-4) |
| **permission_denied** | Dot muted | "Activity permission off" + link to settings |

#### `GoalEditor`

- Row: "Daily step goal" + current value `8 000`
- Tap → bottom sheet with **free numeric text field** (keyboard: number pad)
- Validation: integer only, min `1 000`, max `100 000` `[ASSUMPTION: sane bounds]`, show inline error if invalid
- Save → primary button; disabled until valid; no nag if unchanged
- Set-once philosophy: no recurring prompts (FR-23)
- Same field pattern on **Onboarding step 3** (default prefilled 8000)

#### Data action buttons

| Action | Style | Flow |
|--------|-------|------|
| **Export CSV** | Primary outline (accent border) | System share sheet → file `astra-export-{date}.csv` |
| **Import CSV** | Secondary | File picker → validate → confirm if data exists → progress → success toast |
| **Delete all data** | Danger text button, bottom of section | → `ConfirmDialog` with export nudge (FR-21) |

| Action state | Visual |
|--------------|--------|
| **idle** | Default buttons |
| **in progress** | Spinner on button, disabled duplicate tap |
| **success** | Snackbar 3s: "Export saved" / "Import complete" |
| **error** | `StatusBanner` error variant with retry |

#### Post-purge state

Footprint KPIs → `0` / `0 KB`. Today ring → empty state. History → empty state. Banner: "All local data removed. Export anytime before deleting."

---

### 2.6 Onboarding Flow

**FR refs:** FR-22–24 · **UJ:** UJ-1  
Full-screen modal stack (not tabs). No back on step 1; progress dots optional (3 steps).

| Step | Screen | Content | Primary CTA |
|------|--------|---------|-------------|
| **1 Trust** | `OnboardingTrust` | Headline: "Your steps stay on this device." Body: local-only, no account, no cloud. Illustration: minimal device + lock optional | Continue |
| **2 Permissions** | `OnboardingPermissions` | Explain activity recognition first. Button triggers OS dialog. Notification = separate optional toggle with "Notify when daily goal reached" | Allow activity · Skip notifications |
| **3 Goal** | `OnboardingGoal` | Free numeric field, default 8000 (A-3). Copy: set once, change later in My Data | Start tracking |

**Rules:**
- Trust copy **before** permission request (FR-22)
- Skip on goal → applies default 8000
- On complete → land on **Today** tab
- Never show account/email fields

---

### 2.7 Component Inventory (Flutter-oriented)

| Widget | Surface | Priority |
|--------|---------|----------|
| `GoalRing` | Today | P0 |
| `AppBottomNav` | Shell | P0 |
| `StepBarChart` | History | P0 |
| `PeriodToggle` | History | P0 |
| `FootprintKpiRow` | My Data | P0 |
| `BackgroundStatusCard` | My Data | P0 |
| `GoalEditorSheet` | My Data | P0 |
| `DataActionRow` | My Data | P0 |
| `StatusBanner` | Shared | P0 |
| `ConfirmDialog` | Shared | P0 |
| `OnboardingPage` ×3 | Onboarding | P0 |
| `GoalCelebration` | Today | P0 (FR-15) |
| `TrendChip` | History | P1 |
| `SourceChip` | Today | P1 |

---

### 2.8 State Matrix (cross-surface)

| Event | Today | History | My Data |
|-------|-------|---------|---------|
| First launch | empty → onboarding | empty | footprint 0 |
| Permission granted | progress | — | status ok |
| Background sync | count updates | bars grow | last sync updates |
| Goal reached | **`GoalCelebration`** once (§2.3.1) | — | — |
| Stale >12h | **compact** stale banner | — | **full** stale banner |
| Export | — | — | success snackbar |
| Import | ring refreshes | chart refreshes | footprint updates |
| Purge | empty | empty | zeros + confirm was shown |
| Airplane 24h | works offline | works offline | export works (SM-3) |

### 2.9 Decisions Log (Bloc 2)

| # | Decision | Status | Resolution |
|---|----------|--------|------------|
| D-6 | Goal celebration | **Locked** | `GoalCelebration` composite — ring pulse + glow + shimmer + optional micro-copy (§2.3.1) |
| D-7 | My Data footer | **Locked** | No README / external link in Phase 0 |
| D-8 | Goal editor input | **Locked** | Free numeric text field, 1k–100k validation |
| D-9 | Stale banner placement | **Locked** | Compact on Today + full on My Data |

---

## 3. Screen Flows & Wireframes (Bloc 3)

Text wireframes for Phase 0. All surfaces use `AppScaffold` + bottom tabs except onboarding (full-screen stack).

---

### 3.1 App Map

```
[First launch]
     │
     ▼
[Onboarding 1→2→3] ──► [Today] ◄──► [History]
                           │
                           ▼
                       [My Data]
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        [GoalEditor]  [Share export]  [Purge confirm]
         bottom sheet   OS sheet       dialog
              │
              ▼
        [File picker import]
```

---

### 3.2 Today — default (UJ-2)

```
┌─────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  bg.base
│                                     │
│   ┌─ stale-compact (if >12h) ───┐   │  optional, ~40dp
│   │ Steps may be delayed —      │   │
│   │ see My Data                 │   │
│   └─────────────────────────────┘   │
│                                     │
│            ╭───────────╮            │
│           ╱   6 420     ╲           │  GoalRing + GoalCelebration
│          │  steps today  │          │  when threshold crossed
│          │  goal 8 000   │          │
│           ╲             ╱           │
│            ╰───────────╯            │
│                                     │
│         ┌───────────────┐           │
│         │ 📱 Phone sensor│           │  SourceChip
│         └───────────────┘           │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  ◉ Today    ○ History   ○ My Data   │  tab bar
└─────────────────────────────────────┘
```

**Entry:** Default tab after onboarding; app resume lands last tab or Today `[ASSUMPTION: always Today on cold start]`.

**Exit:** Tab → History / My Data. No drill-down screens in Phase 0.

---

### 3.3 Today — goal celebration moment (FR-15)

Same layout; animation overlays ring (§2.3.1). Sequence:

```
t=0s    steps cross 8 000 (background or foreground)
t=0s    ring completes to 360°
t=0–0.6s  scale pulse + glow + shimmer
t=0.3s  haptic (Android)
t=0.5s  micro-copy "Daily goal reached" fades in below chip
t=2.5s  micro-copy fades out
        ── no repeat until next local day ──
```

If user on History when goal crossed → celebration deferred to next Today visit.

---

### 3.4 History — 7d view (UJ-3)

```
┌─────────────────────────────────────┐
│                                     │
│  History                            │  type.title (optional)
│                                     │
│  ┌─────────────┬─────────────┐      │
│  │  7 days  ■  │   30 days   │      │  PeriodToggle
│  └─────────────┴─────────────┘      │
│                                     │
│  ↑ Up 12% from last week            │  TrendChip (P1)
│                                     │
│  ┌─────────────────────────────┐    │
│  │     ▄                       │    │
│  │   ▄ █     ▄   ▄             │    │  StepBarChart
│  │ ▄ █ █ ▄ ▄ █ ▄ █             │    │  bars: accent-muted
│  │─ ─ ─ ─ ─ ─ ─ ─ ─ ─ goal ─   │    │  dashed goal line
│  │ M  T  W  T  F  S  S         │    │
│  └─────────────────────────────┘    │
│                                     │
├─────────────────────────────────────┤
│  ○ Today    ◉ History   ○ My Data   │
└─────────────────────────────────────┘
```

**Interaction:** Toggle 7d ↔ 30d re-queries SQLite; chart rebind without transition animation (KPI-01).

**Empty state:** Centered copy in chart area — "No history yet. Walk a bit — data stays on this device."

---

### 3.5 My Data — healthy state (UJ-4)

```
┌─────────────────────────────────────┐
│                                     │
│  My Data                            │
│                                     │
│  ┌─ Background ─────────────────┐   │
│  │ ● Active · Last sync 14m ago │   │  BackgroundStatusCard ok
│  └──────────────────────────────┘   │
│                                     │
│  ┌─ Footprint ──────────────────┐   │
│  │  12 480      2.4 MB          │   │  FootprintKpiRow
│  │  samples     stored          │   │
│  │  optimized 2 days ago        │   │
│  └──────────────────────────────┘   │
│                                     │
│  ┌─ Daily goal ─────────────────┐   │
│  │  Daily step goal      8 000 >│   │  tap → GoalEditor sheet
│  └──────────────────────────────┘   │
│                                     │
│  ┌─ Your data ──────────────────┐   │
│  │  [ Export CSV ]              │   │  outline primary
│  │  [ Import CSV ]              │   │  secondary
│  │  Delete all local data       │   │  danger text
│  └──────────────────────────────┘   │
│                                     │
├─────────────────────────────────────┤
│  ○ Today    ○ History   ◉ My Data   │
└─────────────────────────────────────┘
```

---

### 3.6 My Data — stale state (FR-5)

```
┌─ ⚠ stale-full ─────────────────────┐
│ No new steps in 12+ hours.         │
│ Background collection may be       │
│ delayed on this device.            │
└────────────────────────────────────┘
        + BackgroundStatusCard (stale dot)
        + Today shows stale-compact in parallel
```

Copy never implies user fault. iOS adds info variant: "Steps update when you open the app on this device."

---

### 3.7 Onboarding flow (UJ-1)

**Step 1 — Trust (FR-22)**

```
┌─────────────────────────────────────┐
│              ● ○ ○                  │  progress dots
│                                     │
│     Your steps stay on              │
│     this device.                    │  Darker Grotesque headline
│                                     │
│     No account. No cloud.           │  Figtree body
│     Your data is stored locally     │
│     and never sent anywhere.        │
│                                     │
│                                     │
│     [ Continue ]                    │  primary
└─────────────────────────────────────┘
```

**Step 2 — Permissions**

```
│     To count steps, ASTRA needs     │
│     activity access on this phone.  │
│                                     │
│     [ Allow activity access ]       │  → OS permission dialog
│                                     │
│     ☐ Notify when daily goal        │  optional toggle
│       is reached                    │
│     [ Skip notifications ]          │  ghost
```

**Step 3 — Goal (FR-23)**

```
│     Set a daily step goal           │
│                                     │
│     ┌─────────────────────────┐     │
│     │  8000                   │     │  numeric field, free input
│     └─────────────────────────┘     │
│     Change anytime in My Data.      │
│                                     │
│     [ Start tracking ]              │
```

**Flow rules:**
- Back allowed on steps 2–3 only
- Skip goal → 8000 default
- Complete → Today tab, onboarding never shown again

---

### 3.8 Goal Editor sheet (D-8)

```
┌─────────────────────────────────────┐
│  ───                                │  drag handle
│  Daily step goal                      │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  8000                       │    │  number pad keyboard
│  └─────────────────────────────┘    │
│  Enter a value between 1,000        │  helper / inline error
│  and 100,000.                       │
│                                     │
│  [ Save ]              [ Cancel ]   │
└─────────────────────────────────────┘
```

Invalid input → Save disabled + red helper text. Valid save → sheet closes, Today ring recalculates %.

---

### 3.9 Export flow (FR-19)

```
My Data → tap Export CSV
    │
    ▼
[Spinner on button ~1s]
    │
    ▼
[Android share sheet / iOS share]
    file: astra-export-2026-05-22.csv
    │
    ▼
[Snackbar: "Export saved" 3s]
```

No network required (SM-3). User picks destination (Files, Drive locally, etc.) — app does not upload.

---

### 3.10 Import flow (FR-30)

```
My Data → tap Import CSV
    │
    ▼
[OS file picker — filter .csv]
    │
    ├─ invalid headers ──► StatusBanner error + retry
    │
    ├─ valid + existing data ──► ConfirmDialog "Replace all data?"
    │                              Show: N samples will be imported
    │                              [Replace] [Cancel]
    │
    └─ valid + empty DB ──► import directly
                │
                ▼
         [Progress indicator]
                │
                ▼
         Snackbar "Import complete"
         Today + History refresh
         Footprint KPIs update
```

**Round-trip path (beta checklist):** Export → Purge → Import → charts show restored history.

---

### 3.11 Purge flow (FR-20, FR-21)

```
My Data → tap Delete all local data
    │
    ▼
┌─ ConfirmDialog ─────────────────────┐
│  Delete all local data?             │
│                                     │
│  This removes all step history      │
│  on this device. Export first       │
│  if you want to keep a copy.        │
│                                     │
│  [ Export first ]  [ Delete anyway ]│
│  [ Cancel ]                         │
└─────────────────────────────────────┘
    │
    ├─ Export first ──► export flow, dialog stays open
    │
    └─ Delete anyway ──► wipe timeseries_samples (+ related sample prefs)
                │       retain: daily_step_goal, onboarding flag (D-11)
                │
                ▼
         Today: empty ring (0) — goal % uses retained goal
         History: empty state
         My Data: 0 samples / 0 KB · goal row unchanged
         Snackbar: "All local data removed"
```

**Post-purge (D-11 — locked):** Retain `daily_step_goal` and onboarding completion flag. Purge removes **Timeseries Samples** and resets footprint counters only.

---

### 3.12 Edge-case flows

| Scenario | UX behavior |
|----------|-------------|
| **First install, permission denied** | Today: dashed ring, `--`, link "Open settings". My Data: permission banner. No blocking modal loop. |
| **Airplane mode 24h (SM-3)** | All surfaces work. Export/import via local storage. No error banners about network. |
| **Goal already met, open app PM** | Ring full, no celebration (already shown). Count shows actual steps. |
| **Midnight rollover** | Ring resets to new day 0%; celebration flag resets for new local day. |
| **Import malformed row** | Abort with error banner; no partial silent corruption (FR-30). |
| **Android FGS notification** | System notification for background health — separate from goal celebration notification (FR-25). |
| **Reduce motion** | GoalCelebration static variant (§2.3.1). |

---

### 3.13 Primary user journeys (traceability)

| Journey | Flow sections | FRs |
|---------|---------------|-----|
| **UJ-1** Privacy verify | §3.7 → §3.2 → airplane OK | FR-22–24, FR-18 |
| **UJ-2** Mid-day check | §3.2, §3.3 | FR-14–15, FR-4 |
| **UJ-3** Weekly history | §3.4 | FR-16–17 |
| **UJ-4** Export/purge | §3.5, §3.9–3.11 | FR-13, FR-19–21, FR-30 |
| **UJ-5** Builder validate | Dev inject (out of UX spec) | FR-1, FR-28 |

---

### 3.14 Decisions Log (Bloc 3)

| # | Decision | Status | Resolution |
|---|----------|--------|------------|
| D-10 | Cold start tab | **Assumed** | Land on Today after onboarding |
| D-11 | Post-purge goal | **Locked** | Retain `daily_step_goal`; wipe samples only (Baptiste confirmed) |

---

## 4. Accessibility & Polish (Bloc 4)

Phase 0 target: **WCAG 2.1 AA aspirational** (NFR-5, A-6) — not blocking beta, but implement baseline patterns now to avoid retrofit pain.

---

### 4.1 Contrast & Color

| Pair | Ratio (approx) | Use | Phase 0 rule |
|------|----------------|-----|--------------|
| `#F4F5F7` on `#0F1114` | ~16:1 | Body, hero numbers | ✅ AA all sizes |
| `#9CA3AF` on `#0F1114` | ~7:1 | Captions, labels | ✅ AA normal text |
| `#6B7280` on `#0F1114` | ~4.6:1 | Muted footnotes | ⚠️ Large text / non-critical only |
| `#EAD55E` on `#0F1114` | ~10:1 | Accent stroke, icons | ✅ UI components |
| `#EAD55E` on `#1A1D23` (elevated) | ~9:1 | Primary button fill | Use **`color.text.inverse`** for button label (not amber on amber) |
| `#0F1114` on `#EAD55E` | ~10:1 | Primary button text | ✅ Locked pattern |

**Rules:**
- Never amber `#EAD55E` text on charcoal for paragraphs — accent is for strokes, icons, active tabs, button *backgrounds* with dark text.
- Status colors (`stale`, `danger`) always paired with Figtree body text in `color.text.primary`, not color-only meaning.

---

### 4.2 Touch & Target Sizes

| Element | Min size | Notes |
|---------|----------|-------|
| Tab bar items | 48×48dp | Icon + label hit area |
| Primary / secondary buttons | 48dp height | Full-width on onboarding OK |
| Goal editor row (My Data) | 48dp row height | Chevron `>` indicates affordance |
| Period toggle segments | 48dp height | Equal width segments |
| Delete all data | 48dp tap area | Text button with padding |
| Chart bars | Display only | No tap required Phase 0 |

---

### 4.3 Screen Reader & Semantics (Flutter)

| Widget | `Semantics` label (English UI) | Hint |
|--------|-------------------------------|------|
| `GoalRing` | "Steps today: {n} of {goal}" | Updates on sync |
| `GoalRing` (overflow) | "Steps today: {n}. Daily goal {goal} reached." | |
| `GoalCelebration` | Announce once: "Daily goal reached" | `liveRegion: polite` |
| `PeriodToggle` | "Chart range" | Selected: "7 days" / "30 days" |
| `StepBarChart` | "Step history bar chart" | Optional: skip per-bar unless selected |
| Export button | "Export data as CSV file" | |
| Import button | "Import CSV file" | |
| Purge button | "Delete all local data" | |
| Stale banner | Full banner text as label | Not icon-only |
| Tab bar | Standard `NavigationBar` semantics | |

**Progress ring:** Expose `value: steps/goal`, `min: 0`, `max: goal` for TalkBack/VoiceOver.

**Decorative elements:** Glow/shimmer in `GoalCelebration` marked `excludeSemantics: true`.

---

### 4.4 Text Scaling & Layout

- Support OS font scaling to **130%** without clipping hero count (ring scales down via `FittedBox` or responsive diameter).
- Onboarding and My Data scroll when text scale > 1.2.
- History chart: fixed min height 200dp; y-axis may hide at extreme scale — acceptable Phase 0.
- Avoid absolute px heights on copy blocks; use padding + flexible layout.

---

### 4.5 Motion & Cognitive

| Preference | Behavior |
|------------|----------|
| **Reduce motion** (OS) | `GoalCelebration` → static full ring + micro-copy fade only (§2.3.1) |
| **Reduce motion** | Disable ring scale pulse and glow; keep data updates instant |
| Tab / chart transitions | Respect reduce motion → instant swap |

No autoplay carousels, no infinite animations, no parallax.

---

### 4.6 Copy Guidelines (tone + regulatory)

**Voice:** Calm, factual, second person sparingly ("your data"), never judgmental.

| ✅ Say | ❌ Avoid |
|--------|---------|
| "Your steps stay on this device." | "We protect your data" (unverified claim) |
| "Daily goal reached" | "Amazing job!" / "You crushed it!" |
| "No new steps in 12+ hours" | "You haven't moved enough" |
| "Steps update when you open the app" (iOS) | "Background sync failed" (blaming) |
| "Delete all local data" | "Clear cache" (understates impact) |
| "Behavioral visibility tool" (README) | "Medical grade", "diagnose", "recovery score" |

**Numbers:** Locale-aware grouping (`8 000` FR display optional; store integer). Relative times: "14 min ago", "2 days ago".

**English UI** for Phase 0 OSS (NFR-6); French acceptable in README only.

---

### 4.7 Visual Polish Checklist (FR-29 / beta)

Use before beta handoff. Maps to PRD beta checklist visual cohesion items.

| # | Check | Pass criteria |
|---|-------|---------------|
| V-1 | Dark mode default | No light theme flash on launch |
| V-2 | Token consistency | All screens use `AstraColors` tokens — no hardcoded hex in widgets |
| V-3 | Typography | Figtree + Darker Grotesque only; no system font fallback visible unless bundle fail |
| V-4 | Tab cohesion | 3 tabs same bar style, amber active state |
| V-5 | Today hero | Ring + count + chip aligned center; no layout jump on sync |
| V-6 | GoalCelebration | Plays once/day; reduce-motion variant tested |
| V-7 | History perf | Chart bind <100ms with 90d inject (KPI-01) |
| V-8 | My Data hierarchy | Status → footprint → goal → actions order preserved |
| V-9 | Purge empty state | 0 samples, goal retained (D-11), no ghost data on Today |
| V-10 | Onboarding once | No re-show after complete; trust before permission |
| V-11 | Stale dual banner | Compact Today + full My Data when >12h |
| V-12 | Destructive clarity | Purge dialog mentions export; danger color on confirm only |
| V-13 | Screenshot readiness | Today + My Data framable for README GIF (SM-7) |

---

### 4.8 Decisions Log (Bloc 4)

| # | Decision | Status | Resolution |
|---|----------|--------|------------|
| D-12 | WCAG scope | **Locked** | AA aspirational; baseline §4.1–4.5 for Phase 0 |
| D-13 | Button label on amber | **Locked** | Inverse dark text on amber fills |
| D-14 | Semantics language | **Locked** | English labels matching NFR-6 UI |

---

## 5. Fast Pass Complete

### 5.1 Deliverable Summary

| Bloc | Section | Status |
|------|---------|--------|
| 1 | Visual foundation — charcoal + amber, Figtree/Darker Grotesque, ring/chart | ✅ |
| 2 | Components + states — 14 widgets, GoalCelebration, My Data sovereignty | ✅ |
| 3 | Flows + wireframes — onboarding, export/import/purge, edge cases | ✅ |
| 4 | Accessibility + polish + beta visual checklist | ✅ |

**Output file:** `_bmad-output/planning-artifacts/ux-design-specification.md`  
**Input PRD:** `prds/prd-astra-app-2026-05-22/prd.md`  
**Decisions:** D-1 through D-14 logged in §1.7, §2.9, §3.14, §4.8

### 5.2 PRD Traceability (UX-relevant FRs)

| FR | UX spec coverage |
|----|------------------|
| FR-5, FR-13 | §2.5 My Data footprint + stale |
| FR-14, FR-15 | §2.3 GoalRing + §2.3.1 GoalCelebration |
| FR-16, FR-17 | §2.4 History chart + trend |
| FR-19–21, FR-30 | §3.9–3.11 flows |
| FR-22–24 | §3.7 onboarding |
| FR-29 | §4.7 visual checklist |

### 5.3 Recommended Next Steps (BMad workflow)

1. **`[CA] Create Architecture`** — `bmad-create-architecture` (required gate, phase 3)
2. **`[CE] Create Epics and Stories`** — after architecture
3. **`[IR] Check Implementation Readiness`** — align PRD + this UX spec + architecture + epics
4. Optional: Figma high-fi mockups from §3 wireframes if needed before Sprint 1

---

*UX fast pass completed 2026-05-22 — Baptiste / astra-app Phase 0 Sandbox.*
