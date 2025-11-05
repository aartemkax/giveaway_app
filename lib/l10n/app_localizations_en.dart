// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_name => 'Instagram Giveaway';

  @override
  String get home_title => 'Instagram Giveaway';

  @override
  String get login_button => 'Log in';

  @override
  String get login_title => 'Instagram Login';

  @override
  String get no_participants => 'No participants selected';

  @override
  String get ok_button => 'OK';

  @override
  String get password_label => 'Password';

  @override
  String get participants_title => 'Giveaway participants';

  @override
  String get post_url_label => 'Post URL';

  @override
  String get refresh_and_choose => 'Refresh & choose';

  @override
  String get remind_enter_credentials => 'Please enter username and password';

  @override
  String get username_label => 'Username';

  @override
  String get winners_count_label => 'Number of winners';

  @override
  String validation_length(Object minLogin, Object minPass) {
    return 'Login ≥ $minLogin chars, password ≥ $minPass chars';
  }

  @override
  String error_generic(Object error) {
    return 'Error: $error';
  }

  @override
  String get error_internal_error => 'Server error. Please try again later.';

  @override
  String get error_instagram_challenge =>
      'Additional Instagram verification required.';

  @override
  String get error_invalid_credentials => 'Invalid username or password.';

  @override
  String get error_invalid_post_url =>
      'Invalid post URL. Should look like https://www.instagram.com/p/ABC123/';

  @override
  String get error_login_required => 'Please log in first.';

  @override
  String get error_post_unavailable => 'Post not found or unavailable.';

  @override
  String get error_proxy_blocked => 'Your proxy is blocked.';

  @override
  String get error_rate_limited =>
      'Too many requests. Please wait a few minutes.';

  @override
  String get error_session_expired => 'Session expired. Please log in again.';

  @override
  String get error_validation_error =>
      'Username ≥ 3 chars, password ≥ 6 chars.';

  @override
  String get error_invalid_winner_count =>
      'Number of winners must be at least 1';

  @override
  String get error_unknown => 'Unknown error';

  @override
  String get error_instagram_submit_phone =>
      'Instagram requires you to add a phone number. Open Instagram to continue.';

  @override
  String get open_instagram_button => 'Open Instagram';
}
