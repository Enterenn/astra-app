# ASTRA PRD — Technical Addendum

*Companion to `prd.md`. Contains implementation-oriented detail that does not belong in the capability-focused PRD. Downstream architecture and firmware specs should extend this document.*

**Last updated:** 2026-05-22

---

## 1. Open Source & Licensing

| Component | License | Notes |
|-----------|---------|-------|
| Flutter Hub App source | **Apache 2.0** | User decision 2026-05-22; supersedes MIT references in brainstorming |
| Firmware (Zephyr) | Apache 2.0 (planned) | Same OSS policy as Hub |
| PPG filtering algorithms | Apache 2.0 (planned) | Publishable signal-processing code |
| ADP protocol specification | Apache 2.0 (planned) | Wire format + reconciliation semantics |
| ASTRA trademark, logos, iconography | Proprietary | Not in OSS repo |
| Industrial design (enclosure CAD) | Proprietary | Not in OSS repo |
| App Store / Play signing keys | Proprietary | Not in OSS repo |

---

## 2. SQLite Schema (Phase 0 Reference)

Semantic alignment: Open Wearables unified data model. PRD uses **`timeseries_samples`** (not `health_events` from external PRD v3.0).

```sql
-- Primary timeseries table (Phase 0)
CREATE TABLE IF NOT EXISTS timeseries_samples (
    id TEXT PRIMARY KEY,              -- UUID v4
    start_time TEXT NOT NULL,         -- ISO 8601 UTC
    end_time TEXT NOT NULL,           -- ISO 8601 UTC
    type TEXT NOT NULL,               -- e.g. 'steps'
    value REAL NOT NULL,
    unit TEXT NOT NULL,               -- e.g. 'count'
    resolution TEXT NOT NULL,         -- '5min' | '1hour' | '1d'
    provider TEXT NOT NULL,           -- e.g. 'internal_phone'
    device_id TEXT NOT NULL,          -- e.g. 'smartphone' | 'astra_wearable_v1'
    zone_offset TEXT NOT NULL         -- OW-required offset (e.g. '+02:00')
);

CREATE INDEX IF NOT EXISTS idx_timeseries_query
    ON timeseries_samples (type, start_time DESC);

CREATE TABLE IF NOT EXISTS user_preferences (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
-- seed: daily_step_goal
```

**Phase 0 series types:** `steps` / `count` only.  
**Phase 1+ types (planned):** `heart_rate` (bpm), `hrv_rmssd` (ms), `skin_temp` (°C).

