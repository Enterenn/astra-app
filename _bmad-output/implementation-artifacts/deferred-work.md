# Deferred Work

## Deferred from: code review of 1-1-flutter-project-initialization (2026-05-25)

- **Plugin manifest permissions not wired** — workmanager, pedometer, flutter_local_notifications require manifest/Gradle/iOS capability changes; intentionally out of scope for Story 1.1 (Epic 2).

- **Legacy Kotlin Gradle Plugin warnings** — `android.builtInKotlin=false` and `kotlin.incremental=false` are non-blocking workarounds for plugin compatibility; migration tracked for Epic 5 Story 5.2.
