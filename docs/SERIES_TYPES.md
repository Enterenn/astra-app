# ASTRA: Series Types (Phase 0)

Canonical definitions for rows stored in `timeseries_samples`. CSV export/import uses the same vocabulary via [Open Wearables alignment](./OPEN_WEARABLES_ALIGNMENT.md).

**Phase 0 scope:** one stored series type only: **`steps` / `count`**.

---

## Phase 0 canonical type

| Field | Value | Notes |
|-------|-------|-------|
| `type` | `steps` | Enforced by SQLite CHECK in schema v2 |
| `unit` | `count` | Integer step count per bucket |
| `value` | non-negative integer | Schema rejects negative values; step rows must be whole numbers |

Constants: `lib/data/models/normalized_step_bucket.dart` (`kStepSampleType`, `kStepSampleUnit`).

---

## Resolution values

Each bucket spans a fixed time window. Allowed `resolution` strings:

| Value | Meaning | Typical use |
|-------|---------|-------------|
| `5min` | 5-minute bucket | Ingestion default; primary write resolution |
| `1hour` | 1-hour bucket | Lifecycle downsampling |
| `1d` | 1-day bucket | Lifecycle downsampling |

Constants: `kFiveMinuteResolution`, `kHourlyResolution`, `kDailyResolution` in `normalized_step_bucket.dart`.

Import validation accepts only these three values (`TimeseriesCsvCodec`).

---

## Provider and device identifiers (phone ingestion)

Phase 0 phone sensor path:

| Field | Value | Source |
|-------|-------|--------|
| `provider` | `internal_phone` | `kInternalPhoneProvider` in `lib/data/datasources/data_ingestion_source.dart` |
| `device_id` | `smartphone` | `kSmartphoneDeviceId` in the same file |

Future wearable stub (not active in Phase 0): `astra_wearable_v1` / `astra_wearable_v1`.

---

## Timestamps and local day

| Field | Format |
|-------|--------|
| `start_time` / `end_time` | ISO 8601 UTC (`Z` suffix in CSV) |
| `zone_offset` | Immutable civil offset at ingestion, e.g. `+02:00` |

Local-day aggregation uses stored `zone_offset`, not the device timezone at query time.

---

## Phase 1+ planned types (not stored in Phase 0)

From the PRD addendum: **not written to SQLite in Phase 0**:

| `type` | `unit` | Notes |
|--------|--------|-------|
| `heart_rate` | bpm | Wearable PPG path |
| `hrv_rmssd` | ms | Derived from R-R intervals |
| `skin_temp` | °C | Wearable sensor |

Do not import or export these types until schema and ingestion support them.

---

## Derived Today metrics (UI-only, not series types)

The **Today** screen shows additional numbers computed in the presentation layer. They are **not** separate rows in `timeseries_samples`:

| Display | Computation | Implementation |
|---------|-------------|----------------|
| Distance (km) | From step count + stride estimate | `lib/core/metrics/derived_activity_metrics.dart` |
| Active time / walking duration | From active 5-minute buckets | Same module |
| Energy (kcal) | MET-based estimate from walking minutes | Same module |

These metrics support behavioral visibility only. They must not be exported as distinct OW series types in Phase 0.

---

## Related documentation

- [OPEN_WEARABLES_ALIGNMENT.md](./OPEN_WEARABLES_ALIGNMENT.md), CSV column mapping
- [DEPENDENCIES.md](./DEPENDENCIES.md), packages in the ingestion pipeline
- Schema DDL: `lib/core/database/migrations.dart` (`onCreateV2`)
