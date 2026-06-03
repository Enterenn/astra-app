# Open Wearables CSV alignment (Phase 0)

ASTRA exports `timeseries_samples` step rows using this column order:

`id,start_time,end_time,type,value,unit,resolution,provider,device_id,zone_offset`

- **id** — UUID TEXT from SQLite (preserved on export/import)
- **start_time / end_time** — ISO 8601 UTC with `Z` suffix
- **type** — Phase 0: `steps` only
- **value** — integer count for steps (no decimal)
- **unit** — `count`
- **resolution** — `5min`, `1hour`, or `1d`
- **provider / device_id** — ingestion source identifiers
- **zone_offset** — immutable civil offset string e.g. `+02:00`

Implementation: `lib/data/csv/timeseries_csv_codec.dart`
