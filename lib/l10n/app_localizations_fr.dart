// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get app_name => 'Tirage Instagram';

  @override
  String get home_title => 'Tirage Instagram';

  @override
  String get login_button => 'Se connecter';

  @override
  String get login_title => 'Connexion Instagram';

  @override
  String get no_participants => 'Aucun participant sélectionné';

  @override
  String get ok_button => 'OK';

  @override
  String get password_label => 'Mot de passe';

  @override
  String get participants_title => 'Participants au tirage';

  @override
  String get post_url_label => 'URL du post';

  @override
  String get refresh_and_choose => 'Actualiser et choisir';

  @override
  String get remind_enter_credentials =>
      'Veuillez entrer nom d\'utilisateur et mot de passe';

  @override
  String get username_label => 'Nom d\'utilisateur';

  @override
  String get winners_count_label => 'Nombre de gagnants';

  @override
  String validation_length(Object minLogin, Object minPass) {
    return 'Nom d\'utilisateur ≥ $minLogin caractères, mot de passe ≥ $minPass caractères';
  }

  @override
  String error_generic(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get error_internal_error =>
      'Erreur du serveur. Veuillez réessayer plus tard.';

  @override
  String get error_instagram_challenge =>
      'Une vérification supplémentaire Instagram est requise.';

  @override
  String get error_invalid_credentials =>
      'Nom d\'utilisateur ou mot de passe invalide.';

  @override
  String get error_invalid_post_url =>
      'URL du post invalide. Format attendu : https://www.instagram.com/p/ABC123/';

  @override
  String get error_login_required => 'Veuillez vous connecter d\'abord.';

  @override
  String get error_post_unavailable => 'Post introuvable ou indisponible.';

  @override
  String get error_proxy_blocked => 'Votre proxy est bloqué.';

  @override
  String get too_many_jobs => 'Too many requests. Please wait a few minutes.';

  @override
  String get error_session_expired =>
      'Session expirée. Veuillez vous reconnecter.';

  @override
  String get error_validation_error =>
      'Nom d\'utilisateur ≥ 3 caractères, mot de passe ≥ 6 caractères.';

  @override
  String get error_invalid_winner_count =>
      'Le nombre de gagnants doit être au moins 1';

  @override
  String get error_unknown => 'Erreur inconnue';

  @override
  String get error_instagram_submit_phone =>
      'Instagram vous demande d’ajouter un numéro de téléphone. Ouvrez Instagram pour continuer.';

  @override
  String get open_instagram_button => 'Ouvrir Instagram';
}
