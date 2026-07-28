import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ur'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Digital Kissan App'**
  String get appTitle;

  /// The tagline for the application
  ///
  /// In en, this message translates to:
  /// **'Smart Agriculture for Farmers'**
  String get appTagline;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Notifications setting label
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Location setting label
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @useDeviceLocation.
  ///
  /// In en, this message translates to:
  /// **'Use device location'**
  String get useDeviceLocation;

  /// No description provided for @allowLocationPermissions.
  ///
  /// In en, this message translates to:
  /// **'Allow location permissions to auto-detect'**
  String get allowLocationPermissions;

  /// No description provided for @searchEnterLocation.
  ///
  /// In en, this message translates to:
  /// **'Search / Enter location name'**
  String get searchEnterLocation;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @use.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get use;

  /// No description provided for @savedLocations.
  ///
  /// In en, this message translates to:
  /// **'Saved locations'**
  String get savedLocations;

  /// No description provided for @noSavedLocations.
  ///
  /// In en, this message translates to:
  /// **'No saved locations'**
  String get noSavedLocations;

  /// No description provided for @locationSaved.
  ///
  /// In en, this message translates to:
  /// **'Location saved'**
  String get locationSaved;

  /// Failed to get position message
  ///
  /// In en, this message translates to:
  /// **'Failed to get position'**
  String get failedToGetPosition;

  /// About app section
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutApp;

  /// Contact support option
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// Home navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Forecast navigation label
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get forecast;

  /// Alerts navigation label
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// Suggestions navigation label
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get suggestions;

  /// Welcome message on login screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to Digital Kissan'**
  String get welcomeMessage;

  /// Login screen description
  ///
  /// In en, this message translates to:
  /// **'Helping farmers with real-time weather alerts.'**
  String get loginDescription;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login with Phone Number'**
  String get loginButton;

  /// Guest login button text
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get guestButton;

  /// Language label on login screen
  ///
  /// In en, this message translates to:
  /// **'Language:'**
  String get languageLabel;

  /// Dashboard screen title
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Sunny weather condition
  ///
  /// In en, this message translates to:
  /// **'Sunny'**
  String get sunny;

  /// Rain alert message
  ///
  /// In en, this message translates to:
  /// **'Rain expected at 3 PM'**
  String get rainExpected;

  /// Precaution message
  ///
  /// In en, this message translates to:
  /// **'Take precautions to protect your crops.'**
  String get takePrecautions;

  /// Quick tips section title
  ///
  /// In en, this message translates to:
  /// **'Quick Tips'**
  String get quickTips;

  /// Pesticide tip
  ///
  /// In en, this message translates to:
  /// **'Avoid pesticide spraying today'**
  String get avoidPesticide;

  /// Irrigation tip
  ///
  /// In en, this message translates to:
  /// **'Irrigate fields tomorrow'**
  String get irrigateFields;

  /// Soil moisture tip
  ///
  /// In en, this message translates to:
  /// **'Check soil moisture'**
  String get checkSoilMoisture;

  /// No description provided for @irrigateFieldsReason.
  ///
  /// In en, this message translates to:
  /// **'Light irrigation now reduces heat stress and keeps topsoil moisture for seedling roots.'**
  String get irrigateFieldsReason;

  /// No description provided for @delayFertilizerReason.
  ///
  /// In en, this message translates to:
  /// **'Heavy rain can wash away nutrients; delay to avoid waste and patchy growth.'**
  String get delayFertilizerReason;

  /// No description provided for @harvestEarlyReason.
  ///
  /// In en, this message translates to:
  /// **'Expected rain can spoil standing crops; early harvest protects quality and price.'**
  String get harvestEarlyReason;

  /// No description provided for @checkSoilMoistureReason.
  ///
  /// In en, this message translates to:
  /// **'Measuring moisture prevents overwatering and reduces fungus risk.'**
  String get checkSoilMoistureReason;

  /// No description provided for @avoidPesticideReason.
  ///
  /// In en, this message translates to:
  /// **'Wind or rain can spread chemicals and reduce effectiveness; wait for calm, dry conditions.'**
  String get avoidPesticideReason;

  /// Forecast screen title
  ///
  /// In en, this message translates to:
  /// **'7-Day Forecast'**
  String get forecastTitle;

  /// High temperature label
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// Low temperature label
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// Alerts screen title
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// Rain alert type
  ///
  /// In en, this message translates to:
  /// **'Rain Alert'**
  String get rainAlert;

  /// Heatwave alert type
  ///
  /// In en, this message translates to:
  /// **'Heatwave Alert'**
  String get heatwaveAlert;

  /// Storm alert type
  ///
  /// In en, this message translates to:
  /// **'Storm Alert'**
  String get stormAlert;

  /// Heavy rain alert description
  ///
  /// In en, this message translates to:
  /// **'Heavy rain expected at 3 PM.'**
  String get heavyRainExpected;

  /// High temperature warning
  ///
  /// In en, this message translates to:
  /// **'High temperature warning.'**
  String get highTempWarning;

  /// Strong winds alert
  ///
  /// In en, this message translates to:
  /// **'Strong winds expected.'**
  String get strongWindsExpected;

  /// Date label
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Suggestions screen title
  ///
  /// In en, this message translates to:
  /// **'Farming Suggestions'**
  String get suggestionsTitle;

  /// Fertilizer suggestion
  ///
  /// In en, this message translates to:
  /// **'Delay fertilizer application'**
  String get delayFertilizer;

  /// Harvest suggestion
  ///
  /// In en, this message translates to:
  /// **'Harvest early due to rain'**
  String get harvestEarly;

  /// Error message when weather data fetching fails
  ///
  /// In en, this message translates to:
  /// **'Error fetching weather data'**
  String get errorFetchingWeather;

  /// Message when no weather data is available
  ///
  /// In en, this message translates to:
  /// **'No weather data available for this location'**
  String get noWeatherDataAvailable;

  /// Error message when forecast data fetching fails
  ///
  /// In en, this message translates to:
  /// **'Error fetching forecast data'**
  String get errorFetchingForecast;

  /// Message when no forecast data is available
  ///
  /// In en, this message translates to:
  /// **'No forecast data available for this location'**
  String get noForecastDataAvailable;

  /// Location permissions denied message
  ///
  /// In en, this message translates to:
  /// **'Location permissions are denied.'**
  String get locationPermissionsDenied;

  /// Location permissions permanently denied message
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied. Please enable them in app settings.'**
  String get locationPermissionsPermanentlyDenied;

  /// Settings button label in snackbar
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsButtonLabel;

  /// Location not found message
  ///
  /// In en, this message translates to:
  /// **'Location not found.'**
  String get locationNotFound;

  /// Failed to search for location message
  ///
  /// In en, this message translates to:
  /// **'Failed to search for location.'**
  String get failedToSearchLocation;

  /// Choose location option message
  ///
  /// In en, this message translates to:
  /// **'Choose a location option'**
  String get chooseLocationOption;

  /// Getting location message
  ///
  /// In en, this message translates to:
  /// **'Getting Location...'**
  String get gettingLocation;

  /// Use current GPS location button label
  ///
  /// In en, this message translates to:
  /// **'Use current GPS location'**
  String get useCurrentGpsLocation;

  /// Or enter your location manually message
  ///
  /// In en, this message translates to:
  /// **'Or enter your location manually'**
  String get orEnterLocationManually;

  /// Search or enter location hint text
  ///
  /// In en, this message translates to:
  /// **'Search or enter location'**
  String get searchOrEnterLocation;

  /// Or tap on the map to select message
  ///
  /// In en, this message translates to:
  /// **'Or tap on the map to select'**
  String get orTapOnMapToSelect;

  /// Current selected location label
  ///
  /// In en, this message translates to:
  /// **'Current selected location:'**
  String get currentSelectedLocation;

  /// No location selected yet message
  ///
  /// In en, this message translates to:
  /// **'No location selected yet'**
  String get noLocationSelectedYet;

  /// Coordinates label
  ///
  /// In en, this message translates to:
  /// **'Coordinates:'**
  String get coordinates;

  /// Could not get address for the location message
  ///
  /// In en, this message translates to:
  /// **'Could not get address for the location.'**
  String get couldNotGetAddress;

  /// Set/Update Location title
  ///
  /// In en, this message translates to:
  /// **'Set/Update Location'**
  String get setUpdateLocation;
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
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
