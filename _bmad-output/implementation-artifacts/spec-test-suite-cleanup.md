---
title: 'Test suite cleanup — Phase A'
type: 'maintenance'
created: '2026-06-05'
status: 'done'
route: 'one-shot'
---

# Test suite cleanup — Phase A

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

## Follow-up (not in Phase A)

- **Phase B:** merge CSV tests, confirm_dialog smoke, screen smoke consolidation, trim design-constant assertions.
- **Phase C:** tag `test/dev/` with `@Tags(['dev'])` and exclude from CI.
