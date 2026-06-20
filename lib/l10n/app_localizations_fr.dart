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
}
