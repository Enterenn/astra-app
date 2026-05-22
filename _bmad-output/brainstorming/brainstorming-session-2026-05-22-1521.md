---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - 'PRD Astra v2.0 (Mai 2026) — user-provided inline'
  - 'Open Wearables docs — unified data model, data-types, timeseries API (May 2026 research)'
session_topic: 'Phase 0 Sandbox — App Flutter compteur de pas + stockage local buckets temporels, fondation écosystème Astra local-first'
session_goals: 'Générer des idées pour le MVP Phase 0 (architecture données, UX privacy-first, open-source, montée compétences Flutter) alignées sur la roadmap PRD vers ADP/SQLCipher/V1'
selected_approach: 'ai-recommended'
techniques_used:
  - Constraint Mapping
  - Mind Mapping
  - Reverse Brainstorming
ideas_generated: 75
session_active: false
workflow_completed: true
context_file: ''
amended: '2026-05-22 — V2 sync hub strategy (see Amendements post-recherche)'
---

# Brainstorming Session Results

**Facilitator:** Baptiste
**Date:** 2026-05-22

## Session Overview

**Topic:** Phase 0 Sandbox — Flutter app reading phone step count, persisting locally in time-bucketed `health_events` schema, as software R&D sandbox before hardware/ADP.

**Goals:** Ideate on Phase 0 deliverables, data architecture validation, open-source repo structure, Flutter learning path, and bridge toward Phase 1 (SQLCipher, BLE simulator, official UI).

**Scope confirmed:** A — Phase 0 only  
**Profile:** Solo UI/UX designer, front-end notions (HTML/CSS, Vue/React), Flutter novice

### Context Guidance (from PRD v2.0)

- **Vision:** Local-first ecosystem — wearable + mobile hub, zero cloud, zero account in V1.
- **Phase 0 scope:** Isolated Flutter sandbox via Cursor; `pedometer` package; simulated loop inserts; validate temporal bucket performance (<100ms charts after 3 months).
- **Data model target:** SQLite `health_events` table (UUID, ISO8601 windows, type like `steps`, device_id `smartphone` or `astra_v1`); semantic alignment with Open Wearables / HealthKit / Health Connect nomenclature.
- **Out of scope for Phase 0:** SQLCipher, BLE, wearable, ADP wire protocol, official branding.
- **Team constraints (adjusted):** Solo designer-developer; pragmatism — mature SDKs only.
- **Open source:** Full Flutter app code published; ADP specs later; brand/design controlled.

### Session Setup

User provided full PRD v2.0 to anchor global vision. Brainstorming session focuses narrowly on **Phase 0 execution ideas**, not full V1 hardware/firmware scope. Approach selected: **AI-Recommended Techniques**.

## Technique Selection

**Approach:** AI-Recommended Techniques  
**Analysis Context:** Phase 0 Sandbox with focus on solo designer executing Flutter MVP, privacy-first, open-source launch

**Recommended Techniques:**

- **Constraint Mapping:** Map real vs imagined constraints to define achievable solo Phase 0 scope
- **Mind Mapping:** Visual ideation across data, UI, tech, OSS, learning, and performance branches
- **Reverse Brainstorming:** Invert privacy failures into UX/architecture safeguards

**AI Rationale:** Solo UX designer with front-end background needs structured scope reduction first, visual divergent thinking second, and privacy differentiation through inversion third — aligned with frozen PRD Phase 0 deliverables without premature Phase 1 complexity.

## Technique Execution Results

### Constraint Mapping — Completed

**Interactive Focus:** Real vs imagined constraints; quality as funding/beta gate; beta audience (proches); CSV export as sovereignty signal.

**Key Breakthroughs:** Phase 0 = Beta/Investor-Ready Sandbox (not throwaway POC). Quality constraint R7 is strategic.

**User Creative Strengths:** Clear success criteria (accuracy, storage, reliability); strong product ethics (privacy, user control).

**Energy Level:** Reflective, decisive — quickly refined scope when challenged.

**Ideas #1–21**

---

### Mind Mapping — Completed

**Interactive Focus:** UI branch — goal ring, soft rewards, background watcher as ADP foundation.

**Key Breakthroughs:** BackgroundCollector + DataIngestionSource stub = wearable-ready architecture on phone. My Data = brand/privacy statement.

**Building on Previous:** Quality gate → 3 polished screens, not feature bloat.

**Ideas #22–51**

---

### Reverse Brainstorming — Completed

**Interactive Focus:** Privacy failures inverted; storage fear as primary risk; Open Wearables alignment research.

**Key Breakthroughs:** No-INTERNET manifest; single writer rule; OW-aligned `timeseries_samples` schema; downsampling tiers match OW resolution enum.

**Ideas #52–75**

---

## Idea Organization and Prioritization

### Thematic Organization

**Theme 1: Architecture & Data (Foundation)**
- #43 BackgroundCollector, #44 ADP-Ready DataIngestionSource stub, #55 Single Writer Rule
- #61 Tiered Downsampling, #62 5-Min Default Buckets, #70 resolution column, #71 Graph Auto-Select
- #73 OW-Aligned Schema, #74 SERIES_TYPES.md, #75 CSV as OW Import Bridge
- **Pattern:** Phone hub passif, schema export-ready, lifecycle anti-saturation

