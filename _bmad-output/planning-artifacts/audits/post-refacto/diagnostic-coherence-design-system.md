# **Diagnostic de cohérence — Design System**

**Périmètre analysé :** `lib/presentation/widgets/`, `lib/presentation/screens/`

**Source des tokens :** `lib/core/constants/` (pas de dossier `lib/core/theme/` — le thème est dans `astra_theme.dart`)

**Synthèse :** Le projet est globalement bien structuré. ~90 % des espacements passent par `AstraSpacing`, les couleurs sémantiques par `context.astraColors`, et les écrans (`screens/`) sont quasi exempts de valeurs brutes. Les écarts se concentrent sur des motifs répétés non factorisés (poignées de bottom sheet, typo nav/semaine, tooltips chart) et des `copyWith` qui surchargent la hiérarchie typographique.

---

## **1. Valeurs hardcodées (widgets + screens)**

> `*Colors.transparent` est listé car demandé, mais c’est un pattern Material courant (zones cliquables, overlays) — pas une violation de palette sémantique.*
> 

| **Fichier** | **Ligne** | **Valeur** | **Type de problème** |
| --- | --- | --- | --- |
| `widgets/background_status_card.dart` | 59 | `EdgeInsets.only(top: 4)` | Padding hardcodé (`kSpaceXs` existe) |
| `widgets/collection_health_indicator.dart` | 60 | `EdgeInsets.only(top: 4)` | Padding hardcodé |
| `widgets/confirm_dialog.dart` | 39, 108 | `fromLTRB(..., 0, ...)` | Padding `0` littéral (mineur) |
| `widgets/chart/astra_bar_chart_touch.dart` | 23–25 | `horizontal: 12, vertical: 8` | Padding hardcodé (hors `AstraSpacing`) |
| `widgets/display_name_editor_sheet.dart` | 87–88 | `width: 32, height: 4` | Dimensions poignée sheet (non tokenisées) |
| `widgets/goal_editor_sheet.dart` | 84–85 | `width: 32, height: 4` | Dimensions poignée sheet |
| `widgets/height_editor_sheet.dart` | 198–199 | `width: 32, height: 4` | Dimensions poignée sheet |
| `widgets/weight_editor_sheet.dart` | 186–187 | `width: 32, height: 4` | Dimensions poignée sheet |
| `widgets/display_name_editor_sheet.dart` | 91 | `BorderRadius.circular(2)` | BorderRadius hardcodé |
| `widgets/goal_editor_sheet.dart` | 88 | `BorderRadius.circular(2)` | BorderRadius hardcodé |
| `widgets/height_editor_sheet.dart` | 202 | `BorderRadius.circular(2)` | BorderRadius hardcodé |
| `widgets/weight_editor_sheet.dart` | 190 | `BorderRadius.circular(2)` | BorderRadius hardcodé |
| `widgets/chart/astra_bar_chart_touch.dart` | 18 | `BorderRadius.circular(8)` | BorderRadius hardcodé (= `kRadiusSm` non référencé) |
| `widgets/goal_ring.dart` | 855 | `BorderRadius.circular(6)` | BorderRadius hardcodé |
| `widgets/goal_ring.dart` | 864 | `BorderRadius.circular(4)` | BorderRadius hardcodé (= `kSpaceXs`) |
| `widgets/step_bar_chart.dart` | 115–116 | `Radius.circular(4)` | BorderRadius hardcodé |
| `widgets/trends_monthly_bar_chart.dart` | 119 | `Radius.circular(4)` | BorderRadius hardcodé |
| `widgets/app_bottom_nav.dart` | 119–125 | `TextStyle(fontSize: 10, fontWeight: w700, …)` | TextStyle inline complet |
| `widgets/week_progress_row.dart` | 117–121 | `copyWith(fontSize: 10, fontWeight: w600)` | TextStyle inline (surcharge typo) |
| `widgets/week_progress_row.dart` | 127–131 | `copyWith(fontSize: 16, fontWeight: w900)` | TextStyle inline |
| `widgets/trends_peak_day_card.dart` | 52–53, 59–60 | `copyWith(fontWeight: w700)` | TextStyle inline |
| `widgets/trends_peak_day_card.dart` | 66–67 | `copyWith(fontWeight: w400, color: …)` | TextStyle inline |
| `widgets/trends_average_stats_row.dart` | 86–87 | `copyWith(fontWeight: w700)` | TextStyle inline |
| `widgets/trends_average_stats_row.dart` | 93–94 | `copyWith(fontWeight: w400)` | TextStyle inline |
| `widgets/activity_stats_row.dart` | 152–153 | `copyWith(fontWeight: w500)` | TextStyle inline |
| `widgets/week_trophy_badge.dart` | 41–43 | `copyWith(fontWeight: w600)` | TextStyle inline |
| `widgets/astra_segmented_control.dart` | 191–192 | `copyWith(fontWeight: w500/w400)` | TextStyle inline |
| `widgets/chart/astra_bar_chart_touch.dart` | 8–10 | `copyWith(fontWeight: w600)` | TextStyle inline |
| `widgets/unit_option_picker_sheet.dart` | 87–89 | `copyWith(fontWeight: w600/normal)` | TextStyle inline |
| `widgets/astra_inset_shadow.dart` | 8 | `Color(0xFF323337)` | Couleur hors thème (≈ `textPrimary` light) |
| `widgets/status_banner.dart` | 112 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/astra_segmented_control.dart` | 209, 214–216 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/accent_preset_selector.dart` | 91 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/display_name_editor_row.dart` | 50 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/settings_preference_row.dart` | 31 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/menu_nav_row.dart` | 35 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/unit_option_picker_sheet.dart` | 71 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/astra_button.dart` | 85, 90, 92 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/week_progress_row.dart` | 86 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/profile_info_row.dart` | 43 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/data_export_button.dart` | 65, 70, 72 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/chart/astra_bar_chart_core.dart` | 314 | `Colors.transparent` | Couleur Material (acceptable) |
| `widgets/app_bottom_nav.dart` | 53 | `Colors.transparent` | Couleur Material (acceptable) |

**Écrans (`screens/`) :** aucune violation significative détectée — padding, typo et couleurs passent par les tokens.

---

## **2. Tokens existants**

> *Emplacement réel : `lib/core/constants/`, pas `lib/core/theme/`.*
> 

### **`AstraSpacing` (`astra_spacing.dart`)**

- **Grille :** `kSpaceXs` (4), `kSpaceSm` (8), `kSpaceMd` (16), `kSpaceLg` (24), `kSpaceXl` (32), `kSpace2xl` (48)
- **Layout :** `kCardPadding`, `kScreenHorizontalPadding`, `kMinTouchTarget`, `kIconButtonHorizontalInset` (12)
- **Rayons :** `kRadiusSm` (8), `kRadiusMd` (12), `kRadiusLg` (16), `kRadiusFull` (999)
- **Bottom nav :** `kBottomNavBarHeight`, `kBottomNavHorizontalPadding`, `kBottomNavItemGap`, `kBottomNavBottomOffset`, `kBottomNavItemSize`, `kBottomNavIconLabelGap`, `kBottomNavSquircleRadius`

### **`AstraTypography` (`astra_typography.dart`)**

- **Familles :** `figtree`, `darkerGrotesque`
- **Styles sémantiques :** `displayFor`, `rulerSelectedValueFor`, `goalRingStepCountFor`, `goalRingLabelFor`, `titleFor`, `onboardingIntroTitleFor`, `headlineFor`, `bodyFor`, `screenTitleFor`, `labelFor`, `captionFor`, `dataFor`
- **Accès contexte :** `AstraTypography.body(context)`, `.title()`, `.headline()`, etc.

### **`AstraColors` (`astra_colors.dart`)**

- **Extension ThemeData :** `ThemeExtension<AstraColors>`
- **Surfaces :** `bgBase`, `bgElevated`, `bgSubtle`, `borderDefault`, `borderPrimary`
- **Texte :** `textPrimary`, `textSecondary`, `textMuted`, `textInverse`, `neutralGray`
- **Accent / données :** `accentPrimary`, `accentPrimaryMuted`, `accentSecondary`, `dataPositive`, `dataNegative`, `dataGoalLine`
- **Statut :** `statusOk`, `statusStale`, `statusDanger`, `statusInfo`
- **Accès :** `context.astraColors` via `AstraThemeContext`

### **`astra_theme.dart`**

- `buildAstraLightTheme()` / `buildAstraDarkTheme()` — mappe `AstraTypography` → `TextTheme` Material (`displayLarge`, `headlineMedium`, `titleMedium`, `bodyLarge`, `labelLarge`, `bodySmall`, `titleSmall`)

### **`astra_accent_palette.dart` + `astra_accent_preset.dart`**

- Presets : orange, red, green, blue, magenta, pink
- `AccentPalette(primary, secondary)` avec hex verrouillés
- `kDefaultAccentPreset`, `parseAccentPreset()`

### **Constantes widget-level (hors core, mais nommées)**

| **Constante** | **Fichier** | **Valeur** |
| --- | --- | --- |
| `kAstraInsetShadowColor/Opacity/OffsetY/Blur` | `astra_inset_shadow.dart` | ombre inset |
| `kAstraBarChartLeftAxisReserved` (36) | `astra_bar_chart_core.dart` | chart |
| `kAstraBarChartBottomAxisReserved` (24) | idem | chart |
| `kAstraBarTooltipPadding/Margin` | `astra_bar_chart_touch.dart` | tooltip |
| `kGoalRingStrokeWidth/MinDiameter/MaxDiameter/WidthFactor` | `goal_ring.dart` | anneau |
| `_kLeftAxisReserved`, `_kBottomAxisReserved` | `step_bar_chart.dart`, `trends_monthly_bar_chart.dart` | doublons chart |
| `kDailyChartHeight` (320), `_kMonthlyChartHeight` (360) | charts / history | hauteurs |

---

## **3. Valeurs répétées 3+ fois sans constante nommée**

| **Valeur** | **Occurrences** | **Fichiers concernés** | **Suggestion de constante** |
| --- | --- | --- | --- |
| **2** | 8+ | 4 editor sheets (`BorderRadius`), `goal_ring` (`SizedBox`), `week_progress_row` | `kSheetHandleRadius` + `kSpaceMicro` (2px) dans `AstraSpacing` |
| **4** | 10+ | Poignées sheet (`height: 4`), bar charts (`Radius.circular(4)`), indicateurs (`padding top: 4`) | `kSheetHandleHeight`, `kBarChartTopRadius` (= `kSpaceXs`) |
| **6** | 5 | `week_progress_row` (dot 6×6), `goal_ring` (`BorderRadius.circular(6)`) | `kWeekDayDotSize`, `kRadiusXs` (6) |
| **8** | 9+ | Status dots 8×8, `goal_ring` `SizedBox`, tooltip `vertical: 8` | Référencer `kSpaceSm` partout |
| **10** | 4+ | `app_bottom_nav` + `week_progress_row` (`fontSize: 10`) | `kBottomNavLabelFontSize` ou `AstraTypography.navLabelFor()` |
| **12** | 4 | Tooltip padding horizontal, `kIconButtonHorizontalInset` (déjà token) | `kAstraBarTooltipPadding` → utiliser `kSpaceMd`/`kSpaceSm` |
| **16** | 5+ | `week_progress_row` (`fontSize: 16`), icônes 16px | Token typo `weekDayNumber` ou `kIconSizeSm` |
| **20** | 6+ | `app_bottom_nav`, `astra_button`, `data_export_button` (spinner 20×20) | `kIconSizeMd` dans `AstraSpacing` |
| **24** | 5 | Axis reserved chart (3 constantes distinctes pour la même valeur) | Unifier → `kAstraChartAxisReserved` |
| **32** | 5 | Poignées sheet (`width: 32`), ruler `centerIndicatorHeight` | `kSheetHandleWidth` |
| **48** | 4 | `minHeight: 48` (settings rows, unit picker), skeleton bars | `kListRowMinHeight` (= `kSpace2xl`) |
| **FontWeight.w700** sur `dataFor` | 4+ | `trends_peak_day_card`, `trends_average_stats_row` | `AstraTypography.dataBoldFor()` |
| **Motif poignée sheet** (32×4, radius 2) | 4 | Tous les `*_editor_sheet.dart` | Widget `SheetDragHandle` partagé |

---

## **4. `MediaQuery.of(context).size` pour le layout**

**Résultat : 0 occurrence** du anti-pattern demandé dans `widgets/` et `screens/`.

Usages `MediaQuery` trouvés — tous légitimes :

- `MediaQuery.viewInsetsOf(context).bottom` — clavier (editor sheets)
- `MediaQuery.disableAnimationsOf(context)` — accessibilité / reduce motion

**Layout responsive :** le projet utilise `LayoutBuilder` + `constraints.maxWidth/maxHeight` dans `goal_ring`, `goal_celebration`, `astra_segmented_control`, `footprint_kpi_row`, `astra_horizontal_ruler`, charts (`step_bar_chart`, `trends_monthly_bar_chart`, `astra_bar_chart_core`). Les `size.width/height` restants sont dans des `CustomPainter` (canvases), ce qui est correct.

---

## **Recommandations prioritaires**

1. **Extraire `SheetDragHandle`** — élimine 16 lignes dupliquées et 3 valeurs orphelines (32, 4, 2).
2. **Ajouter 2 styles typo** — `navLabel` (10/w700) et `weekDayNumber` (16/w900) dans `AstraTypography`.
3. **Unifier les constantes chart** — `_kLeftAxisReserved` / `kAstraBarChartLeftAxisReserved` en une seule source.
4. **Remplacer les `4` et `8` orphelins** par `AstraSpacing.kSpaceXs` / `kSpaceSm` là où c’est sémantiquement identique.
5. **Migrer `kAstraInsetShadowColor`** vers `colors.textPrimary` (ou token dédié `shadowColor`) pour le support dark mode.