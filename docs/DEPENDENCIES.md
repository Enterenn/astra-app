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
- No foreground service is started in Story 2.4, so no `foregroundServiceType` service declaration is added yet. When a health foreground service is introduced, it must use `foregroundServiceType="health"`, not `dataSync`.

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
