# Deferred Work

## Deferred from: code review of 1-1-flutter-project-initialization (2026-05-25)

- **Plugin manifest permissions not wired** — workmanager, pedometer, flutter_local_notifications require manifest/Gradle/iOS capability changes; intentionally out of scope for Story 1.1 (Epic 2).

- **Legacy Kotlin Gradle Plugin warnings** — `android.builtInKotlin=false` and `kotlin.incremental=false` are non-blocking workarounds for plugin compatibility; migration tracked for Epic 6 Story 6.2.

## Deferred from: code review of 1-2-design-tokens-and-theme-system (2026-05-28)

- **Unrelated `.gitignore` JetBrains entries** — `.idea/` and `*.iml` bundled with story 1-2; useful housekeeping but out of story scope.

- **Preview screen safe-area / text-scale / overflow edge cases** — temporary screen until Story 1.3; fixed 48dp button height may clip at high text scale; scroll body lacks bottom safe-area inset.

- **Partial Material 3 ColorScheme role mapping** — only primary/surface/error/outline set; secondary/tertiary/surfaceContainer roles use framework defaults until M3 stock widgets are used.

- **`copyWith` and mid-range `lerp` tests** — ThemeExtension boilerplate; t=0/t=1 lerp covered; mid-range and wrong-type paths deferred.

- **No widget tests asserting bundled font families** — fonts registered in pubspec but not verified in widget tests.

- **No dedicated unit tests for `astra_theme`, `astra_spacing`, `astra_typography`** — coverage via colors/cubit/widget smoke tests only.

- **AC #2 OS brightness toggle automated test** — spec explicitly requires manual verification; no widget test for platformBrightness changes.
