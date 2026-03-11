// lib/screens/login/app_login_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/utils/asset_paths.dart';
import 'package:giveaway_app/services/api_client.dart';

class AppLoginScreen extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;
  const AppLoginScreen({required this.onLocaleChanged, super.key});

  @override
  State<AppLoginScreen> createState() => _AppLoginScreenState();
}

class _AppLoginScreenState extends State<AppLoginScreen> {
  bool _loading = false;

  Future<bool> _pingAuthServer() async {
    try {
      await ApiClient().init();
      final r = await ApiClient().dio.get(
            '/healthz',
            options: Options(
              sendTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _serverHasFbSession() async {
    try {
      final r = await ApiClient().dio.get('/api/debug_session');
      final m = (r.data is Map) ? Map<String, dynamic>.from(r.data as Map) : {};
      return m['fb_user_token_present'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openFacebookOAuth({required bool switchAccount}) async {
    if (_loading) return;
    setState(() => _loading = true);

    final ok = await _pingAuthServer();
    if (!mounted) return;

    if (!ok) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сервер авторизації недоступний. Спробуйте пізніше'),
        ),
      );
      return;
    }

    // Якщо це НЕ switch account і серверна сесія вже є — не відкриваємо OAuth взагалі.
    if (!switchAccount) {
      final hasSession = await _serverHasFbSession();
      if (!mounted) return;

      if (hasSession) {
        setState(() => _loading = false);
        Navigator.of(context).pushReplacementNamed('/fb_home');
        return;
      }
    }

    final res = await Navigator.of(context).pushNamed(
      '/fb_oauth',
      arguments: {
        'prompt': switchAccount ? 'login' : '',
        'clearSession': switchAccount,
      },
    );

    if (!mounted) return;

    final fbOk = (res == true) && await _serverHasFbSession();
    setState(() => _loading = false);

    if (!fbOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FB OAuth не підтвердився на сервері. Повтори логін.'),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('auth_method', 'fb');

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/fb_home');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AssetPaths.loginBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    Text(
                      loc.login_title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PopupMenuButton<Locale>(
                      icon: const Icon(Icons.language, color: Colors.white),
                      onSelected: widget.onLocaleChanged,
                      itemBuilder: (_) =>
                          AppLocalizations.supportedLocales.map((locale) {
                        final label = locale.languageCode == 'uk'
                            ? 'Українська'
                            : locale.languageCode == 'fr'
                                ? 'Français'
                                : 'English';
                        return PopupMenuItem(value: locale, child: Text(label));
                      }).toList(),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () => _openFacebookOAuth(switchAccount: false),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text(
                      'Обрати переможця (офіційний API Facebook)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _openFacebookOAuth(switchAccount: true),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: Colors.white70),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Увійти через інший Facebook акаунт',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Підходить для публічних сторінок/постів',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Для приватних сторінок',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () =>
                            Navigator.of(context).pushNamed('/password_login'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: Colors.white70),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(loc.open_instagram_button),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