**Theme 2: Privacy & Sovereignty (Differentiation)**
- #16–20 CSV export suite, #52 No-Internet Manifest, #53 Airplane Mode Beta, #54 Dependency Transparency
- #58 Purge Proof Counter, #65 Storage Budget Dashboard, #68 Export Before Purge
- #36 Notification Permission as Trust Moment, #50/README privacy copy
- **Pattern:** My Data screen = proof of promise, not settings afterthought

**Theme 3: UX & Motivation (Beta-Ready Polish)**
- #25–32 Goal ring system, #34 Pulse Celebration, #40 Set-Once Goal Philosophy
- #14 Modern Minimal Shell, #24 Dark Mode Default, #23 My Data as Brand Statement
- #42 Goal Line on Weekly Chart, #6 Trust-First Beta onboarding
- **Pattern:** Modern restraint, gentle motivation, designer-led quality

**Theme 4: Background & Notifications (Non-Negotiable)**
- #35 Local Goal Notification, #37 One Notification Per Day, #38 Background Step Watcher
- #45 Platform-Native Stack (WorkManager / BGAppRefresh), #48 Background Status in My Data
- #56 Background Health Honesty, #57 Stale Data Warning, #69 Lifecycle in BackgroundCollector
- **Pattern:** Same pipeline for phone steps today and ADP wearable tomorrow

**Theme 5: Open Source & Beta (Launch)**
- #3 README as Pitch Deck, #15 README Beta Section, #11 Beta Feedback Loop (Local)
- #12 Accuracy Calibration, #60 90-Day Inject Benchmark, #67 Downsampling Dev Simulator
- **Pattern:** Repo credibility = unlock Phase 1 + funding narrative

### Cross-Cutting Concepts

- **Investor/Beta-Ready Sandbox:** Quality + OSS + working demo > feature count
- **Astra ≠ Open Wearables:** Complementary layers (local hub vs server API); align schema now, integrate API V2 later
- **Storage fear → lifecycle engine:** Downsampling + VACUUM + footprint UI = user trust + technical proof

### Prioritization Results

**Top Priority (Must Ship Phase 0):**
1. BackgroundCollector + SQLite `timeseries_samples` (OW-aligned)
2. 3 screens: Today (goal ring) / History / My Data (sovereignty)
3. DataLifecycleService (downsampling + VACUUM + 90-day benchmark)
4. Local goal notification via background watcher
5. CSV export + README pitch + MIT license

