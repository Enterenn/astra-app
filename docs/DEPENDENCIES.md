# ASTRA — Dependencies & bundled assets

Living inventory of third-party code and bundled assets. Full package audit (FR-27) is completed in Epic 5; this file is started in Story 1.2 for offline fonts.

## Network policy (health pipeline)

Phase 0: **no runtime network fetch** for fonts or health data processing. Fonts are bundled under `assets/fonts/`.

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
