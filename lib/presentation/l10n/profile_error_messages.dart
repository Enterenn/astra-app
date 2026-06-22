import 'package:astra_app/l10n/app_localizations.dart';

import '../cubits/profile_errors.dart';

String profileLoadErrorMessage(
  AppLocalizations l10n,
  ProfileLoadError? error,
) {
  return switch (error) {
    null => l10n.profileCouldNotLoad,
    ProfileLoadError.generic => l10n.profileLoadErrorGeneric,
  };
}