**Quick Wins:**
- Design Token Lite (#2), Dark mode default (#24)
- Storage footprint badge (#8, #65)
- Airplane mode beta protocol (#53)

**Breakthrough (Strategic):**
- DataIngestionSource abstraction (#44) — bridges Phase 0 → ADP
- OW schema alignment (#73) — zero refactor for V2 export

---

## Action Planning — Phase 0 Implementation Roadmap

### Sprint 0: Repo & Schema (Week 1)

1. Init Flutter project in public GitHub repo — MIT LICENSE, README vision + GIF placeholder
2. Create `docs/OPEN_WEARABLES_ALIGNMENT.md` + `docs/SERIES_TYPES.md`
3. Implement SQLite `timeseries_samples` + `user_preferences` (daily_step_goal)
4. Implement `DataIngestionSource` interface + `PhonePedometerSource` + empty `AdpBleSource` stub
5. Android: remove INTERNET permission from manifest (#52)

**Success:** App launches, DB migrates, schema documented.

### Sprint 1: Background Pipeline (Week 2–3)

1. `BackgroundCollector` — single writer to SQLite, buckets 5 min, `type=steps`, `unit=count`
2. Platform background: WorkManager (Android) + BGAppRefresh (iOS) — priority Android beta first
3. `GoalCheckpoint` — local notification 1×/day when goal reached (#37)
4. `DataLifecycleService` — downsampling 5min→1hour (>30d), VACUUM weekly (#61, #66)
5. Dev tools: inject 90 days + downsampling simulator (#60, #67)

**Success:** Steps persist without app open; DB size bounded; benchmark <100ms charts.

### Sprint 2: UI Polish (Week 3–4)

1. **Today:** Goal ring, pulse celebration (#34), step source label (#7)
2. **History:** 7/30 day bars, goal line (#42), weekly trend (#10)
3. **My Data:** Footprint (#65), purge proof (#58), CSV export OW columns (#16–19), background status (#48)
4. Onboarding: trust screen (#6) + goal setup (#26) + notification opt-in (#36)
5. Design tokens — dark mode default (#24)

**Success:** Beta checklist pass (see below).

### Sprint 3: Beta & OSS (Week 5)

1. README: vision, architecture diagram, airplane mode test (#53), beta instructions (#15)
2. `docs/DEPENDENCIES.md` — network audit (#54)
3. Beta with proches — feedback via local export (#11)
4. Record GIF for README (goal ring fill + CSV export)

**Success:** Ready to unlock Phase 1 narrative + potential funding conversations.

---

## Beta Acceptance Checklist

- [ ] Steps accurate vs native Health app (± acceptable margin, #59)
- [ ] Background collection works without opening app (#38)
- [ ] Goal notification fires once per day (#37)
- [ ] DB footprint visible and reasonable after 90-day inject (#65, #60)
- [ ] Purge shows 0 events / 0 Ko (#58)
- [ ] CSV export readable, OW-aligned columns (#75)
- [ ] 24h airplane mode — app fully functional (#53)
- [ ] 3 screens visually cohesive (R7 quality gate)

---

## Open Wearables Alignment Summary

| Astra Phase 0 | Open Wearables |
|---------------|----------------|
| `timeseries_samples` table | `DataPointSeries` / `TimeSeriesSample` API |
| `type=steps`, `unit=count` | SeriesType enum |
| `resolution`: 5min, 1hour, 1d | API resolution param + lifecycle |
| `provider` + `device` | `SourceMetadata` |
| `zone_offset` on timestamps | Required OW field |
| CSV export | Bridge to OW import (V2 API optional) |

Reference: [Unified Data Model](https://openwearables.io/docs/architecture/unified-data-model.md), [Data Types](https://openwearables.io/docs/architecture/data-types.md)

---

## PRD Updates Recommended

1. Rename `health_events` → `timeseries_samples` with OW fields
2. Add `DataLifecycleService` to Phase 0 deliverables
3. Elevate BackgroundCollector to core architecture (not stretch)
4. Document Open Wearables alignment as explicit Phase 0 goal

---

## Session Summary and Insights

**Key Achievements:**
- 75 ideas across 3 techniques; converged to actionable 5-sprint Phase 0 plan
- Resolved tension: quality polish vs scope — Beta/Investor-Ready Sandbox model
- Storage fear addressed with lifecycle architecture aligned to OW resolution tiers
- Clear differentiation: Astra = local hub + ADP; OW = optional export destination V2

**Session Reflections:**
- User's designer profile = UX/privacy as competitive moat, not afterthought
- Background watcher decision correctly reframes Phase 0 as ADP precursor
- Solo execution viable with mature Flutter packages + Cursor co-dev + ruthless scope

**Recommended Flutter Packages:**
- `pedometer` or Health Connect path (Android priority)
- `sqflite`, `flutter_local_notifications`, `workmanager`
- `fl_chart`, `share_plus`, `permission_handler`

---

## Creative Facilitation Narrative

Session evolved from generic step-counter idea to a precise **local-first hub architecture** validated against Open Wearables industry standard. Constraint Mapping surfaced quality-as-funding-gate. Mind Mapping anchored background collection as non-negotiable ADP foundation. Reverse Brainstorming converted storage anxiety into downsampling lifecycle — the same problem Open Wearables acknowledges in their unified model roadmap.

**User Creative Strengths:** Strong ethical product vision, clear beta criteria, willingness to cut auto-suggestions while keeping user empowerment.

**Breakthrough Moment:** Background watcher = not a feature but the prototype of Astra's passive data hub — phone today, wearable tomorrow.

---

## Amendements post-recherche (2026-05-22)

> **Contexte :** Clarifications produit après market research et domain research express. La session ci-dessus reste l'archive des idées Phase 0 ; seules les projections V2+ ci-dessous sont révisées.

### V2+ — Sync multi-devices (futur, pas V1)

- **V1 inchangée :** local-only, sans compte, sans cloud.
- **V2+ (opt-in) :** accès aux données depuis plusieurs appareils via un **hub sync Astra** :
  - **Self-hosted** — profils techniques déploient leur propre serveur (Docker, VPS, homelab)
  - **Managed cloud (payant)** — même fonctionnalité, hébergée par Astra, pour profils novices
- **Conformité :** le tier managed cloud exige le respect complet des lois données santé (GDPR Art. 9, HDS France, etc.) — voir domain research §4.4.

### Relation Open Wearables — révision stratégique

| Période | Position OW | Action |
|---------|-------------|--------|
| **Phase 0–V1** | Référence schéma / vocabulaire timeseries | Conserver alignement `timeseries_samples`, CSV export, `SERIES_TYPES.md` |
| **V2+** | **Concurrent potentiel** sur la couche serveur sync | Hub sync Astra propre (self-host + managed) — pas export/import OW comme stratégie V2 |
| **Interop optionnelle** | Pont CSV ou API reste possible | Décision différée ; pas de dépendance OW |

**Corrections par rapport à cette session :**
- ~~« integrate API V2 later »~~ → hub sync Astra en V2+
- ~~« OW = optional export destination V2 »~~ → hub Astra ; OW = référence Phase 0, concurrent possible V2+
- ~~« Bridge to OW import (V2 API optional) »~~ → CSV export conservé ; interop OW non prioritaire

**Inchangé (Phase 0) :** BackgroundCollector, OW-aligned schema, DataLifecycleService, My Data sovereignty, no-INTERNET manifest.

