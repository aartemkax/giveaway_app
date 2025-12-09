import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_uk.dart';

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
    Locale('fr'),
    Locale('uk'),
  ];

  /// System app name (task switcher, web tab)
  ///
  /// In en, this message translates to:
  /// **'Instagram Giveaway'**
  String get app_name;

  /// AppBar title on home screen
  ///
  /// In en, this message translates to:
  /// **'Instagram Giveaway'**
  String get home_title;

  /// Text on the login button
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login_button;

  /// AppBar title on login screen
  ///
  /// In en, this message translates to:
  /// **'Instagram Login'**
  String get login_title;

  /// Shown when there are no selected participants
  ///
  /// In en, this message translates to:
  /// **'No participants selected'**
  String get no_participants;

  /// Text on confirmation button
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok_button;

  /// Label for password TextField
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password_label;

  /// AppBar title on participants screen
  ///
  /// In en, this message translates to:
  /// **'Giveaway participants'**
  String get participants_title;

  /// Label for the post URL text field
  ///
  /// In en, this message translates to:
  /// **'Post URL'**
  String get post_url_label;

  /// Button to refresh participants and pick winners
  ///
  /// In en, this message translates to:
  /// **'Refresh & choose'**
  String get refresh_and_choose;

  /// Shown when username/password fields are empty
  ///
  /// In en, this message translates to:
  /// **'Please enter username and password'**
  String get remind_enter_credentials;

  /// Label for username TextField
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username_label;

  /// Label for the number-of-winners text field
  ///
  /// In en, this message translates to:
  /// **'Number of winners'**
  String get winners_count_label;

  /// Shown when username/password too short
  ///
  /// In en, this message translates to:
  /// **'Login ≥ {minLogin} chars, password ≥ {minPass} chars'**
  String validation_length(Object minLogin, Object minPass);

  /// Generic error fallback when no other match
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error_generic(Object error);

  /// Unexpected server errors (HTTP 500)
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get error_internal_error;

  /// Backend returns instagram_challenge (HTTP 412)
  ///
  /// In en, this message translates to:
  /// **'Additional Instagram verification required.'**
  String get error_instagram_challenge;

  /// Backend returns invalid_credentials (HTTP 401)
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password.'**
  String get error_invalid_credentials;

  /// Malformed post_url (HTTP 400)
  ///
  /// In en, this message translates to:
  /// **'Invalid post URL. Should look like https://www.instagram.com/p/ABC123/'**
  String get error_invalid_post_url;

  /// Backend returns login_required (HTTP 401)
  ///
  /// In en, this message translates to:
  /// **'Please log in first.'**
  String get error_login_required;

  /// media_pk_from_url fails / post missing (HTTP 400)
  ///
  /// In en, this message translates to:
  /// **'Post not found or unavailable.'**
  String get error_post_unavailable;

  /// Backend returns proxy_blocked (HTTP 403)
  ///
  /// In en, this message translates to:
  /// **'Your proxy is blocked.'**
  String get error_proxy_blocked;

  /// Instagram rate-limit hit (HTTP 429)
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a few minutes.'**
  String get error_rate_limited;

  /// detail == "session_expired" (HTTP 401)
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please log in again.'**
  String get error_session_expired;

  /// Backend returns validation_error (HTTP 400)
  ///
  /// In en, this message translates to:
  /// **'Username ≥ 3 chars, password ≥ 6 chars.'**
  String get error_validation_error;

  /// User sets winners to 0 or negative
  ///
  /// In en, this message translates to:
  /// **'Number of winners must be at least 1'**
  String get error_invalid_winner_count;

  /// Fallback when backend returns something unrecognized
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get error_unknown;

  /// detail == "submit_phone"
  ///
  /// In en, this message translates to:
  /// **'Instagram requires you to add a phone number. Open Instagram to continue.'**
  String get error_instagram_submit_phone;

  /// Button that launches Instagram or fallback URL
  ///
  /// In en, this message translates to:
  /// **'Open Instagram'**
  String get open_instagram_button;
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
      <String>['en', 'fr', 'uk'].contains(locale.languageCode);

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
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
