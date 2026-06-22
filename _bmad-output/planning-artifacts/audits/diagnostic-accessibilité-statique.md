Diagnostic d'accessibilité statique 
Analyse statique du code dans lib/presentation/widgets/ (54 fichiers) et lib/presentation/screens/ (8 fichiers). Méthode : lecture du code source, recherche de motifs (GestureDetector, Semantics, liveRegion, Color(0x, etc.). Aucun test runtime TalkBack/VoiceOver ni mesure de contraste effectuée.
Légende sévérité
Bloquant — action ou information inaccessible ou fortement dégradée pour les utilisateurs de technologies d'assistance
Majeur — non-conformité significative WCAG, contournable avec effort
Mineur — amélioration recommandée, impact limité
Écrans (lib/presentation/screens/)
today_screen.dart
Widget
Problème
Ligne
Sévérité
_GoalRingCard / InkWell « Définir l'objectif »
onTap sans Semantics parent ni semanticsLabel
521–527
Bloquant
_ActivityStatsSection → ActivityStatsRow
Compteurs dynamiques (kcal, distance, durée) sans liveRegion
438–441
Majeur
_GoalRingCard → GoalRing
Mises à jour de pas en temps réel sans liveRegion sur le conteneur sémantique
506–511
Majeur
_PermissionCta / TextButton
Pas de FocusNode explicite ; repose sur le focus Material par défaut
412–413
Mineur
_WeekSection → WeekProgressRow
Pastilles : statut objectif atteint (point coloré) absent du label sémantique
375–385
Majeur
history_screen.dart
Widget
Problème
Ligne
Sévérité
StepBarChart / TrendsMonthlyBarChart
Graphiques interactifs (GestureDetector) : pas de rôle bouton/slider, pas de navigation clavier
86–93, 76–82
Majeur
TrendsMonthlyBarChart
Label sémantique statique ; sélection de barre non annoncée (ExcludeSemantics sur le chart prêt)
— (widget enfant)
Majeur
PeriodToggle
Segments avec splashColor/highlightColor transparents → pas de retour visuel focus clavier
— (via AstraSegmentedControl)
Majeur
settings_screen.dart
Widget
Problème
Ligne
Sévérité
Switch notifications
Label texte et interrupteur non fusionnés (MergeSemantics / Semantics explicite)
279–305
Majeur
_pickLanguage / _pickDistanceUnit…
Délègue à showUnitOptionPickerSheet dont les tuiles n'ont pas de sémantique
84–92, etc.
Bloquant (indirect)
ThemeSelector / AccentPresetSelector
Focus visuel atténué sur segments et pastilles couleur
316–333
Mineur
my_data_screen.dart
Widget
Problème
Ligne
Sévérité
BackgroundStatusCard
Statut de collecte dynamique sans liveRegion
176–181
Majeur
FootprintKpiRow
KPI statiques au chargement ; pas de liveRegion si rafraîchissement silencieux
188–193
Mineur
_SectionLoadingIndicator
CircularProgressIndicator sans label de chargement
175, 187, 199
Mineur
about_screen.dart
Widget
Problème
Ligne
Sévérité
Icon (footprints)
Icône décorative sans ExcludeSemantics ni label
72–76
Mineur
FutureBuilder version
Texte version asynchrone sans Semantics / liveRegion
85–98
Mineur
profile_screen.dart
Widget
Problème
Ligne
Sévérité
—
Aucun problème direct ; délègue à des rows déjà sémantisées
—
—
menu_hub_screen.dart
Widget
Problème
Ligne
Sévérité
—
Structure correcte (Semantics écran + MenuNavRow sémantisées)
—
—
app_scaffold.dart
Widget
Problème
Ligne
Sévérité
—
Pas d'éléments interactifs propres ; navigation via AppBottomNav
—
—
Widgets (lib/presentation/widgets/)
Interactifs & sémantique
Fichier
Widget
Problème
Ligne
Sévérité
unit_option_picker_sheet.dart
_UnitOptionTile / InkWell
Pas de Semantics ni semanticsLabel sur tuile cliquable
70–73
Bloquant
chart/astra_bar_chart_core.dart
GestureDetector
Zone tactile sans Semantics(button:) ni label d'action
108–111
Majeur
astra_horizontal_ruler.dart
_RulerTick / GestureDetector
Tap sur label majeur sans sémantique propre (héritage slider partiel)
681–682
Mineur
today_screen.dart
InkWell objectif
(voir écrans)
526–527
Bloquant
Widgets interactifs correctement couverts : MenuNavRow, ProfileInfoRow, DisplayNameEditorRow, SettingsPreferenceRow, WeekProgressRow, AppBottomNav, AccentPresetSelector, AstraSegmentedControl, StatusBanner, SecondaryScreenHeader, DataExportButton, DataImportButton, DataPurgeButton, AstraButton, ConfirmDialog.
Images & icônes
Fichier
Widget
Problème
Ligne
Sévérité
activity_stats_row.dart
_StatColumn / Icon
Icônes décoratives non exclues
165
Mineur
profile_info_row.dart
Icon caretRight
Non exclue ; parent Semantics compense partiellement
66–69
Mineur
menu_nav_row.dart
Icon caretRight
Idem
49–52
Mineur
settings_preference_row.dart
Icon caretRight
Idem
53–56
Mineur
display_name_editor_row.dart
Icon caretRight
semanticLabel redondant avec le label parent → double annonce possible
76–80
Mineur
app_bottom_nav.dart
_NavItem / Icon
Icône + texte non exclus du nœud sémantique parent
131–135
Mineur
trends_insight_cards.dart
_TrendsInsightCard / Icon
Icône non exclue malgré Semantics.label
118–122
Mineur
trends_average_stats_row.dart
_TrendsStatCard / Icon
Idem
78
Mineur
trends_peak_day_card.dart
Icon trophy
Idem
40–44
Mineur
unit_option_picker_sheet.dart
Icon check
Non exclue quand sélectionné
95–98
Mineur
about_screen.dart
Icon footprints
Idem
72–76
Mineur
Bonnes pratiques observées : WeekTrophyBadge, TrendChip/CaptionPill, GoalRing ( ExcludeSemantics sur contenu visuel), GoalCelebration.
Texte dynamique & LiveRegion
Fichier
Widget
Problème
Ligne
Sévérité
animated_step_count.dart
AnimatedStepCount
Compteur animé sans liveRegion
35–51
Majeur
goal_ring.dart
Semantics anneau
value mis à jour sans liveRegion: true
626–631
Majeur
activity_stats_row.dart
_StatColumn / Text
Valeurs temps réel non annoncées
172–181
Majeur
collection_health_indicator.dart
Semantics
Statut santé collecte dynamique sans liveRegion
53–55
Majeur
background_status_card.dart
Text statut
Copie dynamique (sync, stale…) sans liveRegion
74–77
Majeur
step_bar_chart.dart
_ReadyChart
Sélection de barre : label sémantique mis à jour mais sans liveRegion
191–200
Majeur
trends_monthly_bar_chart.dart
Semantics parent
Label fixe ; interaction masquée par ExcludeSemantics
48–49, 167
Majeur
week_progress_row.dart
_DayPill
Indicateur objectif atteint (point) absent du label
102–111, 82
Majeur
goal_celebration.dart
Semantics
✅ liveRegion: true — référence positive
134–136
—
Focus visuel & retour tactile
Fichier
Widget
Problème
Ligne
Sévérité
astra_segmented_control.dart
_SegmentTarget / InkWell
splashColor, highlightColor, hoverColor tous Colors.transparent
214–216
Majeur
astra_button.dart
OutlinedButton secondary
overlayColor: Colors.transparent — focus Material atténué
92
Mineur
data_export_button.dart
OutlinedButton
Idem
72
Mineur
chart/astra_bar_chart_core.dart
GestureDetector
Pas de FocusNode, inaccessible au clavier
108
Majeur
accent_preset_selector.dart
_AccentChip / InkWell
customBorder sans indicateur focus clavier visible
92–94
Mineur
app_bottom_nav.dart
_NavItem / InkWell
borderRadius OK ; pas de ring focus clavier explicite
171–173
Mineur
Note globale : aucun FocusNode dans lib/presentation/. Le projet repose sur le focus Material implicite et AstraPressable (scale au toucher, pas au clavier).
Couleurs hardcodées
Fichier
Widget
Problème
Ligne
Sévérité
astra_inset_shadow.dart
kAstraInsetShadowColor
Color(0xFF323337) hors thème ; risque contraste non vérifié sur fonds clairs/sombres
8
Mineur
astra_segmented_control.dart
InkWell
Colors.transparent (intentionnel, pas un problème de contraste texte)
209, 214–216
—
astra_button.dart
ButtonStyle
Colors.transparent pour overlays
85, 90, 92
—
app_bottom_nav.dart
Material
Colors.transparent
53
—
Autres fichiers
Material(color: Colors.transparent)
Usage structurel, pas de texte dessus
divers
—
Constat : les couleurs de texte/fond passent quasi exclusivement par context.astraColors et AstraTypography.*For(colors) — bonne base thématique. Le seul Color(0xFF…) est une ombre portée.
Fichiers sans problème détecté
astra_pressable.dart, confirm_dialog.dart, data_import_button.dart, data_purge_button.dart, display_name_editor_sheet.dart, elevated_card.dart, footprint_kpi_row.dart, goal_celebration.dart, goal_celebration_particles.dart, goal_editor_sheet.dart, goal_ring_effects.dart, height_editor_sheet.dart, period_toggle.dart, profile_sheet_field_decoration.dart, ruler_tick_scroll_physics.dart, secondary_screen_shell.dart, section_card.dart, status_banner.dart, tab_placeholder_body.dart, theme_selector.dart, trend_chip.dart, week_trophy_badge.dart, weight_editor_sheet.dart, chart/astra_bar_chart_touch.dart, chart/astra_bar_chart_painter.dart, chart/astra_single_goal_line_painter.dart, chart/bar_chart_layout.dart, chart/chart_axis_ticks.dart, chart/goal_step_line_painter.dart.
Synthèse transversale
Critère
Constat
1. Interactifs sans sémantique
2 points bloquants : tuiles unit_option_picker_sheet, bouton « Définir l'objectif » sur Today
2. Icônes sans exclusion
~12 occurrences mineures ; pattern récurrent sur chevrons et icônes de cartes Trends
3. LiveRegion
1 seul usage (goal_celebration.dart) ; lacune majeure sur compteur de pas, stats activité, statuts collecte, graphiques
4. Focus visuel
Segmented control et graphiques sont les plus fragiles ; pas de stratégie clavier globale
5. Couleurs hardcodées
Très peu ; architecture AstraColors solide
Top 3 des écrans les plus problématiques
1. today_screen.dart — écran principal
Bouton critique « Définir l'objectif » sans label accessibilité (bloquant)
Cœur produit (anneau + stats) : données mises à jour en continu sans liveRegion
Semaine : indicateur visuel d'objectif atteint non reflété dans les annonces
2. history_screen.dart — Trends
Graphiques (StepBarChart, TrendsMonthlyBarChart) : interaction tactile uniquement, sans sémantique d'action ni clavier
Sélection de barres non annoncée (mensuel entièrement masqué)
PeriodToggle hérite du focus atténué du segmented control
3. settings_screen.dart — préférences
Feuilles d'unités/langue via unit_option_picker_sheet : tuiles inaccessibles aux lecteurs d'écran
Switch notifications : label et contrôle non associés explicitement
Contrôles segmentés (thème) + pastilles couleur : focus clavier peu visible
Recommandations prioritaires
Bloquant — Envelopper _UnitOptionTile et le bouton objectif Today dans Semantics(button: true, label: …).
Majeur — Ajouter liveRegion: true sur GoalRing, ActivityStatsRow, CollectionHealthIndicator, BackgroundStatusCard et les charts lors d'un changement de sélection/valeur.
Majeur — Remplacer GestureDetector des charts par un widget focusable (FocusableActionDetector ou Semantics + raccourcis clavier) avec annonce de la barre sélectionnée.
Majeur — Restaurer un retour focus visible sur AstraSegmentedControl (ne pas neutraliser highlightColor/focusColor).
Mineur — Systématiser ExcludeSemantics sur les icônes décoratives à l'intérieur de nœuds Semantics déjà labellisés.
Ce diagnostic reste statique : une validation runtime (TalkBack, VoiceOver, contraste mesuré sur chaque thème/accent) compléterait l'audit avant release.