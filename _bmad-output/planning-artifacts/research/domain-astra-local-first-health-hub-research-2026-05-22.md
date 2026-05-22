---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - README.md
  - _bmad-output/brainstorming/brainstorming-session-2026-05-22-1521.md
  - _bmad-output/planning-artifacts/research/market-astra-local-first-health-hub-research-2026-05-22.md
  - 'PRD Astra v2.0 (referenced in brainstorming session)'
workflowType: 'research'
lastStep: 6
research_type: 'domain'
research_topic: 'Local-first privacy-focused mobile health hub and wearable ecosystem (Astra App)'
research_goals: 'Map domain vocabulary, industry standards, regulatory boundaries, and technical constraints for Phase 0 sandbox and V1 wearable ecosystem'
user_name: 'Baptiste'
date: '2026-05-22'
web_research_enabled: true
source_verification: true
research_mode: 'express'
---

# Research Report: domain

**Date:** 2026-05-22  
**Author:** Baptiste  
**Research Type:** domain (express mode)

---

## Research Overview

This express domain research maps the **industry, regulatory, and technical domain** in which Astra App operates: a local-first Flutter mobile health hub evolving toward a proprietary BLE wearable (ADP) ecosystem.

Unlike market research (which asks *"who buys and who competes?"*), domain research answers *"what are the rules, standards, and constraints of this field?"*

**Key domain findings:**

