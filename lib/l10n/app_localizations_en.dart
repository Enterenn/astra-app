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
}
