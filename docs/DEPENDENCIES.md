# ASTRA: Dependencies & bundled assets

Living inventory of third-party code and bundled assets. Started in Story 1.2 for offline fonts; full package audit (FR-27) completed in Story 7.1.

## Network policy (health pipeline)

Phase 0: **no runtime network fetch** for fonts or health data processing. Fonts are bundled under `assets/fonts/`.

**FR-27 package audit:** Complete as of Story 7.1. Every direct `pubspec.yaml` dependency is listed below with purpose and network posture.

### Debug vs release INTERNET permission

| Build | INTERNET | Notes |
|-------|----------|-------|
| **Release** | Must be absent | Privacy-by-architecture; verified by Story 7.2 `release_manifest_test.dart` |
| **Debug** | May be present | Flutter tooling / hot reload; not shipped to end users |

Health pipeline code paths do not perform HTTP requests in either build.

## Android manifest permissions (health pipeline)

Phase 0 step collection declares only local device-health/background permissions:

| Permission | Why it is present |
|------------|-------------------|
| `ACTIVITY_RECOGNITION` | Required by `pedometer` on Android 10+ to read step-count sensor data |
| `FOREGROUND_SERVICE` | Base permission for future Android foreground service health work |
| `FOREGROUND_SERVICE_HEALTH` | Android 14+ health-specific foreground service permission; avoids misusing `dataSync` for pedometer work |
| `POST_NOTIFICATIONS` | Already used by the app for later local notification UX; not a network permission |

- `INTERNET` is intentionally absent from the release manifest.

### Health foreground service (Story 2.8, notification tuning Story 9.1)

| Component | Role |
|-----------|------|
| `HealthStepForegroundService` (Kotlin) | Android `foregroundServiceType="health"` service; `ServiceCompat.startForeground` with `FOREGROUND_SERVICE_TYPE_HEALTH` on API 34+ |
| Notification channel `astra_health_tracking` (id `100`) | Honest ongoing copy: title **"Tracking steps"**, body **"Background step count on this device."**, channel description **"Background step tracking on this device."** — distinct from goal channel `astra_goal_reached` (id `1`) |
| `HealthForegroundServiceCoordinator` (Dart) | Method channel `com.astraapp.astra_app/health_foreground`; starts/stops FGS on app pause/resume |
| `runFgsStepCollectionCycle` | Periodic `BackgroundCollector.collectOnce` every 60s while FGS runs (same bootstrap as WorkManager) |

- **Visibility (Story 9.1):** Channel `IMPORTANCE_LOW` (FGS floor — not `IMPORTANCE_MIN`, which triggers an extra system battery warning). Quiet channel flags: no vibration, lights, or sound. Builder: `PRIORITY_LOW`, `setSilent(true)`, `VISIBILITY_SECRET`, `setOnlyAlertOnce(true)`, `setShowBadge(false)`.
- **Channel persistence:** Once `createNotificationChannel()` runs, Android stores user overrides in system settings. Re-running with the same channel id does **not** reset importance/sound on existing installs — QA on fresh install or cleared notification settings.
- WorkManager remains registered as fallback orchestrator (architecture D-04).
- No `dataSync` foreground service type.

### Background health capability evaluator (Story 2.10)

| Component | Role |
|-----------|------|
| `BackgroundHealthCapabilityEvaluator` (Dart) | Single D-23 entry point: activity, notification, battery exemption, FGS manifest flag, OEM deferral hint |
| `BackgroundHealthCapabilitySnapshot` | Immutable flags for Epic 4.2 `BackgroundStatusCard`, no user-facing copy in 2.10 |
| `BackgroundHealthCapabilityChannel` (Kotlin) | Method channel `com.astraapp.astra_app/background_health_capability`: `PowerManager.isIgnoringBatteryOptimizations`, `Build.MANUFACTURER` |
| `kAndroidFgsHealthManifestDeclared` | Static manifest truth (verified by `test/android/android_manifest_test.dart`), not runtime FGS running state |

