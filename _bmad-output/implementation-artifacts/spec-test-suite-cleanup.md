---
title: 'Test suite cleanup'
type: 'maintenance'
created: '2026-06-05'
status: 'phase-b-done'
route: 'one-shot'
---

# Test suite cleanup

## Intent

Remove low-value tests that duplicate compile-time guarantees or are covered elsewhere, to shorten CI/local `flutter test` runtime without losing meaningful coverage.

## Removed files (2026-06-05)

| File | Rationale | Coverage retained |
|------|-----------|-------------------|
| `test/dependencies/phosphoricons_flutter_test.dart` | Runtime `codePoint > 0` smoke; icons compile when imported in `app_bottom_nav.dart` | `lib/presentation/widgets/app_bottom_nav.dart` + `widget_test.dart` / `app_scaffold_test.dart` |
| `test/data/datasources/adp_ble_source_test.dart` | Stub contract test; Phase 0 empty stream | `phone_pedometer_source_test.dart`, ingestion integration tests |
| `test/presentation/widgets/app_bottom_nav_test.dart` | Duplicated nav smoke; icon/label sizes live in widget source | `app_scaffold_test.dart` (pill tokens), `widget_test.dart` (four-tab switch) |
| `test/core/time/time_provider_test.dart` | Trivial `SystemTimeProvider` + `FakeTimeProvider` identity | `fake_time_provider.dart` used by normalizer/collector tests |

## Do not recreate

Future stories must **not** re-add these files unless behavior regresses. Prefer extending existing integration tests (`widget_test.dart`, `app_scaffold_test.dart`, datasource tests that exercise real paths).

## Phase B — Merges and trims (2026-06-05)

| Action | Result |
|--------|--------|
| `timeseries_csv_codec_test` + `parse_test` | Single `timeseries_csv_codec_test.dart` (serialize + parse groups) |
| `confirm_dialog_test` + `confirm_dialog_purge_test` | Single `confirm_dialog_test.dart` (import + purge groups) |
| `today_screen_test` + `history_screen_test` | `screen_smoke_test.dart` (Today + History smoke groups) |
| `astra_colors_test` + `astra_accent_presets_test` | Trimmed to parse aliases + lerp endpoints (~6 tests total) |

Do **not** split these back into separate files unless a group grows substantially (>15 cases).

## Follow-up (Phase C)

- Tag `test/dev/` with `@Tags(['dev'])` and exclude from CI.