1. **Astra sits at the intersection of three domains** — consumer wellness tracking, personal health data governance (GDPR/CNIL), and wearable device interoperability (HealthKit / Health Connect / Open Wearables / BLE).
2. **Regulatory advantage of local-only architecture** — CNIL explicitly recognizes that apps storing health data *locally only, without external connection, for exclusively personal use* may fall outside GDPR processor obligations ([CNIL Recommandation mobile, avril 2025](https://cnil.fr/sites/default/files/2025-04/recommandation-applications-mobiles-modifiee.pdf)).
3. **Phase 0 is firmly in "general wellness" territory** — FDA General Wellness Policy (revised Jan 2026) excludes low-risk lifestyle software from device regulation if no clinical claims are made ([FDA](https://www.fda.gov/medical-devices/digital-health-center-excellence/step-3-software-function-intended-maintaining-or-encouraging-healthy-lifestyle)).
4. **Open Wearables is the emerging interoperability standard** — unified timeseries/events schema, MIT-licensed, actively evolving; Astra's OW alignment is architecturally sound.
5. **Background collection is the hardest technical domain constraint** — Android 14+ requires `foregroundServiceType="health"`; iOS throttles background delivery; platform APIs (Health Connect, HealthKit) are the de facto ingestion layer.

Full analysis below.

---

# Domain Research: Local-First Health Hub & Wearable Ecosystem

## Executive Summary

The **personal health data hub** domain is defined by a tension between three forces:

| Force | Domain expression | Astra implication |
|-------|-------------------|-------------------|
| **Platform sovereignty** | Apple HealthKit / Google Health Connect as OS-level health vaults | Phase 0 reads phone sensors; must respect platform permission models |
| **Cloud aggregation** | Garmin, WHOOP, Fitbit, Open Wearables server APIs | Astra rejects this model in V1; OW is optional export, not dependency |
| **Data sovereignty regulation** | GDPR Art. 9, EHDS (2025–2027), CNIL, state US privacy laws | Local-only architecture is a domain-native compliance strategy, not a workaround |

Astra's domain positioning is **"personal wellness instrument, not medical device, not cloud health platform."** This boundary must be maintained in product copy, feature scope, and regulatory posture through V1.

---

## 1. Domain Definition & Scope

### 1.1 What Domain Is Astra In?

Astra operates across overlapping but distinct sub-domains:

```
┌─────────────────────────────────────────────────────────────┐
│                    DIGITAL HEALTH DOMAIN                     │
├──────────────┬──────────────┬──────────────┬──────────────┤
│  Wellness    │  PGHD        │  Wearable    │  Data        │
│  & Fitness   │  (Patient-   │  Hardware    │  Sovereignty │
│  Tracking    │  Generated   │  & BLE       │  & Privacy   │
│              │  Health Data)│  Protocols   │              │
├──────────────┴──────────────┴──────────────┴──────────────┤
│  ★ ASTRA Phase 0: Wellness + PGHD + Data Sovereignty      │
│  ★ ASTRA V1+: adds Wearable Hardware + BLE (ADP)          │
└─────────────────────────────────────────────────────────────┘
```

**Domain vocabulary (essential terms):**

| Term | Definition | Astra usage |
|------|------------|-------------|
| **PGHD** | Patient-Generated Health Data — data created by individuals via apps/wearables, outside clinical settings | Steps, activity buckets in `timeseries_samples` |
| **HealthKit** | Apple's on-device health data store (iOS) | Optional Phase 0+ read path; not required for pedometer-only sandbox |
| **Health Connect** | Google's on-device health platform (Android); replaces Google Fit | Future Android ingestion; no cloud API ([OW docs](https://openwearables.io/integrations/google-health-connect/)) |
| **Timeseries sample** | Point-in-time health measurement (steps, HR, etc.) with timestamp + value + unit | Core Astra data primitive (OW-aligned) |
| **Event record** | Duration-bound health event (workout, sleep session) | Phase 1+ scope |
| **General wellness product** | FDA category: lifestyle maintenance, low risk, no disease claims | Phase 0–V1 regulatory boundary |
| **Special category data** | GDPR Art. 9: health data requiring explicit consent | Applies if EU users + cloud processing; mitigated by local-only |
| **EHDS** | European Health Data Space — EU framework for health data reuse (applicable March 2027) | Secondary-use only; wellness apps status unclear ([npj Digital Medicine, 2025](https://www.nature.com/articles/s41746-025-02147-3)) |
| **ADP** | Astra Device Protocol — proprietary BLE wire protocol (Phase 1+) | Domain-specific; aligns with BLE GATT/GHSP patterns |
| **Local-first** | Device is source of truth; cloud is optional sync relay | Core architectural domain principle |

### 1.2 Domain Boundaries (What Astra Is NOT)

| Adjacent domain | Boundary | Risk if crossed |
|-----------------|----------|-----------------|
| **Medical device (FDA/CE)** | No diagnosis, treatment, clinical thresholds | Premarket review, liability |
| **HIPAA-covered entity** | No provider/payer relationship | BAA obligations, audit |
| **HDS (Hébergeur Données de Santé)** | No third-party hosting of French health data | French certification required |
| **Clinical EHR / FHIR** | Not a medical record system | HealthWallet.me territory |
| **Cloud health platform** | No server-side user accounts in V1 | GDPR processor role, breach surface |

---

## 2. Industry Standards & Interoperability Landscape

### 2.1 Platform Layer (OS Health Stores)

| Standard | Owner | Scope | Astra relationship |
|----------|-------|-------|-------------------|
| **Apple HealthKit** | Apple | iOS on-device health vault | Read/write via permissions; HKQuantityTypeIdentifier.stepCount for steps |
| **Google Health Connect** | Google | Android on-device; StepsRecord, permissions model | Android Phase 0+ path; requires `READ_STEPS`, background permissions on API 33+ ([Android Developers](https://developer.android.com/health-and-fitness/health-connect/data-types)) |
| **Samsung Health SDK** | Samsung | Android alternative/addition | Supported by OW SDK; secondary Android path |

**Domain rule:** HealthKit and Health Connect are **read aggregators**, not product backends. The OS health store is the interoperability hub for consumer wearables — Astra either reads from it or bypasses it with direct sensor access (pedometer).

### 2.2 Aggregation Layer (Server/API)

| Standard | Model | Astra relationship |
|----------|-------|-------------------|
| **Open Wearables** | Self-hosted unified REST API; timeseries + events + health scores; MIT | Schema alignment target; reference architecture for V2 dual deployment (OSS self-host + managed) ([Unified Data Model](https://openwearables.io/docs/architecture/unified-data-model)) |
| **FHIR R4** | Clinical interoperability (HL7) | Out of scope V1; relevant only if medical record integration planned |
| **IEEE 11073** | Personal Health Device semantic model | Underlying BLE health device semantics (via GHSP) |

**Open Wearables unified model (domain-relevant entities):**

| OW Entity | Astra Phase 0 equivalent |
|-----------|-------------------------|
| `DataPointSeries` | `timeseries_samples` table |
| `SeriesTypeDefinition` | `type` + `unit` columns (e.g., steps/count) |
| `ExternalDeviceMapping` | `provider` + `device_id` fields |
| `EventRecord` | Future workouts/sleep events |
| Resolution / downsampling tiers | `DataLifecycleService` resolution enum |

### 2.3 Device Layer (BLE Protocols)

| Standard | Scope | Astra V1 relevance |
|----------|-------|-------------------|
| **BLE GATT** | Generic Attribute Profile — transport | ADP foundation |
| **GHSP / GHSS** | Generic Health Sensor Profile/Service — IEEE 11073 ACOM over GATT | Reference for ADP semantic layer ([Bluetooth SIG GHSP v1.0](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/GHSP_v1.0/out/en/index-en.html)) |
| **HDP + MCAP** | Classic Bluetooth health device profile | Legacy; not recommended for new BLE wearables |
| **Custom GATT services** | Vendor-specific (WHOOP, Polar, etc.) | ADP will be proprietary; OW-normalized at app layer |

**Domain insight for ADP design:** Industry trend is toward **GATT + semantic health models** (GHSP/IEEE 11073) rather than proprietary binary protocols. Astra's ADP should consider GHSP-compatible observation types even if wire format is custom — reduces future interoperability friction.

### 2.4 Mobile Development Domain (Flutter Ecosystem)

| Package / SDK | Role | Phase 0 consideration |
|---------------|------|------------------------|
| `pedometer` | Direct step sensor access | Phase 0 primary (Android priority) |
| `sqflite` | Local SQLite | Core persistence |
| `workmanager` | Android background tasks | BackgroundCollector |
| `flutter_local_notifications` | Goal notifications | Background watcher output |
| `health_connector` / `health` | HealthKit/Health Connect abstraction | Phase 0+ optional upgrade path |
| `open_wearables_health_sdk` | Background sync to OW backend | **Not for V1** (requires cloud); useful reference for Health Connect patterns ([pub.dev](https://pub.dev/packages/open_wearables_health_sdk)) |

---

## 3. Regulatory Domain

### 3.1 EU / France (Primary for Baptiste)

#### GDPR — Special Category Health Data

Step counts and activity data are **health data under GDPR** when they reveal information about physical health ([Custodia GDPR guide](https://app.custodia-privacy.com/blog/gdpr-wearables-health-tech)):

- **Art. 9(2)(a):** Explicit consent required for processing special category data
- **Art. 25:** Privacy by design and by default
- **Art. 20:** Data portability (CSV export = domain-compliant feature)

**Critical CNIL exception for Astra architecture (April 2025):**

> *"Application mobile en santé : c'est le cas lorsque l'application enregistre et conserve les données de manière uniquement locale, sans connexion extérieure et à des fins exclusivement personnelles, sans que l'application ne propose de fonctionnalités permettant d'assurer un service à distance à son utilisateur."*
> — [CNIL Recommandation applications mobiles modifiée, avril 2025](https://cnil.fr/sites/default/files/2025-04/recommandation-applications-mobiles-modifiee.pdf)

**Domain implication:** Astra Phase 0/V1 local-only, no-account architecture may **fall outside GDPR processor obligations** entirely — the user is the sole controller. This is a structurally unique regulatory position vs. all cloud competitors.

**Caveats:**
- Applies only while no cloud sync, no remote service, no third-party data sharing
- **V2+ multi-device sync** (self-hosted or managed cloud — see §4.4) reintroduces full GDPR obligations; CNIL local-only exception no longer applies for that flow
- App Store privacy nutrition labels still required

#### EHDS (European Health Data Space)

- **In force:** 26 March 2025 | **Applicable:** 26 March 2027 ([European Commission](https://health.ec.europa.eu/ehealth-digital-health-and-care/reuse-health-data_en))
- Covers secondary use of health data including wearables/mobile apps
- EDPB urged explicit consent for PGHD secondary use ([npj Digital Medicine, 2025](https://www.nature.com/articles/s41746-025-02147-3))
- **Wellness app inclusion in mandatory EHDS transfer remains unclear** — monitor 2026–2027 guidance

#### France-Specific

| Requirement | Applies to Astra? | Notes |
|-------------|-------------------|-------|
| **HDS certification** | No (V1 local-only) | **Required for V2 managed cloud** if Astra hosts French users' health data; not required for user self-hosted deployment ([CNIL](https://cnil.fr/fr/applications-mobiles-en-sante-et-protection-des-donnees-personnelles-les-questions-se-poser)) |
| **CNIL formalités préalables** | Unlikely (local-only wellness) | Required for health data processing by organizations; Art. 65 exemptions for certain cases ([CNIL](https://www.cnil.fr/fr/quelles-formalites-pour-les-traitements-de-donnees-de-sante)) |
| **Code de la santé publique** | No (wellness scope) | Applies to telemedicine, medical devices |

### 3.2 United States

| Framework | Scope | Astra Phase 0 |
|-----------|-------|---------------|
| **FDA General Wellness** | Low-risk lifestyle products; enforcement discretion | ✅ Step counter + goal ring = general wellness if no clinical claims ([FDA Step 3 guidance](https://www.fda.gov/medical-devices/digital-health-center-excellence/step-3-software-function-intended-maintaining-or-encouraging-healthy-lifestyle)) |
| **FDA revised policy (Jan 2026)** | Clarifies non-invasive sensing wearables can be wellness products | ✅ Relevant for future Astra wearable with accelerometer/PPG ([Covington analysis](https://www.cov.com/en/news-and-insights/insights/2026/01/fda-issues-revised-guidance-on-general-wellness-products)) |
| **HIPAA** | Covered entities only | ❌ Not applicable |
| **State privacy laws** (CA, NY, etc.) | Consumer health data | ⚠️ Applies if US users + any cloud processing; mitigated by local-only |

**FDA boundary rules for Astra (domain guardrails):**

| Allowed (wellness) | Prohibited (medical device territory) |
|---------------------|---------------------------------------|
| Step counting, activity tracking | Diagnosis of disease/condition |
| Daily goal setting, gentle motivation | Clinical thresholds ("see a doctor if…") |
| Sleep duration (accelerometer) | AFib detection without clearance |
| Recovery/strain scores (wellness framing) | Blood pressure values mimicking clinical unless validated |
| CSV export of personal data | Claims of substituting medical devices |

### 3.3 App Store Platform Rules

| Platform | Domain requirement | Astra action |
|----------|-------------------|--------------|
| **Apple App Store** | `PrivacyInfo.xcprivacy` mandatory for HealthKit apps; no ad use of health data | Declare if HealthKit used; Phase 0 pedometer-only may avoid HealthKit initially |
| **Google Play** | Privacy policy URL; Health Connect permissions declared in manifest | `FOREGROUND_SERVICE_HEALTH` for background health collection ([Android 14 FGS types](https://developer.android.com/about/versions/14/changes/fgs-types-required)) |
| **Both** | Accurate privacy nutrition labels | "Data not collected" if truly local-only |

---

## 4. Technical Domain Constraints

### 4.1 Background Data Collection (Critical Path)

Background step collection is the **dominant technical domain constraint** for Phase 0 credibility.

| Platform | Mechanism | Domain constraint |
|----------|-----------|-------------------|
| **Android 14+** | `WorkManager` + optional `health` foreground service type | Must declare `FOREGROUND_SERVICE_HEALTH`; Play rejects `dataSync` type for health data ([OW SDK docs](https://pub.dev/packages/open_wearables_health_sdk)) |
| **Android Health Connect** | On-device only; background read needs `READ_HEALTH_DATA_IN_BACKGROUND` (API 33+) | Permission UX is a trust moment ([Android Developers](https://developer.android.com/health-and-fitness/health-connect/data-types)) |
| **iOS** | `BGAppRefreshTask` + HealthKit background delivery | Opportunistic (~15–30 min); not real-time ([DEV Community health app guide](https://dev.to/famitha_ma_b9c13ab1d324e/build-a-fitness-wearable-companion-app-with-react-native-healthkit-health-connect-57en)) |
| **Direct pedometer** | `ACTIVITY_RECOGNITION` permission (Android) | Bypasses Health Connect; lower integration, higher control |

**Domain best practice:** Single-writer rule to SQLite; idempotent inserts by time bucket; honest stale-data UI when background delivery fails.

### 4.2 Local Storage & Lifecycle

| Concern | Domain pattern | Astra approach |
|---------|---------------|----------------|
| **Unbounded growth** | Timeseries DBs saturate mobile storage | Tiered downsampling (5min → 1hour → 1day); VACUUM ([OW resolution model](https://openwearables.io/docs/architecture/unified-data-model)) |
| **Encryption at rest** | Expected for health data | SQLCipher in Phase 1; plaintext acceptable for Phase 0 sandbox with migration path |
| **Schema migration** | Client-side migrations are tricky in local-first apps ([DEV local-first manifesto](https://dev.to/beck_moulton/why-your-health-data-belongs-on-your-device-not-the-cloud-a-local-first-manifesto-3nj)) | Versioned migrations from day 1 |
| **Export/portability** | GDPR Art. 20; user expectation | CSV with OW-aligned columns |

### 4.3 Local-First Architecture Patterns (Domain Trend)

The digital health domain is moving toward **device-as-source-of-truth** architectures:

1. **Local-only** (Astra V1) — no sync server; maximum sovereignty
2. **Local-first + E2E encrypted sync** — CRDTs + encrypted blobs ([DEV E2E local-first](https://dev.to/doszhan/how-we-added-e2e-encryption-on-top-of-a-local-first-architecture-2jc2))
3. **Self-hosted backend** — Open Wearables, HealthLog model
4. **On-device AI** — HealthWallet.me, llama.cpp inference

Astra Phase 0 → V1 follows pattern **#1**. V2+ introduces pattern **#3** (self-hosted sync hub) and a managed variant of **#2** (encrypted multi-device via Astra cloud) — see §4.4.

### 4.4 V2+ Multi-Device Sync Strategy (Product Owner Clarification)

> **Scope:** V2 and beyond — **not V1**. V1 remains local-only, no account, no cloud.

When users need to access their health data from **multiple devices**, Astra will offer the **same sync capability** through two deployment models:

| Model | Target user | Deployment | Monetization |
|-------|-------------|------------|--------------|
| **Self-hosted sync hub** | Technical users (devs, self-hosters) | User deploys Astra sync app/server on own infrastructure (Docker, homelab, VPS) | Free/OSS stack; user owns infra |
| **Managed cloud service** | Non-technical users | Astra hosts the sync hub; user creates account, opts in explicitly | Paid subscription |

**Functional parity:** Both models provide the same outcome — centralized access to health data collected on phone/wearable from multiple devices. The difference is **who operates the server**, not the feature set.

**Domain implications when V2 activates:**

| Requirement | Self-hosted | Managed cloud |
|-------------|-------------|---------------|
| GDPR Art. 9 explicit consent | User is controller; Astra provides software | **Astra becomes processor/controller** — consent flows, DPA, registry |
| CNIL local-only exception | N/A (user chose remote sync) | **No longer applicable** |
| HDS (France) | User's responsibility if hosting health data | **Astra must obtain HDS certification** if hosting EU/French health data |
| CNIL formalités préalables | User's obligation if applicable | **Required** for Astra-operated health data processing |
| DPIA (Art. 35) | Recommended for user deployment docs | **Mandatory** before launch |
| Data portability (Art. 20) | Export from self-hosted instance | Export + account deletion in managed service |
| US state privacy laws (CCPA, NY HIPA, etc.) | Lower exposure (user-operated) | **Full compliance** required |
| EHDS (2027+) | Monitor; user-controlled | Opt-in only; granular consent if secondary use ever offered |

**Architecture principle (carry from V1):** Design the sync protocol and data schema in Phase 0–V1 so V2 is an **opt-in layer**, not a refactor. OW schema alignment supports this — the sync hub can speak the same `timeseries_samples` vocabulary whether self-hosted or managed.

**Positioning continuity:** V1 promise ("your data stays on your phone") remains true by default. V2 adds an **explicit, opt-in** path for multi-device convenience — never silent cloud upload.

---

## 5. Domain Competitive Landscape (Standards & Ecosystem Players)

### 5.1 Ecosystem Actors by Layer

| Layer | Key actors | Domain role |
|-------|-----------|-------------|
| **OS** | Apple, Google | Gatekeepers of health permissions and background execution |
| **Device OEM** | Garmin, Polar, WHOOP, Fitbit/Google, Samsung | Hardware + proprietary cloud |
| **Interoperability** | Open Wearables, FastenHealth (FHIR) | Normalization APIs |
| **Privacy-first OSS** | HealthWallet, HealthLog, XSpan | Alternative architectures; validate demand |
| **Regulators** | FDA, CNIL, EDPB, state AGs | Define wellness vs. medical boundaries |
| **Standards bodies** | Bluetooth SIG, HL7/FHIR, IEEE 11073 | Protocol and semantic definitions |

### 5.2 Astra's Domain Position

```
         Clinical ←────────────────────────────→ Consumer Wellness
              │                                        │
    FHIR/EHR  │                                        │  Step counters
    HIPAA     │                                        │  Goal rings
              │         ┌──────────────┐             │
              │         │    ASTRA     │             │
              │         │  local hub   │             │
              │         │  + wearable  │             │
              │         └──────────────┘             │
              │                                        │
         Cloud-required ←──────────────────→ Local-first
              │                                        │
    WHOOP/Garmin cloud                       Astra V1 (no cloud)
    Open Wearables server                    HealthWallet offline
```

---

## 6. Domain Risks & Compliance Matrix

| Risk domain | Phase 0 | Phase 1 | V1 (wearable) | V2+ (sync) | Mitigation |
|-------------|---------|---------|---------------|------------|------------|
| **GDPR Art. 9** | Low (local-only CNIL exception) | Low | Low if no cloud | **High** (managed cloud) | Maintain no-INTERNET manifest through V1; V2 = full consent stack |
| **HDS (France)** | N/A | N/A | N/A | **High** (managed cloud only) | HDS certification before managed service launch |
| **FDA medical device** | Very low | Low | Medium (sensors) | Low (sync layer) | Wellness-only claims; no clinical outputs |
| **CE marking (EU MDR)** | N/A (software only) | N/A | Medium (hardware) | N/A | Class I wellness device assessment before hardware sale |
| **Platform rejection** | Medium | Medium | Medium | Medium | Correct FGS types; PrivacyInfo.xcprivacy |
| **BLE interoperability** | N/A | Low (simulator) | High | N/A | Reference GHSP; document ADP spec |
| **EHDS secondary use** | N/A | N/A | Low (2027+) | Medium (managed) | Monitor; opt-in only; never default |

---

## 7. Domain Recommendations for Astra

### 7.1 Maintain Domain Boundaries

1. **Product category:** "Personal wellness instrument" — never "health monitor" with clinical connotation
2. **Feature guardrails:** No heart rate clinical alerts, no AFib, no "consult doctor" prompts in Phase 0
3. **Copy guardrails:** "Your data stays on your phone" — verifiable, not aspirational
4. **Architecture guardrails:** No silent cloud calls; dependency audit in README

### 7.2 Leverage Domain Advantages

1. **CNIL local-only exception** — document in privacy policy; unique vs. competitors
2. **OW schema alignment** — reduces domain integration cost for V2 sync hub and optional OW interoperability
3. **General wellness FDA path** — no premarket barrier for Phase 0 launch
4. **Screenless wearable domain trend** — V1 hardware aligns with WHOOP/Fitbit Air direction

### 7.3 Domain Documentation to Produce (Phase 0)

| Document | Domain purpose |
|----------|---------------|
| `docs/OPEN_WEARABLES_ALIGNMENT.md` | Interoperability domain mapping |
| `docs/SERIES_TYPES.md` | Domain vocabulary for timeseries types |
| `docs/DEPENDENCIES.md` | Network/privacy audit |
| `docs/REGULATORY_POSITION.md` | Wellness scope, CNIL/FDA boundary statement |
| `docs/ADP_OVERVIEW.md` (Phase 1) | BLE protocol domain spec |

---

## 8. Domain Outlook (2026–2028)

| Trend | Domain impact on Astra |
|-------|----------------------|
| **EHDS applicable (2027)** | May create opt-in secondary-use obligations for wellness apps; local-only likely exempt |
| **FDA wellness expansion (Jan 2026)** | Easier path for sensor-enabled Astra wearable without clinical clearance |
| **Open Wearables maturation** | OW schema/SDK informs V2 sync hub design; OW remains reference, not dependency |
| **Health Connect dominance on Android** | Phase 0 pedometer → Phase 1 Health Connect read path advisable |
| **On-device AI for health** | V2+ opportunity: local insights without cloud (HealthWallet precedent) |
| **Dual deployment (self-host + managed)** | V2 GTM mirrors Open Wearables model: OSS for technical users, paid managed for novices — with full regulatory compliance on managed tier |
| **Consent platforms (SHC)** | Mandatory for V2 managed cloud; adopt granular consent UX ([npj Digital Medicine](https://www.nature.com/articles/s41746-025-02147-3)) |

---

## Sources

### Regulatory
- [CNIL — Applications mobiles en santé (questions)](https://cnil.fr/fr/applications-mobiles-en-sante-et-protection-des-donnees-personnelles-les-questions-se-poser)
- [CNIL — Recommandation applications mobiles modifiée (avril 2025)](https://cnil.fr/sites/default/files/2025-04/recommandation-applications-mobiles-modifiee.pdf)
- [CNIL — Formalités données de santé](https://www.cnil.fr/fr/quelles-formalites-pour-les-traitements-de-donnees-de-sante)
- [Custodia — GDPR for Wearables](https://app.custodia-privacy.com/blog/gdpr-wearables-health-tech)
- [European Commission — EHDS Reuse of Health Data](https://health.ec.europa.eu/ehealth-digital-health-and-care/reuse-health-data_en)
- [FDA — General Wellness Step 3](https://www.fda.gov/medical-devices/digital-health-center-excellence/step-3-software-function-intended-maintaining-or-encouraging-healthy-lifestyle)
- [Covington — FDA Revised General Wellness Policy (Jan 2026)](https://www.cov.com/en/news-and-insights/insights/2026/01/fda-issues-revised-guidance-on-general-wellness-products)
- [npj Digital Medicine — Consent platform for health data sharing (2025)](https://www.nature.com/articles/s41746-025-02147-3)

### Standards & Interoperability
- [Open Wearables — Unified Data Model](https://openwearables.io/docs/architecture/unified-data-model)
- [Open Wearables — Health Connect Integration](https://openwearables.io/integrations/google-health-connect/)
- [Open Wearables — API Reference](https://openwearables.io/docs/api-reference/introduction)
- [Bluetooth SIG — Generic Health Sensor Profile v1.0](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/GHSP_v1.0/out/en/index-en.html)
- [Bluetooth SIG — Health Device Profile 1.1](https://www.bluetooth.com/specifications/specs/health-device-profile-1-1/)

### Technical Domain
- [Android Developers — Foreground Service Types (Android 14)](https://developer.android.com/about/versions/14/changes/fgs-types-required)
- [Android Developers — Health Connect Data Types](https://developer.android.com/health-and-fitness/health-connect/data-types)
- [pub.dev — open_wearables_health_sdk](https://pub.dev/packages/open_wearables_health_sdk)
- [pub.dev — health_connector](https://pub.dev/packages/health_connector)
- [DEV — Local-First Health Data Manifesto](https://dev.to/beck_moulton/why-your-health-data-belongs-on-your-device-not-the-cloud-a-local-first-manifesto-3nj)

### Internal Project Context
- `_bmad-output/planning-artifacts/research/market-astra-local-first-health-hub-research-2026-05-22.md`
- `_bmad-output/brainstorming/brainstorming-session-2026-05-22-1521.md`
- `README.md`

---

## Research Limitations (Express Mode)

- No legal review — regulatory positions are domain research summaries, not legal advice
- CE/MDR hardware classification not analyzed in depth (premature for Phase 0)
- French HDS and CNIL formalities assessed at principle level only
- BLE/ADP protocol design not validated against Bluetooth SIG qualification requirements
- EHDS impact on wellness-only apps remains uncertain pending 2027 implementation

**Confidence level:** High on standards and platform constraints; medium on regulatory local-only exemption (requires legal validation before commercial launch in EU).

---

**Research completed:** 2026-05-22  
**Mode:** Express (accelerated for documented brownfield project)
