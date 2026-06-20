import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Application title shown in task switcher / OS shell
  ///
  /// In en, this message translates to:
  /// **'ASTRA'**
  String get appTitle;

  /// My Data screen title and menu label (audit REF-21)
  ///
  /// In en, this message translates to:
  /// **'Privacy & My Data'**
  String get menuPrivacyAndData;

  /// My Data Background section headline (audit REF-21)
  ///
  /// In en, this message translates to:
  /// **'Step Tracking Status'**
  String get menuTrackingStatus;

  /// Compact stale-data banner on Today screen (audit REF-21)
  ///
  /// In en, this message translates to:
  /// **'Data outdated. Tap to refresh.'**
  String get bannerStaleData;

  /// Today screen permission CTA when step access is denied (audit REF-21)
  ///
  /// In en, this message translates to:
  /// **'Step access denied. Tap to fix.'**
  String get errorNoPermission;

  /// Onboarding step 0 primary button label (audit REF-21)
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardingStartBtn;

  /// Weekly step trend chip when steps increased
  ///
  /// In en, this message translates to:
  /// **'Up {percentage}% from last week'**
  String trendsWeeklyGrowth(int percentage);

  /// Weekly step trend chip when steps decreased
  ///
  /// In en, this message translates to:
  /// **'Down {percentage}% from last week'**
  String trendsWeeklyDecline(int percentage);

  /// Weekly step trend chip when steps unchanged from prior week
  ///
  /// In en, this message translates to:
  /// **'Same as last week'**
  String get trendsWeeklyFlat;

  /// Weekly step trend chip when prior week has no step data
  ///
  /// In en, this message translates to:
  /// **'No prior week data'**
  String get trendsNoPriorWeek;

  /// Menu hub screen title
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuTitle;

  /// Menu hub section headline for profile and data links
  ///
  /// In en, this message translates to:
  /// **'Informations'**
  String get menuSectionInformations;

  /// Menu hub navigation label for Profile screen
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get menuProfile;

  /// Short menu navigation label for My Data screen
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get menuData;

  /// Menu hub section headline for settings and about
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get menuOther;

  /// Menu hub navigation label for Settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// Menu hub navigation label for About screen
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get menuAbout;

  /// Bottom navigation tab label for Today / steps
  ///
  /// In en, this message translates to:
  /// **'STEPS'**
  String get navSteps;

  /// Bottom navigation tab label for History / trends
  ///
  /// In en, this message translates to:
  /// **'TRENDS'**
  String get navTrends;

  /// Bottom navigation tab label for Menu hub
  ///
  /// In en, this message translates to:
  /// **'MENU'**
  String get navMenu;

  /// Generic save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Generic cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Back navigation button label and semantics
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Placeholder when an optional profile field has no value
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// Default semantics hint for navigation rows
  ///
  /// In en, this message translates to:
  /// **'Double tap to open.'**
  String get commonDoubleTapToOpen;

  /// Default semantics hint for editable profile rows
  ///
  /// In en, this message translates to:
  /// **'Double tap to edit.'**
  String get commonDoubleTapToEdit;

  /// Default semantics hint for settings preference rows
  ///
  /// In en, this message translates to:
  /// **'Double tap to change.'**
  String get commonDoubleTapToChange;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section headline for language preference
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language selector option for English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// Language selector option for French
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get settingsLanguageFrench;

  /// Subtitle when no explicit language preference is saved
  ///
  /// In en, this message translates to:
  /// **'Using device language'**
  String get settingsLanguageAutomatic;

  /// Snack bar when saving language preference fails
  ///
  /// In en, this message translates to:
  /// **'Could not update language'**
  String get settingsLanguageUpdateError;

  /// Settings section headline for unit preferences
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get settingsUnits;

  /// Distance unit preference label
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get settingsDistance;

  /// Weight unit preference label
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get settingsWeight;

  /// Height unit preference label
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get settingsHeight;

  /// Settings section headline for notification preferences
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Toggle label for goal notification preference
  ///
  /// In en, this message translates to:
  /// **'Receive Goal notifications'**
  String get settingsGoalNotifications;

  /// Settings section headline for theme and accent
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Snack bar when saving a unit preference fails
  ///
  /// In en, this message translates to:
  /// **'Could not update unit preference'**
  String get settingsUnitPreferenceUpdateError;

  /// Snack bar when saving notification preference fails
  ///
  /// In en, this message translates to:
  /// **'Could not update notification setting'**
  String get settingsNotificationUpdateError;

  /// Theme selector option for system appearance
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// Semantics label for system theme option
  ///
  /// In en, this message translates to:
  /// **'System appearance'**
  String get settingsThemeSystemSemantics;

  /// Theme selector option for light appearance
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Semantics label for light theme option
  ///
  /// In en, this message translates to:
  /// **'Light appearance'**
  String get settingsThemeLightSemantics;

  /// Theme selector option for dark appearance
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Semantics label for dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark appearance'**
  String get settingsThemeDarkSemantics;

  /// Semantics hint for theme segmented control
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get settingsThemeSemanticsHint;

  /// Semantics label for orange accent preset chip
  ///
  /// In en, this message translates to:
  /// **'Accent color, Orange'**
  String get settingsAccentOrange;

  /// Semantics label for red accent preset chip
  ///
  /// In en, this message translates to:
  /// **'Accent color, Red'**
  String get settingsAccentRed;

  /// Semantics label for green accent preset chip
  ///
  /// In en, this message translates to:
  /// **'Accent color, Green'**
  String get settingsAccentGreen;

  /// Semantics label for blue accent preset chip
  ///
  /// In en, this message translates to:
  /// **'Accent color, Blue'**
  String get settingsAccentBlue;

  /// Semantics label for magenta accent preset chip
  ///
  /// In en, this message translates to:
  /// **'Accent color, Magenta'**
  String get settingsAccentMagenta;

  /// Semantics label for pink accent preset chip
  ///
  /// In en, this message translates to:
  /// **'Accent color, Pink'**
  String get settingsAccentPink;

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Profile section headline for editable fields
  ///
  /// In en, this message translates to:
  /// **'Informations'**
  String get profileSectionInformations;

  /// Fallback error message when profile screen fails to load
  ///
  /// In en, this message translates to:
  /// **'Could not load profile'**
  String get profileCouldNotLoad;

  /// Snack bar when display name save fails
  ///
  /// In en, this message translates to:
  /// **'Could not save display name'**
  String get profileCouldNotSaveDisplayName;

  /// Snack bar when height save fails
  ///
  /// In en, this message translates to:
  /// **'Could not save height'**
  String get profileCouldNotSaveHeight;

  /// Snack bar when weight save fails
  ///
  /// In en, this message translates to:
  /// **'Could not save weight'**
  String get profileCouldNotSaveWeight;

  /// Error message when profile cubit refresh fails
  ///
  /// In en, this message translates to:
  /// **'Could not load profile settings'**
  String get profileLoadErrorGeneric;

  /// Profile display name field label
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileDisplayName;

  /// Text field label in display name editor sheet
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get profileDisplayNameFirstName;

  /// Semantics label for display name edit chevron
  ///
  /// In en, this message translates to:
  /// **'Edit display name'**
  String get profileDisplayNameEditSemantics;

  /// Semantics label for editable display name row
  ///
  /// In en, this message translates to:
  /// **'Display name, {value}. {hint}'**
  String profileDisplayNameSemantics(String value, String hint);

  /// Semantics label for read-only display name row
  ///
  /// In en, this message translates to:
  /// **'Display name, {value}.'**
  String profileDisplayNameReadOnlySemantics(String value);

  /// Profile height field label
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get profileHeight;

  /// Profile weight field label
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get profileWeight;

  /// Height editor feet input label
  ///
  /// In en, this message translates to:
  /// **'Feet'**
  String get profileHeightFeet;

  /// Height editor inches input label
  ///
  /// In en, this message translates to:
  /// **'Inches'**
  String get profileHeightInches;

  /// Height editor centimeters input label
  ///
  /// In en, this message translates to:
  /// **'Centimeters'**
  String get profileHeightCentimeters;

  /// Height editor validation when cm input is not a whole number
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number in centimeters'**
  String get profileHeightEnterWholeNumberCm;

  /// Height editor validation when cm value is out of range
  ///
  /// In en, this message translates to:
  /// **'Height must be between {min} and {max} cm'**
  String profileHeightRangeCm(int min, int max);

  /// Height editor validation when only one of feet/inches is filled
  ///
  /// In en, this message translates to:
  /// **'Enter both feet and inches'**
  String get profileHeightEnterBothFtIn;

  /// Height editor validation when ft/in input is not numeric
  ///
  /// In en, this message translates to:
  /// **'Enter whole numbers for feet and inches'**
  String get profileHeightEnterWholeNumbersFtIn;

  /// Height editor validation when inches are out of range
  ///
  /// In en, this message translates to:
  /// **'Inches must be between 0 and 11'**
  String get profileHeightInchesRange;

  /// Height editor validation when ft/in value is out of range
  ///
  /// In en, this message translates to:
  /// **'Height must be between {minFeet} ft {minInches} in and {maxFeet} ft {maxInches} in'**
  String profileHeightRangeFtIn(
    int minFeet,
    int minInches,
    int maxFeet,
    int maxInches,
  );

  /// Weight editor pounds input label
  ///
  /// In en, this message translates to:
  /// **'Pounds'**
  String get profileWeightPounds;

  /// Weight editor kilograms input label
  ///
  /// In en, this message translates to:
  /// **'Kilograms'**
  String get profileWeightKilograms;

  /// Weight editor validation when input is not a number
  ///
  /// In en, this message translates to:
  /// **'Enter a valid weight'**
  String get profileWeightEnterValid;

  /// Weight editor validation when too many decimal places
  ///
  /// In en, this message translates to:
  /// **'Use at most one decimal place'**
  String get profileWeightOneDecimal;

  /// Weight editor validation when kg value is out of range
  ///
  /// In en, this message translates to:
  /// **'Weight must be between {min} and {max} kg'**
  String profileWeightRangeKg(int min, int max);

  /// Weight editor validation when lb value is out of range
  ///
  /// In en, this message translates to:
  /// **'Weight must be between {min} and {max} lb'**
  String profileWeightRangeLb(String min, String max);

  /// My Data section headline for database footprint KPIs
  ///
  /// In en, this message translates to:
  /// **'Footprint'**
  String get myDataFootprint;

  /// My Data section headline for export/import/purge actions
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get myDataYourData;

  /// Snack bar after successful CSV export
  ///
  /// In en, this message translates to:
  /// **'Export saved'**
  String get myDataExportSaved;

  /// Snack bar after successful CSV import
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get myDataImportComplete;

  /// Snack bar after successful local data purge
  ///
  /// In en, this message translates to:
  /// **'All local data removed'**
  String get myDataPurgeSuccess;

  /// Export CSV button label
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get myDataExportCsv;

  /// Semantics label for export CSV button
  ///
  /// In en, this message translates to:
  /// **'Export data as CSV file'**
  String get myDataExportCsvSemantics;

  /// Import CSV button label
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get myDataImportCsv;

  /// Semantics label for import CSV button
  ///
  /// In en, this message translates to:
  /// **'Import CSV file'**
  String get myDataImportCsvSemantics;

  /// Purge button label on My Data screen
  ///
  /// In en, this message translates to:
  /// **'Delete all local data'**
  String get myDataDeleteAllLocalData;

  /// Error banner when CSV export fails
  ///
  /// In en, this message translates to:
  /// **'Export could not be completed. Try again.'**
  String get myDataExportErrorGeneric;

  /// Error banner when CSV import fails
  ///
  /// In en, this message translates to:
  /// **'Import could not be completed. Try again.'**
  String get myDataImportErrorGeneric;

  /// Error banner when data purge fails
  ///
  /// In en, this message translates to:
  /// **'Purge could not be completed. Try again.'**
  String get myDataPurgeErrorGeneric;

  /// Error banner when purge succeeds but post-purge refresh fails
  ///
  /// In en, this message translates to:
  /// **'All local data was removed, but the app could not refresh. Try again.'**
  String get myDataPurgeRefreshError;

  /// Background status when collection is healthy
  ///
  /// In en, this message translates to:
  /// **'Background collection active · Last sync {relativeTime}'**
  String myDataBackgroundHealthy(String relativeTime);

  /// Background status when collection is stale
  ///
  /// In en, this message translates to:
  /// **'Background collection delayed · Last sync {relativeTime}'**
  String myDataBackgroundStale(String relativeTime);

  /// Background status on iOS when steps sync on app open
  ///
  /// In en, this message translates to:
  /// **'Steps sync when you open the app · Last sync {relativeTime}'**
  String myDataBackgroundIosBackfill(String relativeTime);

  /// Background status when activity permission is denied
  ///
  /// In en, this message translates to:
  /// **'Activity permission off'**
  String get myDataBackgroundPermissionDenied;

  /// Button to open OS settings when activity permission is off
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get myDataOpenSettings;

  /// Semantics label for background status dot
  ///
  /// In en, this message translates to:
  /// **'Status indicator'**
  String get myDataStatusIndicator;

  /// Footprint KPI caption for sample count
  ///
  /// In en, this message translates to:
  /// **'samples stored'**
  String get myDataFootprintSamplesStored;

  /// Semantics label for sample count KPI
  ///
  /// In en, this message translates to:
  /// **'{count} samples stored'**
  String myDataFootprintSamplesStoredSemantics(String count);

  /// Footprint KPI caption for database file size
  ///
  /// In en, this message translates to:
  /// **'database size'**
  String get myDataFootprintDatabaseSize;

  /// Semantics label for database size KPI
  ///
  /// In en, this message translates to:
  /// **'Database size {size}'**
  String myDataFootprintDatabaseSizeSemantics(String size);

  /// Footprint KPI caption when database has never been optimized
  ///
  /// In en, this message translates to:
  /// **'not optimized yet'**
  String get myDataFootprintNotOptimizedYet;

  /// Footprint KPI caption when database was optimized
  ///
  /// In en, this message translates to:
  /// **'optimized {relativeTime}'**
  String myDataFootprintOptimized(String relativeTime);

  /// Purge confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete all local data?'**
  String get myDataPurgeConfirmTitle;

  /// Purge confirmation dialog body copy
  ///
  /// In en, this message translates to:
  /// **'This removes all step history on this device. Export first if you want to keep a copy.'**
  String get myDataPurgeConfirmBody;

  /// Purge dialog button to export before deleting
  ///
  /// In en, this message translates to:
  /// **'Export first'**
  String get myDataPurgeExportFirst;

  /// Purge dialog button to confirm deletion
  ///
  /// In en, this message translates to:
  /// **'Delete anyway'**
  String get myDataPurgeDeleteAnyway;

  /// Import confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Import data?'**
  String get myDataImportConfirmTitle;

  /// Import confirmation dialog body copy
  ///
  /// In en, this message translates to:
  /// **'This file contains {csvRowCount} samples. Your database already has {existingSampleCount} samples. Rows with matching IDs or the same time bucket will be skipped — existing data is not overwritten.'**
  String myDataImportConfirmBody(int csvRowCount, int existingSampleCount);

  /// Import confirmation dialog confirm button
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get myDataImportConfirmImport;

  /// About screen title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// App name shown on About screen
  ///
  /// In en, this message translates to:
  /// **'Astra Health'**
  String get aboutAppName;

  /// Version line on About screen
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String aboutVersion(String version);

  /// Distance unit preference label for metric
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get unitDistanceMetric;

  /// Distance unit preference label for imperial
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get unitDistanceImperial;

  /// Weight unit preference label for kilograms
  ///
  /// In en, this message translates to:
  /// **'Kg'**
  String get unitWeightKg;

  /// Weight unit preference label for pounds
  ///
  /// In en, this message translates to:
  /// **'lb'**
  String get unitWeightLb;

  /// Height unit preference label for centimeters
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get unitHeightCm;

  /// Height unit preference label for feet and inches
  ///
  /// In en, this message translates to:
  /// **'ft+in'**
  String get unitHeightFtIn;

  /// Display label for kilometers
  ///
  /// In en, this message translates to:
  /// **'Km'**
  String get unitDistanceKm;

  /// Display label for miles
  ///
  /// In en, this message translates to:
  /// **'Mi'**
  String get unitDistanceMi;

  /// Formatted height in feet and inches
  ///
  /// In en, this message translates to:
  /// **'{feet} ft {inches} in'**
  String unitHeightFtInDisplay(int feet, int inches);

  /// Formatted height in centimeters
  ///
  /// In en, this message translates to:
  /// **'{height} cm'**
  String unitHeightCmDisplay(int height);

  /// Formatted weight in pounds
  ///
  /// In en, this message translates to:
  /// **'{weight} lb'**
  String unitWeightLbDisplay(String weight);

  /// Formatted weight in kilograms
  ///
  /// In en, this message translates to:
  /// **'{weight} kg'**
  String unitWeightKgDisplay(String weight);

  /// Relative time when no prior sync exists
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get relativeTimeNever;

  /// Relative time for very recent events
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relativeTimeJustNow;

  /// Relative time in minutes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String relativeTimeMinutesAgo(int count);

  /// Relative time in hours
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String relativeTimeHoursAgo(int count);

  /// Relative time in days
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String relativeTimeDaysAgo(int count);

  /// Singular minute unit for relative time formatting
  ///
  /// In en, this message translates to:
  /// **'minute'**
  String get relativeTimeMinute;

  /// Plural minute unit for relative time formatting
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get relativeTimeMinutes;

  /// Singular hour unit for relative time formatting
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get relativeTimeHour;

  /// Plural hour unit for relative time formatting
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get relativeTimeHours;

  /// Singular day unit for relative time formatting
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get relativeTimeDay;

  /// Plural day unit for relative time formatting
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get relativeTimeDays;

  /// Today screen title and screen semantics label
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get todayScreenTitle;

  /// Section headline above the week progress row on Today
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get todayWeekSectionHeadline;

  /// Button label to open the daily step goal editor
  ///
  /// In en, this message translates to:
  /// **'Set goal'**
  String get todaySetGoalLabel;

  /// SnackBar when saving the daily step goal fails
  ///
  /// In en, this message translates to:
  /// **'Daily goal could not be saved. Try again.'**
  String get todayGoalSaveError;

  /// Full stale-data banner on My Data when running on iOS
  ///
  /// In en, this message translates to:
  /// **'No new steps in 4+ hours. Steps update when you open the app on this device.'**
  String get bannerStaleFullIos;

  /// Full stale-data banner on My Data when running on Android
  ///
  /// In en, this message translates to:
  /// **'No new steps in 12+ hours. Background collection may be delayed on this device.'**
  String get bannerStaleFullAndroid;

  /// Info banner explaining foreground step sync behaviour
  ///
  /// In en, this message translates to:
  /// **'Steps update when you open the app on this device.'**
  String get bannerInfoStepsSync;

  /// Generic fallback error message for action banners
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get commonErrorGeneric;

  /// Collection health indicator when ingestion is current
  ///
  /// In en, this message translates to:
  /// **'Collection active ●'**
  String get todayCollectionHealthActive;

  /// Collection health indicator when data is stale
  ///
  /// In en, this message translates to:
  /// **'Last sync {relativeTime} ⚠'**
  String todayCollectionHealthStale(String relativeTime);

  /// Collection health indicator when step sensor permission is denied
  ///
  /// In en, this message translates to:
  /// **'Sensor access revoked ✕'**
  String get todayCollectionHealthPermissionDenied;

  /// Label under the sneaker icon in the goal ring center
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get todayGoalRingStepsLabel;

  /// Goal ring accessibility label while step count is loading
  ///
  /// In en, this message translates to:
  /// **'Steps today: loading'**
  String get todayGoalRingSemanticsLoading;

  /// Goal ring accessibility label when step permission is denied
  ///
  /// In en, this message translates to:
  /// **'Steps today: permission required'**
  String get todayGoalRingSemanticsNoPermission;

  /// Goal ring accessibility label when daily goal is met or exceeded
  ///
  /// In en, this message translates to:
  /// **'Steps today: {steps}. Daily goal {goal} reached.'**
  String todayGoalRingSemanticsGoalReached(int steps, int goal);

  /// Goal ring accessibility label showing progress toward daily goal
  ///
  /// In en, this message translates to:
  /// **'Steps today: {steps} of {goal}'**
  String todayGoalRingSemanticsProgress(int steps, int goal);

  /// Celebration overlay copy when daily step goal is reached
  ///
  /// In en, this message translates to:
  /// **'Daily goal reached'**
  String get todayGoalCelebrationLabel;

  /// Title of the daily step goal editor bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Daily step goal'**
  String get todayGoalEditorTitle;

  /// Validation error for invalid daily step goal input
  ///
  /// In en, this message translates to:
  /// **'Enter a value between 1,000 and 100,000.'**
  String get todayGoalValidationError;

  /// Week trophy badge accessibility label
  ///
  /// In en, this message translates to:
  /// **'Goals met {count} of {total} days this week'**
  String todayWeekGoalsMetSemantics(int count, int total);

  /// Week day pill accessibility label
  ///
  /// In en, this message translates to:
  /// **'{weekdayLabel} {dayNumber}'**
  String todayWeekDaySemantics(String weekdayLabel, int dayNumber);

  /// Kilocalorie unit label in Today activity stats row
  ///
  /// In en, this message translates to:
  /// **'Kcal'**
  String get todayStatsKcalLabel;

  /// Kilometre unit label in Today activity stats row
  ///
  /// In en, this message translates to:
  /// **'Km'**
  String get todayStatsKmLabel;

  /// Mile unit label in Today activity stats row
  ///
  /// In en, this message translates to:
  /// **'Mi'**
  String get todayStatsMiLabel;

  /// Onboarding primary button for weight and height steps
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinueBtn;

  /// Onboarding secondary button to skip optional metrics
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkipBtn;

  /// Onboarding final step primary button to complete setup
  ///
  /// In en, this message translates to:
  /// **'Let\'s Go'**
  String get onboardingLetsGoBtn;

  /// Onboarding intro screen headline
  ///
  /// In en, this message translates to:
  /// **'Your Health. Your Phone. Period.'**
  String get onboardingIntroHeadline;

  /// Onboarding intro first card paragraph
  ///
  /// In en, this message translates to:
  /// **'Astra tracks your movement, habits, and health metrics using only your device\'s built-in sensors. No accounts, no cloud leakage.'**
  String get onboardingIntroParagraphOne;

  /// Onboarding intro second card paragraph
  ///
  /// In en, this message translates to:
  /// **'Your personal evolution belongs to you—and only you.'**
  String get onboardingIntroParagraphTwo;

  /// Onboarding weight picker screen title
  ///
  /// In en, this message translates to:
  /// **'What is your weight?'**
  String get onboardingWeightTitle;

  /// Onboarding height picker screen title
  ///
  /// In en, this message translates to:
  /// **'What is your height?'**
  String get onboardingHeightTitle;

  /// Hint below weight/height pickers explaining optional metrics
  ///
  /// In en, this message translates to:
  /// **'Weight and height are optional, but help improve the accuracy of measurements in the app.'**
  String get onboardingOptionalMetricsHint;

  /// Kilogram unit label on onboarding weight picker
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get onboardingUnitKg;

  /// Pound unit label on onboarding weight picker
  ///
  /// In en, this message translates to:
  /// **'lb'**
  String get onboardingUnitLb;

  /// Centimetre unit label on onboarding height picker
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get onboardingUnitCm;

  /// Inch unit label on onboarding height picker
  ///
  /// In en, this message translates to:
  /// **'in'**
  String get onboardingUnitIn;

  /// Semantics hint for weight unit segmented control
  ///
  /// In en, this message translates to:
  /// **'Select weight unit'**
  String get onboardingWeightUnitSemantics;

  /// Semantics hint for height unit segmented control
  ///
  /// In en, this message translates to:
  /// **'Select height unit'**
  String get onboardingHeightUnitSemantics;

  /// Trends screen title and semantics label
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trendsScreenTitle;

  /// Trends chart period toggle — seven day window
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get trendsPeriod7Days;

  /// Trends chart period toggle — thirty day window
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get trendsPeriod30Days;

  /// Trends chart period toggle — twelve month window
  ///
  /// In en, this message translates to:
  /// **'12 months'**
  String get trendsPeriod12Months;

  /// Semantics hint for Trends period segmented control
  ///
  /// In en, this message translates to:
  /// **'Chart range'**
  String get trendsChartRangeSemantics;

  /// Empty state copy when no step history exists for chart
  ///
  /// In en, this message translates to:
  /// **'No history yet. Walk a bit — data stays on this device.'**
  String get trendsEmptyHistory;

  /// Accessibility label for daily step bar chart
  ///
  /// In en, this message translates to:
  /// **'Step history bar chart'**
  String get trendsStepBarChartSemantics;

  /// Accessibility label for twelve month bar chart
  ///
  /// In en, this message translates to:
  /// **'Twelve month step history bar chart'**
  String get trendsMonthlyBarChartSemantics;

  /// Caption under average kcal stat on Trends screen
  ///
  /// In en, this message translates to:
  /// **'average calories burned per day'**
  String get trendsAverageKcalCaption;

  /// Caption under average steps stat on Trends screen
  ///
  /// In en, this message translates to:
  /// **'average steps taken per day'**
  String get trendsAverageStepsCaption;

  /// Accessibility label for average kcal stat card
  ///
  /// In en, this message translates to:
  /// **'Average {kcal} kilocalories burned per day'**
  String trendsAverageKcalSemantics(int kcal);

  /// Accessibility label for average steps stat card
  ///
  /// In en, this message translates to:
  /// **'Average {steps} steps taken per day'**
  String trendsAverageStepsSemantics(int steps);

  /// Caption under peak day stat on Trends screen
  ///
  /// In en, this message translates to:
  /// **'peak day in this period'**
  String get trendsPeakDayCaption;

  /// Accessibility label for peak day stat card
  ///
  /// In en, this message translates to:
  /// **'Peak day {dateLabel} with {steps} steps in this period'**
  String trendsPeakDaySemantics(String dateLabel, int steps);

  /// Daily bar chart tooltip steps versus goal
  ///
  /// In en, this message translates to:
  /// **'{steps}/{goal} steps'**
  String chartTooltipStepsOfGoal(int steps, int goal);

  /// Bar chart selection semantics when no daily goal is set
  ///
  /// In en, this message translates to:
  /// **'no goal set'**
  String get chartGoalStatusNoGoal;

  /// Bar chart selection semantics when steps exceed goal
  ///
  /// In en, this message translates to:
  /// **'{count} over goal'**
  String chartGoalStatusOverGoal(int count);

  /// Bar chart selection semantics when steps are below goal
  ///
  /// In en, this message translates to:
  /// **'{count} below goal'**
  String chartGoalStatusBelowGoal(int count);

  /// Bar chart selection semantics when daily goal is exactly met
  ///
  /// In en, this message translates to:
  /// **'goal met'**
  String get chartGoalStatusMet;

  /// Bar chart accessibility label when a day bar is selected
  ///
  /// In en, this message translates to:
  /// **'{date}, {steps} of {goal} steps, {status}'**
  String chartSelectionSemantics(
    String date,
    int steps,
    int goal,
    String status,
  );

  /// Monthly bar chart tooltip average steps per day
  ///
  /// In en, this message translates to:
  /// **'{steps} steps/day'**
  String trendsMonthlyTooltipStepsPerDay(int steps);

  /// Monthly bar chart tooltip total steps and day count
  ///
  /// In en, this message translates to:
  /// **'{total} total · {days} days'**
  String trendsMonthlyTooltipTotal(int total, int days);

  /// Short Monday label for charts
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get commonWeekdayMon;

  /// Short Tuesday label for charts
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get commonWeekdayTue;

  /// Short Wednesday label for charts
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get commonWeekdayWed;

  /// Short Thursday label for charts
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get commonWeekdayThu;

  /// Short Friday label for charts
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get commonWeekdayFri;

  /// Short Saturday label for charts
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get commonWeekdaySat;

  /// Short Sunday label for charts
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get commonWeekdaySun;

  /// Uppercase Monday label for Today week progress pills
  ///
  /// In en, this message translates to:
  /// **'MON'**
  String get todayWeekPillMon;

  /// Uppercase Tuesday label for Today week progress pills
  ///
  /// In en, this message translates to:
  /// **'TUE'**
  String get todayWeekPillTue;

  /// Uppercase Wednesday label for Today week progress pills
  ///
  /// In en, this message translates to:
  /// **'WED'**
  String get todayWeekPillWed;

  /// Uppercase Thursday label for Today week progress pills
  ///
  /// In en, this message translates to:
  /// **'THU'**
  String get todayWeekPillThu;

  /// Uppercase Friday label for Today week progress pills
  ///
  /// In en, this message translates to:
  /// **'FRI'**
  String get todayWeekPillFri;

  /// Uppercase Saturday label for Today week progress pills
  ///
  /// In en, this message translates to:
  /// **'SAT'**
  String get todayWeekPillSat;

  /// Uppercase Sunday label for Today week progress pills
  ///
  /// In en, this message translates to:
  /// **'SUN'**
  String get todayWeekPillSun;

  /// Short January label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get commonMonthJan;

  /// Short February label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get commonMonthFeb;

  /// Short March label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get commonMonthMar;

  /// Short April label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get commonMonthApr;

  /// Short May label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get commonMonthMay;

  /// Short June label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get commonMonthJun;

  /// Short July label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get commonMonthJul;

  /// Short August label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get commonMonthAug;

  /// Short September label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get commonMonthSep;

  /// Short October label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get commonMonthOct;

  /// Short November label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get commonMonthNov;

  /// Short December label for chart period captions
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get commonMonthDec;

  /// Full January name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get commonMonthJanuary;

  /// Full February name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get commonMonthFebruary;

  /// Full March name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get commonMonthMarch;

  /// Full April name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get commonMonthApril;

  /// Full May name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get commonMonthMayFull;

  /// Full June name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get commonMonthJune;

  /// Full July name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get commonMonthJuly;

  /// Full August name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get commonMonthAugust;

  /// Full September name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get commonMonthSeptember;

  /// Full October name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get commonMonthOctober;

  /// Full November name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get commonMonthNovember;

  /// Full December name for chart tooltips
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get commonMonthDecember;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
