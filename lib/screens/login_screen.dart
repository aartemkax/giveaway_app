// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/utils/asset_paths.dart';
import 'package:giveaway_app/screens/instagram_login_webview.dart';
import 'package:giveaway_app/services/api_client.dart'; // ⬅️ потрібен для /api/debug_session

class LoginScreen extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;
  const LoginScreen({required this.onLocaleChanged, super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<bool> _ensureBackendSession() async {
    try {
      final r = await ApiClient().dio.get('/api/debug_session');
      final data = r.data;
      if (data is Map) {
        return data['ig_settings_present'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _openInstagramWebLogin({bool retryIfNoSession = true}) async {
    if (_loading) return;
    setState(() => _loading = true);

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const InstagramLoginWebView()),
    );

    if (!mounted) {
      return;
    }

    if (ok == true) {
      final hasSession = await _ensureBackendSession();
      if (hasSession) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/participants');
      } else if (retryIfNoSession) {
        // тихо повторюємо один раз
        setState(() => _loading = false);
        await _openInstagramWebLogin(retryIfNoSession: false);
        return;
      } else {
        // опційно: повідомити про збій встановлення сесії
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.error_internal_error)),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
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
                    onPressed: _loading ? null : _openInstagramWebLogin,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
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