- **Battery optimization:** Status read via native `PowerManager` only; `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is **not** added, no auto-request on launch (Epic 4.2 owns settings UX).
- **OEM deferral hint:** `likelyOemBatteryDeferral` is true for Samsung/Xiaomi/Huawei/Oppo/Vivo/OnePlus/Realme when not battery-exempt, a UX hint, not proof WM was deferred.
- **WorkManager fallback:** WM registers on Android regardless of FGS; periodic task passes `databasePath` in `inputData`. WM reconciles buckets (~15 min minimum), not realtime 5-min cadence; foreground backfill on open remains mandatory.

## WorkManager device verification (Story 2.4)

Automated tests (`test/core/services/workmanager_callback_test.dart`) prove the callback bootstrap writes a bucket through an isolate-local DB connection that a separate UI connection can read. End-to-end confirmation still requires a **physical Android device** with a step counter (emulators often report `StepCount not available`).

### Physical-device spike checklist (AC #1)

1. Install a debug build: `flutter build apk --debug` then `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.
2. Grant permissions: `adb shell pm grant com.astraapp android.permission.ACTIVITY_RECOGNITION` (and `POST_NOTIFICATIONS` on Android 13+).
3. Complete onboarding in the app; note baseline via `adb exec-out run-as com.astraapp cat databases/astra_app.db` (+ `-wal`/`-shm` if needed) or query on-device sqlite3.
4. Walk a few dozen steps (or move with the phone).
5. Send the app to background (`adb shell input keyevent KEYCODE_HOME`) or force-stop after first launch so WorkManager is registered.
6. Optional: force the periodic job before the 15-minute window (Android 14+ namespace required):

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
| Forced jobscheduler run | PARTIAL, WM accepted force but rescheduled (`executed before schedule`) |
| Step bucket written | FAIL, emulator pedometer: `StepCount not available` |
| Foreground backfill on launch | Ran; same pedometer error, 0 step rows in DB |

Physical-device confirmation remains the reference gate before beta.

## Bundled fonts (offline)

