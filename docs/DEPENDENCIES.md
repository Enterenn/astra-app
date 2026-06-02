# ASTRA — Dependencies & bundled assets

Living inventory of third-party code and bundled assets. Full package audit (FR-27) is completed in Epic 5; this file is started in Story 1.2 for offline fonts.

## Network policy (health pipeline)

Phase 0: **no runtime network fetch** for fonts or health data processing. Fonts are bundled under `assets/fonts/`.

## Android manifest permissions (health pipeline)

Phase 0 step collection declares only local device-health/background permissions:

| Permission | Why it is present |
|------------|-------------------|
| `ACTIVITY_RECOGNITION` | Required by `pedometer` on Android 10+ to read step-count sensor data |
| `FOREGROUND_SERVICE` | Base permission for future Android foreground service health work |
| `FOREGROUND_SERVICE_HEALTH` | Android 14+ health-specific foreground service permission; avoids misusing `dataSync` for pedometer work |
| `POST_NOTIFICATIONS` | Already used by the app for later local notification UX; not a network permission |

- `INTERNET` is intentionally absent from the release manifest.

### Health foreground service (Story 2.8)

| Component | Role |
|-----------|------|
| `HealthStepForegroundService` (Kotlin) | Android `foregroundServiceType="health"` service; `ServiceCompat.startForeground` with `FOREGROUND_SERVICE_TYPE_HEALTH` on API 34+ |
| Notification channel `astra_health_tracking` (id `100`) | Honest ongoing copy: "Step tracking active" — distinct from goal channel `astra_goal_reached` (id `1`) |
| `HealthForegroundServiceCoordinator` (Dart) | Method channel `com.astraapp.astra_app/health_foreground`; starts/stops FGS on app pause/resume |
| `runFgsStepCollectionCycle` | Periodic `BackgroundCollector.collectOnce` every 5 minutes while FGS runs (same bootstrap as WorkManager) |

- WorkManager remains registered as fallback orchestrator (architecture D-04).
- No `dataSync` foreground service type.

### Background health capability evaluator (Story 2.10)

| Component | Role |
|-----------|------|
| `BackgroundHealthCapabilityEvaluator` (Dart) | Single D-23 entry point: activity, notification, battery exemption, FGS manifest flag, OEM deferral hint |
| `BackgroundHealthCapabilitySnapshot` | Immutable flags for Epic 4.2 `BackgroundStatusCard` — no user-facing copy in 2.10 |
| `BackgroundHealthCapabilityChannel` (Kotlin) | Method channel `com.astraapp.astra_app/background_health_capability`: `PowerManager.isIgnoringBatteryOptimizations`, `Build.MANUFACTURER` |
| `kAndroidFgsHealthManifestDeclared` | Static manifest truth (verified by `test/android/android_manifest_test.dart`) — not runtime FGS running state |

- **Battery optimization:** Status read via native `PowerManager` only; `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is **not** added — no auto-request on launch (Epic 4.2 owns settings UX).
- **OEM deferral hint:** `likelyOemBatteryDeferral` is true for Samsung/Xiaomi/Huawei/Oppo/Vivo/OnePlus/Realme when not battery-exempt — a UX hint, not proof WM was deferred.
- **WorkManager fallback:** WM registers on Android regardless of FGS; periodic task passes `databasePath` in `inputData`. WM reconciles buckets (~15 min minimum), not realtime 5-min cadence; foreground backfill on open remains mandatory.

## WorkManager device verification (Story 2.4)

Automated tests (`test/core/services/workmanager_callback_test.dart`) prove the callback bootstrap writes a bucket through an isolate-local DB connection that a separate UI connection can read. End-to-end confirmation still requires a **physical Android device** with a step counter (emulators often report `StepCount not available`).

### Physical-device spike checklist (AC #1)

1. Install a debug build: `flutter build apk --debug` then `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.
2. Grant permissions: `adb shell pm grant com.astraapp android.permission.ACTIVITY_RECOGNITION` (and `POST_NOTIFICATIONS` on Android 13+).
3. Complete onboarding in the app; note baseline via `adb exec-out run-as com.astraapp cat databases/astra_app.db` (+ `-wal`/`-shm` if needed) or query on-device sqlite3.
4. Walk a few dozen steps (or move with the phone).
5. Send the app to background (`adb shell input keyevent KEYCODE_HOME`) or force-stop after first launch so WorkManager is registered.
6. Optional — force the periodic job before the 15-minute window (Android 14+ namespace required):

   ```bash
   adb shell cmd jobscheduler run -f -u 0 -n androidx.work.systemjobscheduler com.astraapp 2
   ```

   WorkManager may still defer execution if the task is ahead of its minimum interval; waiting 15 minutes or reopening the app (foreground backfill) are valid fallbacks.

7. Reopen the app. Expect `getLastIngestionUtc()` / step rows to advance vs baseline.
8. Record device model, Android version, and pass/fail in the story Dev Agent Record.

**AC #2 (24 h without opening the app)** is a beta acceptance test (SM-2), not automatable in CI.

### Emulator attempt (2026-06-02)

| Item | Result |
|------|--------|
| Device | `sdk_gphone16k_x86_64`, Android 17 (API 37) |
| APK install | PASS |
| WorkManager job registered | PASS (`androidx.work.systemjobscheduler` job id `2`) |
| Forced jobscheduler run | PARTIAL — WM accepted force but rescheduled (`executed before schedule`) |
| Step bucket written | FAIL — emulator pedometer: `StepCount not available` |
| Foreground backfill on launch | Ran; same pedometer error, 0 step rows in DB |

Physical-device confirmation remains the reference gate before beta.

## Bundled fonts (offline)

| Family | File | License | Weights (via variable font) | Used for |
|--------|------|---------|----------------------------|----------|
| Figtree | `assets/fonts/Figtree-VariableFont_wght.ttf` | [SIL Open Font License 1.1](https://scripts.sil.org/OFL) | 400, 500, 600 (`FontWeight`) | `type.body`, `type.caption`, `type.label`, `type.headline` |
| Darker Grotesque | `assets/fonts/DarkerGrotesque-VariableFont_wght.ttf` | SIL OFL 1.1 | 500, 600 (`FontWeight`) | `type.display`, `type.title`, `type.data` |

- **Source:** [Google Fonts](https://fonts.google.com/) — downloaded into repo; not loaded at runtime.
- **Flutter registration:** `pubspec.yaml` → `flutter.fonts` (two families, one variable file each).
- **Excluded:** `google_fonts` package and any CDN font loading.

## Dart / Flutter packages

See `pubspec.yaml` and `pubspec.lock`. Package-level audit table → Epic 5 Story 5.1.

### Dev / test only

| Package | Purpose |
|---------|---------|
| `sqflite_common_ffi` | Run sqflite-backed unit tests on VM/desktop without an emulator |
| `sqlite3` | Native SQLite bindings required by `sqflite_common_ffi` 2.4+ |
