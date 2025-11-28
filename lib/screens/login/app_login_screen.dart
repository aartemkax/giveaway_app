// lib/screens/login/app_login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/utils/asset_paths.dart';
import 'package:giveaway_app/screens/login/instagram_login_webview.dart';
import 'package:giveaway_app/screens/password_login_screen.dart';
import 'package:giveaway_app/screens/login/fb_oauth_screen.dart'; // ← ДОДАНО

class LoginScreen extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;
  const LoginScreen({required this.onLocaleChanged, super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _openInstagramWebLogin() async {
    if (_loading) return;
    setState(() => _loading = true);

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const InstagramLoginWebView()),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('auth_method', 'custom'); // ← фіксуємо канал
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/participants');
    }
  }

  void _openFbOAuth() {
    if (_loading) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FbOAuthScreen()));
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

                // 1) Офіційний вхід через Facebook/IG Graph
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openFbOAuth,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child:
                        const Text('Обрати переможця (офіційний API Facebook)'),
                  ),
                ),

                const SizedBox(height: 8),

                // Примітка для альтернативного каналу
                const Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Для приватних сторінок',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),

                const SizedBox(height: 8),

                // 2) Альтернативний спосіб: через Instagram sessionid (твій існуючий)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _openInstagramWebLogin,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Open Instagram'),
                  ),
                ),

                const SizedBox(height: 8),

                // Додатково: парольний логін (опційно)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PasswordLoginScreen(
                                onLocaleChanged: widget.onLocaleChanged,
                              ),
                            ),
                          );
                        },
                  child: const Text('Інші способи'),
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