| Family | File | License | Weights (via variable font) | Used for |
|--------|------|---------|----------------------------|----------|
| Figtree | `assets/fonts/Figtree-VariableFont_wght.ttf` | [SIL Open Font License 1.1](https://scripts.sil.org/OFL) | 400, 500, 600 (`FontWeight`) | `type.body`, `type.caption`, `type.label`, `type.headline` |
| Darker Grotesque | `assets/fonts/DarkerGrotesque-VariableFont_wght.ttf` | SIL OFL 1.1 | 500, 600 (`FontWeight`) | `type.display`, `type.title`, `type.data` |

- **Source:** [Google Fonts](https://fonts.google.com/), downloaded into repo; not loaded at runtime.
- **Flutter registration:** `pubspec.yaml` → `flutter.fonts` (two families, one variable file each).
- **Excluded:** `google_fonts` package and any CDN font loading.

## Dart / Flutter packages

Direct dependencies from `pubspec.yaml` (locked versions from `pubspec.lock` as of Story 7.1):

| Package | Locked version | Purpose | Network in health pipeline |
|---------|----------------|---------|---------------------------|
| `flutter` | SDK | UI framework | No |
| `flutter_bloc` | 9.1.1 | Cubit state management (`TodayCubit`, `HistoryCubit`, etc.) | No |
| `sqflite` | 2.4.2+1 | On-device SQLite (`timeseries_samples`, WAL, migrations) | No |
| `path` | 1.9.1 | DB path joining, file path helpers | No |
| `uuid` | 4.5.3 | UUID v4 for sample `id` on insert | No |
| `workmanager` | 0.9.0+3 | Android background periodic collection (fallback orchestrator) | No |
| `pedometer` | 4.2.0 | OS step counter sensor stream | No |
| `permission_handler` | 12.0.1 | OS permission dialogs (`ACTIVITY_RECOGNITION`, notifications) | No (OS UI only) |
| `fl_chart` | 1.2.0 | Trends bar chart | No |
| `flutter_local_notifications` | 21.0.0 | Local goal-reached and FGS ongoing notifications, **no FCM/Firebase** | No (local channels only) |
| `path_provider` | 2.1.5 | App documents/temp paths for export | No |
| `file_picker` | 12.0.0-beta.5 | My Data CSV import/export via OS save/pick dialogs | No data upload; OS picker only |
| `phosphoricons_flutter` | 1.0.0 | Phosphor icon fonts (bundled in package) | No |
| `figma_squircle` | 0.6.3 | Figma corner smoothing on nav squircle | No |
| `package_info_plus` | 10.1.0 | Profile version footer from built manifest (Story 7.3); local platform channel only | No |

### `flutter_local_notifications` (local only)

Implementation: `lib/core/services/notification_service.dart`.

- Uses `FlutterLocalNotificationsPlugin` with Android notification channels only
- Goal reached: channel `astra_goal_reached`
- FGS ongoing copy: channel `astra_health_tracking` (Kotlin FGS coordination)
- **No** Firebase Cloud Messaging, **no** remote push, **no** analytics SDK

See KGP section below for Android build patches.

### Epic 5 UI packages (reference)

| Package | Notes |
|---------|-------|
| `phosphoricons_flutter` 1.0.0 | Figma-aligned Phosphor icons. **Not** `phosphor_flutter` 2.1.0 (incompatible with Dart 3.12). Tab icons: `sneakerMove`, `chartBar`, `database`, `user` |
| `figma_squircle` 0.6.3 | `SmoothRectangleBorder` on active nav squircle, `cornerRadius` 16, `cornerSmoothing` 1.0 |
| `file_picker` 12.0.0-beta.5 | Beta pin for CSV import/export via OS dialogs (Story 4.4 import, Story 17-1 export) |

### Android Built-in Kotlin / KGP (Story 5.5)

AGP 9.0.1 + Flutter 3.44.0 use **built-in Kotlin** (no `kotlin-android` on the app module). Two Phase 0 plugins still shipped KGP on pub.dev at audit time (2026-06-03); no newer pub release fixes them.

| Plugin | Locked version | Upstream | ASTRA workaround |
|--------|----------------|----------|------------------|
| `pedometer` | 4.2.0 | [carp-dk/flutter-plugins](https://github.com/carp-dk/flutter-plugins), no built-in Kotlin release; track [Flutter AGP 9 umbrella #181383](https://github.com/flutter/flutter/issues/181383) | `scripts/kgp-patches/pedometer-4.2.0-build.gradle` |
| `workmanager_android` | 0.9.0+2 (via `workmanager` 0.9.0+3) | [flutter_workmanager](https://github.com/fluttercommunity/flutter_workmanager), track AGP 9 / built-in Kotlin | `scripts/kgp-patches/workmanager_android-0.9.0+2-build.gradle` |

**Patch application (Story 5.5):**

- **Automatic:** `android/settings.gradle.kts` copies version-checked patches from `scripts/kgp-patches/` into pub-cache before Flutter loads plugin Gradle projects (every `flutter build` / `flutter run` on Android).
- **Manual fallback** (IDE-only Gradle sync, or after `flutter pub get` without a build):

```powershell
.\scripts\patch_kgp_plugins.ps1
```

```bash
./scripts/patch_kgp_plugins.sh
```

**Removal criteria:** delete patch files + script + `settings.gradle.kts` patch block when each plugin publishes a built-in-Kotlin release and `flutter build apk` emits no KGP warnings without patching.

**App-level migration (Story 5.5):** `org.jetbrains.kotlin.android` removed from `android/settings.gradle.kts`; `kotlin.incremental=false` removed from `android/gradle.properties`. **Flutter migrator re-adds** `android.builtInKotlin=false` and `android.newDsl=false` on upgrade — these flags remain in `gradle.properties` as of Story 7.2; Phase 0 plugin KGP patches in `settings.gradle.kts` handle legacy plugins until upstream migrates. Do not remove migrator flags without a dedicated follow-up. **Kotlin toolchain:** AGP 9 defaults to KGP 2.2.10; ASTRA pins `kotlin_version=2.3.20` in `gradle.properties` (Flutter minimum 2.2.20; KGP 2.3.10+ compatible with AGP 9.0.x per Kotlin docs).

**Pub upgrades skipped for KGP:** `pedometer`, `workmanager`, `file_picker` already at latest compatible versions; `permission_handler` / `sqflite` minor bumps are unrelated to KGP (deferred).

**`file_picker` 12.0.0-beta.5:** AGP9-aware, applies KGP only when `android.builtInKotlin=false`; no patch required once built-in Kotlin is enabled.

### Dev / test only (not shipped in release APK)

| Package | Locked version | Purpose |
|---------|----------------|---------|
| `flutter_test` | SDK | Widget and unit tests |
| `flutter_lints` | 6.0.0 | Static analysis rules |
| `sqflite_common_ffi` | 2.4.0+3 | Run sqflite-backed unit tests on VM/desktop without an emulator |
| `sqlite3` | 3.3.2 | Native SQLite bindings required by `sqflite_common_ffi` 2.4+ |

Windows tests use `hooks.user_defines.sqlite3` with `source: system` and `name_windows: winsqlite3` so Flutter does not copy `sqlite3.dll` into `build/native_assets/` (avoids file-lock errors). See `test/flutter_test_config.dart`.
