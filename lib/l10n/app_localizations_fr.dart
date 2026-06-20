// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'ASTRA';

  @override
  String get menuPrivacyAndData => 'Confidentialité & Mes Données';

  @override
  String get menuTrackingStatus => 'État du suivi des pas';

  @override
  String get bannerStaleData => 'Données obsolètes. Toucher pour actualiser.';

  @override
  String get errorNoPermission => 'Accès aux pas refusé. Toucher pour régler.';

  @override
  String get onboardingStartBtn => 'Démarrer';

  @override
  String trendsWeeklyGrowth(int percentage) {
    return 'En hausse de $percentage% la semaine dernière';
  }

  @override
  String trendsWeeklyDecline(int percentage) {
    return 'En baisse de $percentage% la semaine dernière';
  }

  @override
  String get trendsWeeklyFlat => 'Identique à la semaine dernière';

  @override
  String get trendsNoPriorWeek => 'Pas de données la semaine précédente';

  @override
  String get menuTitle => 'Menu';

  @override
  String get menuSectionInformations => 'Informations';

  @override
  String get menuProfile => 'Profil';

  @override
  String get menuData => 'Données';

  @override
  String get menuOther => 'Autre';

  @override
  String get menuSettings => 'Paramètres';

  @override
  String get menuAbout => 'À propos';

  @override
  String get navSteps => 'PAS';

  @override
  String get navTrends => 'STATS';

  @override
  String get navMenu => 'MENU';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonNotSet => 'Non renseigné';

  @override
  String get commonDoubleTapToOpen => 'Toucher deux fois pour ouvrir.';

  @override
  String get commonDoubleTapToEdit => 'Toucher deux fois pour modifier.';

  @override
  String get commonDoubleTapToChange => 'Toucher deux fois pour changer.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageEnglish => 'Anglais';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsLanguageAutomatic => 'Langue de l\'appareil';

  @override
  String get settingsLanguageUpdateError =>
      'Impossible de mettre à jour la langue';

  @override
  String get settingsUnits => 'Unités';

  @override
  String get settingsDistance => 'Distance';

  @override
  String get settingsWeight => 'Poids';

  @override
  String get settingsHeight => 'Taille';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsGoalNotifications =>
      'Recevoir les notifications d\'objectif';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsUnitPreferenceUpdateError =>
      'Impossible de mettre à jour l\'unité';

  @override
  String get settingsNotificationUpdateError =>
      'Impossible de mettre à jour le paramètre de notification';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsThemeSystemSemantics => 'Apparence système';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeLightSemantics => 'Apparence claire';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsThemeDarkSemantics => 'Apparence sombre';

  @override
  String get settingsThemeSemanticsHint => 'Thème de l\'application';

  @override
  String get settingsAccentOrange => 'Couleur d\'accent, Orange';

  @override
  String get settingsAccentRed => 'Couleur d\'accent, Rouge';

  @override
  String get settingsAccentGreen => 'Couleur d\'accent, Vert';

  @override
  String get settingsAccentBlue => 'Couleur d\'accent, Bleu';

  @override
  String get settingsAccentMagenta => 'Couleur d\'accent, Magenta';

  @override
  String get settingsAccentPink => 'Couleur d\'accent, Rose';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileSectionInformations => 'Informations';

  @override
  String get profileCouldNotLoad => 'Impossible de charger le profil';

  @override
  String get profileCouldNotSaveDisplayName =>
      'Impossible d\'enregistrer le nom affiché';

  @override
  String get profileCouldNotSaveHeight => 'Impossible d\'enregistrer la taille';

  @override
  String get profileCouldNotSaveWeight => 'Impossible d\'enregistrer le poids';

  @override
  String get profileLoadErrorGeneric =>
      'Impossible de charger les paramètres du profil';

  @override
  String get profileDisplayName => 'Nom affiché';

  @override
  String get profileDisplayNameFirstName => 'Prénom';

  @override
  String get profileDisplayNameEditSemantics => 'Modifier le nom affiché';

  @override
  String profileDisplayNameSemantics(String value, String hint) {
    return 'Nom affiché, $value. $hint';
  }

  @override
  String profileDisplayNameReadOnlySemantics(String value) {
    return 'Nom affiché, $value.';
  }

  @override
  String get profileHeight => 'Taille';

  @override
  String get profileWeight => 'Poids';

  @override
  String get profileHeightFeet => 'Pieds';

  @override
  String get profileHeightInches => 'Pouces';

  @override
  String get profileHeightCentimeters => 'Centimètres';

  @override
  String get profileHeightEnterWholeNumberCm =>
      'Saisissez un nombre entier en centimètres';

  @override
  String profileHeightRangeCm(int min, int max) {
    return 'La taille doit être entre $min et $max cm';
  }

  @override
  String get profileHeightEnterBothFtIn => 'Saisissez les pieds et les pouces';

  @override
  String get profileHeightEnterWholeNumbersFtIn =>
      'Saisissez des nombres entiers pour les pieds et les pouces';

  @override
  String get profileHeightInchesRange =>
      'Les pouces doivent être entre 0 et 11';

  @override
  String profileHeightRangeFtIn(
    int minFeet,
    int minInches,
    int maxFeet,
    int maxInches,
  ) {
    return 'La taille doit être entre $minFeet pi $minInches po et $maxFeet pi $maxInches po';
  }

  @override
  String get profileWeightPounds => 'Livres';

  @override
  String get profileWeightKilograms => 'Kilogrammes';

  @override
  String get profileWeightEnterValid => 'Saisissez un poids valide';

  @override
  String get profileWeightOneDecimal => 'Utilisez au plus une décimale';

  @override
  String profileWeightRangeKg(int min, int max) {
    return 'Le poids doit être entre $min et $max kg';
  }

  @override
  String profileWeightRangeLb(String min, String max) {
    return 'Le poids doit être entre $min et $max lb';
  }

  @override
  String get myDataFootprint => 'Empreinte';

  @override
  String get myDataYourData => 'Vos données';

  @override
  String get myDataExportSaved => 'Export enregistré';

  @override
  String get myDataImportComplete => 'Importation terminée';

  @override
  String get myDataPurgeSuccess =>
      'Toutes les données locales ont été supprimées';

  @override
  String get myDataExportCsv => 'Exporter CSV';

  @override
  String get myDataExportCsvSemantics => 'Exporter les données en fichier CSV';

  @override
  String get myDataImportCsv => 'Importer CSV';

  @override
  String get myDataImportCsvSemantics => 'Importer un fichier CSV';

  @override
  String get myDataDeleteAllLocalData => 'Supprimer toutes les données locales';

  @override
  String get myDataExportErrorGeneric =>
      'L\'export n\'a pas pu être terminé. Réessayez.';

  @override
  String get myDataImportErrorGeneric =>
      'L\'import n\'a pas pu être terminé. Réessayez.';

  @override
  String get myDataPurgeErrorGeneric =>
      'La suppression n\'a pas pu être terminée. Réessayez.';

  @override
  String get myDataPurgeRefreshError =>
      'Toutes les données locales ont été supprimées, mais l\'application n\'a pas pu actualiser. Réessayez.';

  @override
  String myDataBackgroundHealthy(String relativeTime) {
    return 'Collecte en arrière-plan active · Dernière synchro $relativeTime';
  }

  @override
  String myDataBackgroundStale(String relativeTime) {
    return 'Collecte en arrière-plan retardée · Dernière synchro $relativeTime';
  }

  @override
  String myDataBackgroundIosBackfill(String relativeTime) {
    return 'Les pas se synchronisent à l\'ouverture de l\'app · Dernière synchro $relativeTime';
  }

  @override
  String get myDataBackgroundPermissionDenied =>
      'Autorisation d\'activité désactivée';

  @override
  String get myDataOpenSettings => 'Ouvrir les paramètres';

  @override
  String get myDataStatusIndicator => 'Indicateur d\'état';

  @override
  String get myDataFootprintSamplesStored => 'échantillons stockés';

  @override
  String myDataFootprintSamplesStoredSemantics(String count) {
    return '$count échantillons stockés';
  }

  @override
  String get myDataFootprintDatabaseSize => 'taille de la base';

  @override
  String myDataFootprintDatabaseSizeSemantics(String size) {
    return 'Taille de la base $size';
  }

  @override
  String get myDataFootprintNotOptimizedYet => 'pas encore optimisé';

  @override
  String myDataFootprintOptimized(String relativeTime) {
    return 'optimisé $relativeTime';
  }

  @override
  String get myDataPurgeConfirmTitle =>
      'Supprimer toutes les données locales ?';

  @override
  String get myDataPurgeConfirmBody =>
      'Cela supprime tout l\'historique des pas sur cet appareil. Exportez d\'abord si vous souhaitez conserver une copie.';

  @override
  String get myDataPurgeExportFirst => 'Exporter d\'abord';

  @override
  String get myDataPurgeDeleteAnyway => 'Supprimer quand même';

  @override
  String get myDataImportConfirmTitle => 'Importer des données ?';

  @override
  String myDataImportConfirmBody(int csvRowCount, int existingSampleCount) {
    return 'Ce fichier contient $csvRowCount échantillons. Votre base contient déjà $existingSampleCount échantillons. Les lignes avec des ID identiques ou le même créneau horaire seront ignorées — les données existantes ne sont pas écrasées.';
  }

  @override
  String get myDataImportConfirmImport => 'Importer';

  @override
  String get aboutTitle => 'À propos';

  @override
  String get aboutAppName => 'Astra Health';

  @override
  String aboutVersion(String version) {
    return 'Version : $version';
  }

  @override
  String get unitDistanceMetric => 'Métrique';

  @override
  String get unitDistanceImperial => 'Impérial';

  @override
  String get unitWeightKg => 'Kg';

  @override
  String get unitWeightLb => 'lb';

  @override
  String get unitHeightCm => 'cm';

  @override
  String get unitHeightFtIn => 'pi+po';

  @override
  String get unitDistanceKm => 'Km';

  @override
  String get unitDistanceMi => 'Mi';

  @override
  String unitHeightFtInDisplay(int feet, int inches) {
    return '$feet pi $inches po';
  }

  @override
  String unitHeightCmDisplay(int height) {
    return '$height cm';
  }

  @override
  String unitWeightLbDisplay(String weight) {
    return '$weight lb';
  }

  @override
  String unitWeightKgDisplay(String weight) {
    return '$weight kg';
  }

  @override
  String get relativeTimeNever => 'jamais';

  @override
  String get relativeTimeJustNow => 'à l\'instant';

  @override
  String relativeTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count minutes',
      one: 'il y a 1 minute',
    );
    return '$_temp0';
  }

  @override
  String relativeTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count heures',
      one: 'il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String relativeTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get relativeTimeMinute => 'minute';

  @override
  String get relativeTimeMinutes => 'minutes';

  @override
  String get relativeTimeHour => 'heure';

  @override
  String get relativeTimeHours => 'heures';

  @override
  String get relativeTimeDay => 'jour';

  @override
  String get relativeTimeDays => 'jours';

  @override
  String get todayScreenTitle => 'Pas';

  @override
  String get todayWeekSectionHeadline => 'Cette semaine';

  @override
  String get todaySetGoalLabel => 'Définir l\'objectif';

  @override
  String get todayGoalSaveError =>
      'L\'objectif quotidien n\'a pas pu être enregistré. Réessayez.';

  @override
  String get bannerStaleFullIos =>
      'Aucun nouveau pas depuis 4 h+. Les pas se mettent à jour à l\'ouverture de l\'app sur cet appareil.';

  @override
  String get bannerStaleFullAndroid =>
      'Aucun nouveau pas depuis 12 h+. La collecte en arrière-plan peut être retardée sur cet appareil.';

  @override
  String get bannerInfoStepsSync =>
      'Les pas se mettent à jour à l\'ouverture de l\'app sur cet appareil.';

  @override
  String get commonErrorGeneric => 'Une erreur s\'est produite. Réessayez.';

  @override
  String get todayCollectionHealthActive => 'Collecte active ●';

  @override
  String todayCollectionHealthStale(String relativeTime) {
    return 'Dernière sync $relativeTime ⚠';
  }

  @override
  String get todayCollectionHealthPermissionDenied => 'Accès capteur révoqué ✕';

  @override
  String get todayGoalRingStepsLabel => 'Pas';

  @override
  String get todayGoalRingSemanticsLoading => 'Pas du jour : chargement';

  @override
  String get todayGoalRingSemanticsNoPermission =>
      'Pas du jour : autorisation requise';

  @override
  String todayGoalRingSemanticsGoalReached(int steps, int goal) {
    return 'Pas du jour : $steps. Objectif quotidien de $goal atteint.';
  }

  @override
  String todayGoalRingSemanticsProgress(int steps, int goal) {
    return 'Pas du jour : $steps sur $goal';
  }

  @override
  String get todayGoalCelebrationLabel => 'Objectif quotidien atteint';

  @override
  String get todayGoalEditorTitle => 'Objectif de pas quotidien';

  @override
  String get todayGoalValidationError =>
      'Entrez une valeur entre 1 000 et 100 000.';

  @override
  String todayWeekGoalsMetSemantics(int count, int total) {
    return 'Objectifs atteints $count sur $total jours cette semaine';
  }

  @override
  String todayWeekDaySemantics(String weekdayLabel, int dayNumber) {
    return '$weekdayLabel $dayNumber';
  }

  @override
  String get todayStatsKcalLabel => 'Kcal';

  @override
  String get todayStatsKmLabel => 'Km';

  @override
  String get todayStatsMiLabel => 'Mi';

  @override
  String get onboardingContinueBtn => 'Continuer';

  @override
  String get onboardingSkipBtn => 'Passer';

  @override
  String get onboardingLetsGoBtn => 'C\'est parti';

  @override
  String get onboardingIntroHeadline =>
      'Votre santé. Votre téléphone. Point final.';

  @override
  String get onboardingIntroParagraphOne =>
      'Astra suit votre activité, vos habitudes et vos indicateurs de santé grâce uniquement aux capteurs intégrés de votre appareil. Pas de compte, pas de fuite cloud.';

  @override
  String get onboardingIntroParagraphTwo =>
      'Votre évolution personnelle vous appartient — et vous seul.';

  @override
  String get onboardingTrustOfflineBadge => '100 % hors ligne';

  @override
  String get onboardingTrustNoAccountBadge => 'Aucun compte requis';

  @override
  String get onboardingWeightTitle => 'Quel est votre poids ?';

  @override
  String get onboardingHeightTitle => 'Quelle est votre taille ?';

  @override
  String get onboardingOptionalMetricsHint =>
      'Le poids et la taille sont optionnels, mais améliorent la précision des mesures dans l\'application.';

  @override
  String get onboardingUnitKg => 'kg';

  @override
  String get onboardingUnitLb => 'lb';

  @override
  String get onboardingUnitCm => 'cm';

  @override
  String get onboardingUnitIn => 'in';

  @override
  String get onboardingWeightUnitSemantics => 'Choisir l\'unité de poids';

  @override
  String get onboardingHeightUnitSemantics => 'Choisir l\'unité de taille';

  @override
  String get trendsScreenTitle => 'Statistiques';

  @override
  String get trendsPeriod7Days => '7 jours';

  @override
  String get trendsPeriod30Days => '30 jours';

  @override
  String get trendsPeriod12Months => '12 mois';

  @override
  String get trendsChartRangeSemantics => 'Période du graphique';

  @override
  String get trendsEmptyHistory =>
      'Pas encore d\'historique. Marchez un peu — les données restent sur cet appareil.';

  @override
  String get trendsStepBarChartSemantics =>
      'Graphique en barres de l\'historique des pas';

  @override
  String get trendsMonthlyBarChartSemantics =>
      'Graphique en barres sur douze mois';

  @override
  String get trendsAverageKcalCaption => 'calories brûlées en moyenne par jour';

  @override
  String get trendsAverageStepsCaption => 'pas effectués en moyenne par jour';

  @override
  String trendsAverageKcalSemantics(int kcal) {
    return 'Moyenne de $kcal kilocalories brûlées par jour';
  }

  @override
  String trendsAverageStepsSemantics(int steps) {
    return 'Moyenne de $steps pas effectués par jour';
  }

  @override
  String get trendsPeakDayCaption => 'meilleur jour de la période';

  @override
  String trendsPeakDaySemantics(String dateLabel, int steps) {
    return 'Meilleur jour $dateLabel avec $steps pas sur cette période';
  }

  @override
  String chartTooltipStepsOfGoal(int steps, int goal) {
    return '$steps/$goal pas';
  }

  @override
  String get chartGoalStatusNoGoal => 'aucun objectif défini';

  @override
  String chartGoalStatusOverGoal(int count) {
    return '$count au-dessus de l\'objectif';
  }

  @override
  String chartGoalStatusBelowGoal(int count) {
    return '$count en dessous de l\'objectif';
  }

  @override
  String get chartGoalStatusMet => 'objectif atteint';

  @override
  String chartSelectionSemantics(
    String date,
    int steps,
    int goal,
    String status,
  ) {
    return '$date, $steps sur $goal pas, $status';
  }

  @override
  String trendsMonthlyTooltipStepsPerDay(int steps) {
    return '$steps pas/jour';
  }

  @override
  String trendsMonthlyTooltipTotal(int total, int days) {
    return '$total au total · $days jours';
  }

  @override
  String get commonWeekdayMon => 'lun.';

  @override
  String get commonWeekdayTue => 'mar.';

  @override
  String get commonWeekdayWed => 'mer.';

  @override
  String get commonWeekdayThu => 'jeu.';

  @override
  String get commonWeekdayFri => 'ven.';

  @override
  String get commonWeekdaySat => 'sam.';

  @override
  String get commonWeekdaySun => 'dim.';

  @override
  String get todayWeekPillMon => 'LUN';

  @override
  String get todayWeekPillTue => 'MAR';

  @override
  String get todayWeekPillWed => 'MER';

  @override
  String get todayWeekPillThu => 'JEU';

  @override
  String get todayWeekPillFri => 'VEN';

  @override
  String get todayWeekPillSat => 'SAM';

  @override
  String get todayWeekPillSun => 'DIM';

  @override
  String get commonMonthJan => 'janv.';

  @override
  String get commonMonthFeb => 'févr.';

  @override
  String get commonMonthMar => 'mars';

  @override
  String get commonMonthApr => 'avr.';

  @override
  String get commonMonthMay => 'mai';

  @override
  String get commonMonthJun => 'juin';

  @override
  String get commonMonthJul => 'juil.';

  @override
  String get commonMonthAug => 'août';

  @override
  String get commonMonthSep => 'sept.';

  @override
  String get commonMonthOct => 'oct.';

  @override
  String get commonMonthNov => 'nov.';

  @override
  String get commonMonthDec => 'déc.';

  @override
  String get commonMonthJanuary => 'janvier';

  @override
  String get commonMonthFebruary => 'février';

  @override
  String get commonMonthMarch => 'mars';

  @override
  String get commonMonthApril => 'avril';

  @override
  String get commonMonthMayFull => 'mai';

  @override
  String get commonMonthJune => 'juin';

  @override
  String get commonMonthJuly => 'juillet';

  @override
  String get commonMonthAugust => 'août';

  @override
  String get commonMonthSeptember => 'septembre';

  @override
  String get commonMonthOctober => 'octobre';

  @override
  String get commonMonthNovember => 'novembre';

  @override
  String get commonMonthDecember => 'décembre';
}
