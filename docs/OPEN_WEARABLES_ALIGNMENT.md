# Open Wearables CSV alignment (Phase 0)

ASTRA aligns with [Open Wearables](https://github.com/theopenwearables/open-wearables) **CSV vocabulary only**, for user data portability. ASTRA does **not** bundle the Open Wearables server, SDK, or cloud sync.

---

## CSV header (exact order)

From `TimeseriesCsvCodec.headerRow` in `lib/data/csv/timeseries_csv_codec.dart`:

```
id,start_time,end_time,type,value,unit,resolution,provider,device_id,zone_offset
```

Import rejects any header that deviates from this column order or naming.

---

## Entity mapping: SQLite → CSV

| ASTRA `timeseries_samples` column | OW CSV column | Type / format |
|-----------------------------------|---------------|---------------|
| `id` | `id` | UUID TEXT (preserved on export/import) |
| `start_time` | `start_time` | ISO 8601 UTC with `Z` suffix |
| `end_time` | `end_time` | ISO 8601 UTC with `Z` suffix |
| `type` | `type` | Phase 0: `steps` only |
| `value` | `value` | Integer count (no decimal for steps) |
| `unit` | `unit` | `count` |
| `resolution` | `resolution` | `5min`, `1hour`, or `1d` |
| `provider` | `provider` | e.g. `internal_phone` |
| `device_id` | `device_id` | e.g. `smartphone` |
| `zone_offset` | `zone_offset` | Immutable civil offset, e.g. `+02:00` |

---

## Bucket identity (unique index)

Upserts deduplicate on the composite key defined in schema v2 (`idx_bucket_identity`):

```
provider, device_id, type, start_time, end_time, resolution
```

Source: `lib/core/database/migrations.dart` → `onCreateV2`.

---

## Phase 0 series vocabulary

See [SERIES_TYPES.md](./SERIES_TYPES.md) for canonical `steps` / `count` definitions and phone `provider` / `device_id` values.

---

## Canonical JSON example

Matches PRD addendum §2 (one 5-minute step bucket):

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

## Implementation references

| Concern | File |
|---------|------|
| CSV serialize / parse / validate | `lib/data/csv/timeseries_csv_codec.dart` |
| Schema + unique index | `lib/core/database/migrations.dart` |
| Bucket constants | `lib/data/models/normalized_step_bucket.dart` |
| Ingestion identifiers | `lib/data/datasources/data_ingestion_source.dart` |
| Export / import UX | My Data screen (Epic 4) |

---

## What this is not

- **Not** a dependency on Open Wearables infrastructure
- **Not** a guarantee of bidirectional sync with third-party OW deployments
- **Not** an extension for Phase 1+ vitals until schema and ingestion support them
