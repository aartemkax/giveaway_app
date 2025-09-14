// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get app_name => 'Instagram Giveaway';

  @override
  String get home_title => 'Instagram Giveaway';

  @override
  String get login_button => 'Увійти';

  @override
  String get login_title => 'Вхід в Instagram';

  @override
  String get no_participants => 'Немає обраних учасників';

  @override
  String get ok_button => 'ОК';

  @override
  String get password_label => 'Пароль';

  @override
  String get participants_title => 'Учасники Giveaway';

  @override
  String get post_url_label => 'Посилання на пост';

  @override
  String get refresh_and_choose => 'Оновити й обрати';

  @override
  String get remind_enter_credentials => 'Будь ласка, введіть логін і пароль';

  @override
  String get username_label => 'Логін';

  @override
  String get winners_count_label => 'Кількість переможців';

  @override
  String validation_length(Object minLogin, Object minPass) {
    return 'Логін ≥ $minLogin символів, пароль ≥ $minPass символів';
  }

  @override
  String error_generic(Object error) {
    return 'Помилка: $error';
  }

  @override
  String get error_internal_error =>
      'Помилка сервера. Спробуйте ще раз пізніше.';

  @override
  String get error_instagram_challenge =>
      'Потрібна додаткова верифікація в Instagram.';

  @override
  String get error_invalid_credentials => 'Неправильний логін або пароль.';

  @override
  String get error_invalid_post_url =>
      'Неправильне посилання на пост. Має вигляд https://www.instagram.com/p/ABC123/';

  @override
  String get error_login_required => 'Потрібно увійти в систему.';

  @override
  String get error_post_unavailable => 'Пост не знайдено або недоступний.';

  @override
  String get error_proxy_blocked => 'Ваш проксі заблоковано.';

  @override
  String get error_rate_limited => 'Забагато запитів. Зачекайте кілька хвилин.';

  @override
  String get error_session_expired => 'Сесія закінчилася. Увійдіть знову.';

  @override
  String get error_validation_error =>
      'Логін ≥ 3 символи, пароль ≥ 6 символів.';

  @override
  String get error_invalid_winner_count =>
      'Кількість переможців повинна бути не менше 1';

  @override
  String get error_unknown => 'Невідома помилка';

  @override
  String get error_instagram_submit_phone =>
      'Instagram вимагає додати номер телефону. Відкрийте Instagram, щоб продовжити.';

  @override
  String get open_instagram_button => 'Відкрити Instagram';
}