**Canonical JSON example** (matches prd.md §4.3.1):

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "start_time": "2026-05-22T14:30:00Z",
  "end_time": "2026-05-22T14:35:00Z",
  "type": "steps",
  "value": 132,
  "unit": "count",
  "resolution": "5min",
  "provider": "internal_phone",
  "device_id": "smartphone",
  "zone_offset": "+02:00"
}
```

---

## 2.1 Time Semantics (Summary)

Full doctrine: prd.md §1.3.

- `start_time` / `end_time`: ISO 8601 **UTC**
- `zone_offset`: captured at ingestion, immutable per row
- Daily goals: aggregate by local calendar day using stored `zone_offset`

---

## 2.2 Data Ownership (Summary)

Full doctrine: prd.md §1.4. User owns all **Timeseries Samples** regardless of `provider` / `device_id`.

---

## 3. Data Lifecycle (Downsampling Detail)

| Age | Resolution | Ratio |
|-----|------------|-------|
| 0–30 days | 5 min | 1:1 |
| 31–365 days | 1 hour | 12:1 (five-minute buckets) |
| > 365 days | 1 day | 24:1 (hourly buckets) |

**Maintenance schedule:** weekly `PRAGMA optimize; VACUUM;`

**Compaction:** Destructive and irreversible — finer buckets deleted after coarser aggregate written (prd.md FR-11). No archive tier.

External PRD v3.0 specified 1-minute active buckets; brainstorming + domain research selected **5-minute default** for OW alignment and mobile storage efficiency.

**Storage volume targets** (prd.md §1.2, NFR-7/8): 1 year < 50 MB, 5 years < 200 MB (steps-only, lifecycle active).

---

## 4. Phase 1 Hub Enhancements (Preview)

Not Phase 0 scope; captured for architectural continuity.

### 4.1 SQLCipher

- AES-256 encryption at rest via SQLCipher extension.
- Key generated on first launch; sequestered in Android Keystore / iOS Keychain.
- **Recovery phrase:** BIP39-style word sequence shown once at init; user must save offline.
- Migration from plaintext Phase 0 DB via export/re-import or in-place migration tool.

### 4.2 BLE Simulator

- Module simulating ADP disconnect/reconnect and burst reconciliation.
- Tests ACK-based flash release without physical Wearable.

---

## 5. Wearable Hardware (External PRD v3.0 Extract)

### 5.1 MCU

| Stage | Target |
|-------|--------|
| Prototyping | Nordic nRF52840 DK or nRF5340 DK |
| Industrialization (2026/2027) | Nordic nRF54 series (nRF54L15 or nRF54H20) |

Rationale: ~50% energy reduction vs prior gen; hardware crypto (Secure Enclave).

### 5.2 Sensors

| Sensor | Part (reference) | Purpose |
|--------|------------------|---------|
| PPG | MAX86140 / MAX86141 | HR, R-R intervals → HRV |
| IMU | Bosch BMI270 or ST LSM6DSOX | Steps, activity/sleep qualification |
| Skin temp | MAX30205 (optional) | Skin temperature |

### 5.3 Power

- Li-Po 80–120 mAh
- Magnetic pogo-pin charging
- PMIC ultra-low-power (e.g., nRF7002 class)
- **KPI-02 target:** 5–7 days continuous HR windowed acquisition

---

## 6. Firmware Architecture (Zephyr)

```
┌─────────────────────────────────────────┐
│ APPLICATION LOGIC                        │
│ (state machine, ring buffer, ADP encode) │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│ HAL API (read_steps(), get_hr(), etc.)  │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│ DRIVERS (DeviceTree: MAX86141, BMI270)  │
└─────────────────────────────────────────┘
```

**Rule:** Application logic never calls sensor registers directly.

- **OS:** Zephyr RTOS
- **Language:** C (V1); Rust migration prepared long-term

### PPG noise mitigation (Risk 10.2)

When IMU acceleration exceeds threshold (running, sharp motion), firmware marks period as **noisy** and suspends HRV calculation to avoid polluting Hub database.

---

## 7. Astra Device Protocol (ADP) — Overview

- **Transport:** BLE 5.3, custom GATT characteristics
- **Mode:** Batch / offline-first — Wearable does not maintain continuous connection
- **Wearable storage:** Circular flash buffer for offline periods
- **Payload:** Compact binary (Protocol Buffers lite or bit-mask encoding)
- **Reconciliation:**
  1. On reconnect, Hub sends timestamp of last valid local event
  2. Wearable transmits missing data in bursts
  3. Hub ACKs each packet → Wearable releases flash space

**Industry reference:** Consider GHSP/IEEE 11073 observation types for semantic compatibility even if wire format is proprietary.

Full ADP spec: `docs/ADP_OVERVIEW.md` (Phase 1 deliverable).

---

## 8. Interoperability Strategy

### Phase 0–V1

- OW schema/vocabulary alignment (`timeseries_samples`, CSV export)
- No OW server dependency
- Optional future: HealthKit / Health Connect export (V2 bridge)

### V2+ (Product owner clarification)

| Model | User | Compliance burden |
|-------|------|-------------------|
| Self-hosted ASTRA sync hub | Technical users | User is controller |
| Managed ASTRA cloud (paid) | Non-technical users | GDPR Art. 9, HDS (France), DPIA, consent flows |

Open Wearables remains **schema reference**; V2 sync is native ASTRA hub, not OW export-as-strategy.

---

## 9. Code Injector Guardrails (Cursor / LLM)

From external PRD §11 — enforce at review time:

1. No database package other than SQLite / official SQLCipher Flutter bindings
2. No HTTP/WebSocket/analytics in health data pipeline
3. Database config must implement downsampling routines (DataLifecycleService)
4. Schema must conform to §2 above

---

## 10. Regulatory Reference Documents (Phase 0)

Recommended repo docs (from domain research):

| Document | Purpose |
|----------|---------|
| `docs/REGULATORY_POSITION.md` | General wellness scope; CNIL/FDA boundaries |
| `docs/OPEN_WEARABLES_ALIGNMENT.md` | OW entity mapping |
| `docs/SERIES_TYPES.md` | Supported measurement types |
| `docs/DEPENDENCIES.md` | Network/privacy audit |

**Disclaimer:** Domain research summaries are not legal advice. EU commercial launch requires counsel on CNIL local-only exemption.

---

## 11. Execution Matrix (Full — from External PRD)

| Phase | Scope | Key actions |
|-------|-------|-------------|
| **0** | Flutter sandbox | Pedometer, fake data inject, KPI-01, 3 screens, OSS |
| **1** | Hub V1 | SQLCipher, key backup, BLE sim, UI freeze |
| **2** | DevKit firmware | Nordic DK, Zephyr drivers, HAL, PPG validation |
| **3** | Integrated prototype | Final PCB, battery, SLA enclosure, power opt |
| **4** | Industrialization | Crowdfunding, CE/FCC labs, tooling |

**Phase 0 exit (external PRD):** Basic UI functional; KPI-01 validated on simulator/inject.  
**Phase 0 exit (BMAD PRD):** Beta checklist + learning outcome + OSS repo (see prd.md §7).

---

## 12. Flutter Package Reference (Phase 0)

| Package | Role |
|---------|------|
| `pedometer` | Direct step sensor |
| `sqflite` | SQLite persistence |
| `workmanager` | Android background |
| `flutter_local_notifications` | Goal notification |
| `fl_chart` | History charts |
| `share_plus` | CSV export share sheet |
| `permission_handler` | Runtime permissions |

**Phase 1 candidates:** SQLCipher bindings, `health` / `health_connector` for Health Connect/HealthKit.

**Explicitly excluded Phase 0:** `open_wearables_health_sdk` (requires cloud backend).
