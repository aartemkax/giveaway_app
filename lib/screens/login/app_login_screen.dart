// lib/screens/login/app_login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/utils/asset_paths.dart';
import 'package:giveaway_app/screens/login/instagram_login_webview.dart';

class AppLoginScreen extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;
  const AppLoginScreen({required this.onLocaleChanged, super.key});

  @override
  State<AppLoginScreen> createState() => _AppLoginScreenState();
}

class _AppLoginScreenState extends State<AppLoginScreen> {
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
      await prefs.setString('auth_method', 'custom');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/participants');
    }
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

                // 1) Офіційний API FB (через окремий екран /fb_oauth)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.of(context).pushNamed('/fb_oauth');
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text(
                      'Обрати переможця (офіційний API Facebook)',
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

                // 2) Для приватних сторінок — кастомний вхід
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Для приватних сторінок',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _openInstagramWebLogin,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: Colors.white70),
                      foregroundColor: Colors.white,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(loc.open_instagram_button),
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
