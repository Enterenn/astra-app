// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ASTRA';

  @override
  String get menuPrivacyAndData => 'Privacy & My Data';

  @override
  String get menuTrackingStatus => 'Step Tracking Status';

  @override
  String get bannerStaleData => 'Data outdated. Tap to refresh.';

  @override
  String get errorNoPermission => 'Step access denied. Tap to fix.';

  @override
  String get onboardingStartBtn => 'Start';

  @override
  String trendsWeeklyGrowth(int percentage) {
    return 'Up $percentage% from last week';
  }

  @override
  String trendsWeeklyDecline(int percentage) {
    return 'Down $percentage% from last week';
  }

  @override
  String get trendsWeeklyFlat => 'Same as last week';

  @override
  String get trendsNoPriorWeek => 'No prior week data';

  @override
  String get menuTitle => 'Menu';

  @override
  String get menuSectionInformations => 'Informations';

  @override
  String get menuProfile => 'Profile';

  @override
  String get menuData => 'Data';

  @override
  String get menuOther => 'Other';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuAbout => 'About';

  @override
  String get navSteps => 'STEPS';

  @override
  String get navTrends => 'TRENDS';

  @override
  String get navMenu => 'MENU';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNotSet => 'Not set';

  @override
  String get commonDoubleTapToOpen => 'Double tap to open.';

  @override
  String get commonDoubleTapToEdit => 'Double tap to edit.';

  @override
  String get commonDoubleTapToChange => 'Double tap to change.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'French';

  @override
  String get settingsLanguageAutomatic => 'Using device language';

  @override
  String get settingsLanguageUpdateError => 'Could not update language';

  @override
  String get settingsUnits => 'Units';

  @override
  String get settingsDistance => 'Distance';

  @override
  String get settingsWeight => 'Weight';

  @override
  String get settingsHeight => 'Height';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsGoalNotifications => 'Receive Goal notifications';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsUnitPreferenceUpdateError =>
      'Could not update unit preference';

  @override
  String get settingsNotificationUpdateError =>
      'Could not update notification setting';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeSystemSemantics => 'System appearance';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeLightSemantics => 'Light appearance';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeDarkSemantics => 'Dark appearance';

  @override
  String get settingsThemeSemanticsHint => 'App theme';

  @override
  String get settingsAccentOrange => 'Accent color, Orange';

  @override
  String get settingsAccentRed => 'Accent color, Red';

  @override
  String get settingsAccentGreen => 'Accent color, Green';

  @override
  String get settingsAccentBlue => 'Accent color, Blue';

  @override
  String get settingsAccentMagenta => 'Accent color, Magenta';

  @override
  String get settingsAccentPink => 'Accent color, Pink';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileSectionInformations => 'Informations';

  @override
  String get profileCouldNotLoad => 'Could not load profile';

  @override
  String get profileCouldNotSaveDisplayName => 'Could not save display name';

  @override
  String get profileCouldNotSaveHeight => 'Could not save height';

  @override
  String get profileCouldNotSaveWeight => 'Could not save weight';

  @override
  String get profileLoadErrorGeneric => 'Could not load profile settings';

  @override
  String get profileDisplayName => 'Display name';

  @override
  String get profileDisplayNameFirstName => 'First name';

  @override
  String get profileDisplayNameEditSemantics => 'Edit display name';

  @override
  String profileDisplayNameSemantics(String value, String hint) {
    return 'Display name, $value. $hint';
  }

  @override
  String profileDisplayNameReadOnlySemantics(String value) {
    return 'Display name, $value.';
  }

  @override
  String get profileHeight => 'Height';

  @override
  String get profileWeight => 'Weight';

  @override
  String get profileHeightFeet => 'Feet';

  @override
  String get profileHeightInches => 'Inches';

  @override
  String get profileHeightCentimeters => 'Centimeters';

  @override
  String get profileHeightEnterWholeNumberCm =>
      'Enter a whole number in centimeters';

  @override
  String profileHeightRangeCm(int min, int max) {
    return 'Height must be between $min and $max cm';
  }

  @override
  String get profileHeightEnterBothFtIn => 'Enter both feet and inches';

  @override
  String get profileHeightEnterWholeNumbersFtIn =>
      'Enter whole numbers for feet and inches';

  @override
  String get profileHeightInchesRange => 'Inches must be between 0 and 11';

  @override
  String profileHeightRangeFtIn(
    int minFeet,
    int minInches,
    int maxFeet,
    int maxInches,
  ) {
    return 'Height must be between $minFeet ft $minInches in and $maxFeet ft $maxInches in';
  }

  @override
  String get profileWeightPounds => 'Pounds';

  @override
  String get profileWeightKilograms => 'Kilograms';

  @override
  String get profileWeightEnterValid => 'Enter a valid weight';

  @override
  String get profileWeightOneDecimal => 'Use at most one decimal place';

  @override
  String profileWeightRangeKg(int min, int max) {
    return 'Weight must be between $min and $max kg';
  }

  @override
  String profileWeightRangeLb(String min, String max) {
    return 'Weight must be between $min and $max lb';
  }

  @override
  String get myDataFootprint => 'Footprint';

  @override
  String get myDataYourData => 'Your data';

  @override
  String get myDataExportSaved => 'Export saved';

  @override
  String get myDataImportComplete => 'Import complete';

  @override
  String get myDataPurgeSuccess => 'All local data removed';

  @override
  String get myDataExportCsv => 'Export CSV';

  @override
  String get myDataExportCsvSemantics => 'Export data as CSV file';

  @override
  String get myDataImportCsv => 'Import CSV';

  @override
  String get myDataImportCsvSemantics => 'Import CSV file';

  @override
  String get myDataDeleteAllLocalData => 'Delete all local data';

  @override
  String get myDataExportErrorGeneric =>
      'Export could not be completed. Try again.';

  @override
  String get myDataImportErrorGeneric =>
      'Import could not be completed. Try again.';

  @override
  String get myDataPurgeErrorGeneric =>
      'Purge could not be completed. Try again.';

  @override
  String get myDataPurgeRefreshError =>
      'All local data was removed, but the app could not refresh. Try again.';

  @override
  String myDataBackgroundHealthy(String relativeTime) {
    return 'Background collection active · Last sync $relativeTime';
  }

  @override
  String myDataBackgroundStale(String relativeTime) {
    return 'Background collection delayed · Last sync $relativeTime';
  }

  @override
  String myDataBackgroundIosBackfill(String relativeTime) {
    return 'Steps sync when you open the app · Last sync $relativeTime';
  }

  @override
  String get myDataBackgroundPermissionDenied => 'Activity permission off';

  @override
  String get myDataOpenSettings => 'Open settings';

  @override
  String get myDataStatusIndicator => 'Status indicator';

  @override
  String get myDataFootprintSamplesStored => 'samples stored';

  @override
  String myDataFootprintSamplesStoredSemantics(String count) {
    return '$count samples stored';
  }

  @override
  String get myDataFootprintDatabaseSize => 'database size';

  @override
  String myDataFootprintDatabaseSizeSemantics(String size) {
    return 'Database size $size';
  }

  @override
  String get myDataFootprintNotOptimizedYet => 'not optimized yet';

  @override
  String myDataFootprintOptimized(String relativeTime) {
    return 'optimized $relativeTime';
  }

  @override
  String get myDataPurgeConfirmTitle => 'Delete all local data?';

  @override
  String get myDataPurgeConfirmBody =>
      'This removes all step history on this device. Export first if you want to keep a copy.';

  @override
  String get myDataPurgeExportFirst => 'Export first';

  @override
  String get myDataPurgeDeleteAnyway => 'Delete anyway';

  @override
  String get myDataImportConfirmTitle => 'Import data?';

  @override
  String myDataImportConfirmBody(int csvRowCount, int existingSampleCount) {
    return 'This file contains $csvRowCount samples. Your database already has $existingSampleCount samples. Rows with matching IDs or the same time bucket will be skipped — existing data is not overwritten.';
  }

  @override
  String get myDataImportConfirmImport => 'Import';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutAppName => 'Astra Health';

  @override
  String aboutVersion(String version) {
    return 'Version: $version';
  }

  @override
  String get unitDistanceMetric => 'Metric';

  @override
  String get unitDistanceImperial => 'Imperial';

  @override
  String get unitWeightKg => 'Kg';

  @override
  String get unitWeightLb => 'lb';

  @override
  String get unitHeightCm => 'cm';

  @override
  String get unitHeightFtIn => 'ft+in';

  @override
  String get unitDistanceKm => 'Km';

  @override
  String get unitDistanceMi => 'Mi';

  @override
  String unitHeightFtInDisplay(int feet, int inches) {
    return '$feet ft $inches in';
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
  String get relativeTimeNever => 'never';

  @override
  String get relativeTimeJustNow => 'just now';

  @override
  String relativeTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String relativeTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String relativeTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get relativeTimeMinute => 'minute';

  @override
  String get relativeTimeMinutes => 'minutes';

  @override
  String get relativeTimeHour => 'hour';

  @override
  String get relativeTimeHours => 'hours';

  @override
  String get relativeTimeDay => 'day';

  @override
  String get relativeTimeDays => 'days';

  @override
  String get todayScreenTitle => 'Steps';

  @override
  String get todayWeekSectionHeadline => 'This week';

  @override
  String get todaySetGoalLabel => 'Set goal';

  @override
  String get todayGoalSaveError => 'Daily goal could not be saved. Try again.';

  @override
  String get bannerStaleFullIos =>
      'No new steps in 4+ hours. Steps update when you open the app on this device.';

  @override
  String get bannerStaleFullAndroid =>
      'No new steps in 12+ hours. Background collection may be delayed on this device.';

  @override
  String get bannerInfoStepsSync =>
      'Steps update when you open the app on this device.';

  @override
  String get commonErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get todayCollectionHealthActive => 'Collection active ●';

  @override
  String todayCollectionHealthStale(String relativeTime) {
    return 'Last sync $relativeTime ⚠';
  }

  @override
  String get todayCollectionHealthPermissionDenied => 'Sensor access revoked ✕';

  @override
  String get todayGoalRingStepsLabel => 'Steps';

  @override
  String get todayGoalRingSemanticsLoading => 'Steps today: loading';

  @override
  String get todayGoalRingSemanticsNoPermission =>
      'Steps today: permission required';

  @override
  String todayGoalRingSemanticsGoalReached(int steps, int goal) {
    return 'Steps today: $steps. Daily goal $goal reached.';
  }

  @override
  String todayGoalRingSemanticsProgress(int steps, int goal) {
    return 'Steps today: $steps of $goal';
  }

  @override
  String get todayGoalCelebrationLabel => 'Daily goal reached';

  @override
  String get todayGoalEditorTitle => 'Daily step goal';

  @override
  String get todayGoalValidationError =>
      'Enter a value between 1,000 and 100,000.';

  @override
  String todayWeekGoalsMetSemantics(int count, int total) {
    return 'Goals met $count of $total days this week';
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
  String get onboardingContinueBtn => 'Continue';

  @override
  String get onboardingSkipBtn => 'Skip';

  @override
  String get onboardingLetsGoBtn => 'Let\'s Go';

  @override
  String get onboardingIntroHeadline => 'Your Health. Your Phone. Period.';

  @override
  String get onboardingIntroParagraphOne =>
      'Astra tracks your movement, habits, and health metrics using only your device\'s built-in sensors. No accounts, no cloud leakage.';

  @override
  String get onboardingIntroParagraphTwo =>
      'Your personal evolution belongs to you—and only you.';

  @override
  String get onboardingWeightTitle => 'What is your weight?';

  @override
  String get onboardingHeightTitle => 'What is your height?';

  @override
  String get onboardingOptionalMetricsHint =>
      'Weight and height are optional, but help improve the accuracy of measurements in the app.';

  @override
  String get onboardingUnitKg => 'kg';

  @override
  String get onboardingUnitLb => 'lb';

  @override
  String get onboardingUnitCm => 'cm';

  @override
  String get onboardingUnitIn => 'in';

  @override
  String get onboardingWeightUnitSemantics => 'Select weight unit';

  @override
  String get onboardingHeightUnitSemantics => 'Select height unit';

  @override
  String get trendsScreenTitle => 'Trends';

  @override
  String get trendsPeriod7Days => '7 days';

  @override
  String get trendsPeriod30Days => '30 days';

  @override
  String get trendsPeriod12Months => '12 months';

  @override
  String get trendsChartRangeSemantics => 'Chart range';

  @override
  String get trendsEmptyHistory =>
      'No history yet. Walk a bit — data stays on this device.';

  @override
  String get trendsStepBarChartSemantics => 'Step history bar chart';

  @override
  String get trendsMonthlyBarChartSemantics =>
      'Twelve month step history bar chart';

  @override
  String get trendsAverageKcalCaption => 'average calories burned per day';

  @override
  String get trendsAverageStepsCaption => 'average steps taken per day';

  @override
  String trendsAverageKcalSemantics(int kcal) {
    return 'Average $kcal kilocalories burned per day';
  }

  @override
  String trendsAverageStepsSemantics(int steps) {
    return 'Average $steps steps taken per day';
  }

  @override
  String get trendsPeakDayCaption => 'peak day in this period';

  @override
  String trendsPeakDaySemantics(String dateLabel, int steps) {
    return 'Peak day $dateLabel with $steps steps in this period';
  }

  @override
  String chartTooltipStepsOfGoal(int steps, int goal) {
    return '$steps/$goal steps';
  }

  @override
  String get chartGoalStatusNoGoal => 'no goal set';

  @override
  String chartGoalStatusOverGoal(int count) {
    return '$count over goal';
  }

  @override
  String chartGoalStatusBelowGoal(int count) {
    return '$count below goal';
  }

  @override
  String get chartGoalStatusMet => 'goal met';

  @override
  String chartSelectionSemantics(
    String date,
    int steps,
    int goal,
    String status,
  ) {
    return '$date, $steps of $goal steps, $status';
  }

  @override
  String trendsMonthlyTooltipStepsPerDay(int steps) {
    return '$steps steps/day';
  }

  @override
  String trendsMonthlyTooltipTotal(int total, int days) {
    return '$total total · $days days';
  }

  @override
  String get commonWeekdayMon => 'Mon';

  @override
  String get commonWeekdayTue => 'Tue';

  @override
  String get commonWeekdayWed => 'Wed';

  @override
  String get commonWeekdayThu => 'Thu';

  @override
  String get commonWeekdayFri => 'Fri';

  @override
  String get commonWeekdaySat => 'Sat';

  @override
  String get commonWeekdaySun => 'Sun';

  @override
  String get commonMonthJan => 'Jan';

  @override
  String get commonMonthFeb => 'Feb';

  @override
  String get commonMonthMar => 'Mar';

  @override
  String get commonMonthApr => 'Apr';

  @override
  String get commonMonthMay => 'May';

  @override
  String get commonMonthJun => 'Jun';

  @override
  String get commonMonthJul => 'Jul';

  @override
  String get commonMonthAug => 'Aug';

  @override
  String get commonMonthSep => 'Sep';

  @override
  String get commonMonthOct => 'Oct';

  @override
  String get commonMonthNov => 'Nov';

  @override
  String get commonMonthDec => 'Dec';

  @override
  String get commonMonthJanuary => 'January';

  @override
  String get commonMonthFebruary => 'February';

  @override
  String get commonMonthMarch => 'March';

  @override
  String get commonMonthApril => 'April';

  @override
  String get commonMonthMayFull => 'May';

  @override
  String get commonMonthJune => 'June';

  @override
  String get commonMonthJuly => 'July';

  @override
  String get commonMonthAugust => 'August';

  @override
  String get commonMonthSeptember => 'September';

  @override
  String get commonMonthOctober => 'October';

  @override
  String get commonMonthNovember => 'November';

  @override
  String get commonMonthDecember => 'December';
}
