// lib/screens/login_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/utils/asset_paths.dart';
import 'package:giveaway_app/utils/api_exception.dart';
import 'package:giveaway_app/services/auth_service.dart';
import 'package:giveaway_app/services/device_service.dart';
import 'package:giveaway_app/screens/instagram_login_webview.dart';

class LoginScreen extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;
  const LoginScreen({
    required this.onLocaleChanged,
    super.key,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Веб-логін Instagram у вбудованому WebView.
  /// Після успіху ставимо локальний прапорець і переходимо далі.
  Future<void> _openInstagramWebLogin() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const InstagramLoginWebView()),
    );
    if (!mounted) return;
    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/participants');
    }
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.remind_enter_credentials)));
      return;
    }
    if (username.length < 3 || password.length < 6) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.validation_length(3, 6))));
      return;
    }

    setState(() => _loading = true);

    Map<String, dynamic> raw = {};
    Map<String, dynamic> emu = {};
    try {
      raw = await DeviceService().collectFingerprint();
      debugPrint('raw deviceInfo: ${jsonEncode(raw)}');
      emu = await DeviceService().emulateOnServer(raw);
      debugPrint('emulated deviceInfo: ${jsonEncode(emu)}');
    } catch (e) {
      debugPrint('Device emulation failed: $e');
    }

    try {
      await AuthService().login(username, password, deviceInfo: emu);

      // успішно: зберігаємо локальний стан і переходимо
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/participants');
    } on ApiException catch (e) {
      String text;
      bool openWebFlow = false;

      switch (e.code) {
        case 'validation_error':
          text = loc.error_validation_error;
          break;
        case 'invalid_credentials':
          text = loc.error_invalid_credentials;
          break;
        case 'instagram_challenge':
          text = e.detail == 'submit_phone'
              ? loc.error_instagram_submit_phone
              : loc.error_instagram_challenge;
          openWebFlow = true;
          break;
        case 'suspicious_login':
          text = loc.error_instagram_challenge;
          openWebFlow = true;
          break;
        default:
          text = e.code == 'internal_error'
              ? loc.error_internal_error
              : loc.error_generic(e.code);
      }

      if (!mounted) return;

      if (openWebFlow) {
        await _openInstagramWebLogin();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.error_internal_error)));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
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
                        return PopupMenuItem(
                          value: locale,
                          child: Text(label),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _userCtrl,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color.fromARGB(204, 255, 255, 255),
                    labelText: loc.username_label,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color.fromARGB(204, 255, 255, 255),
                    labelText: loc.password_label,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey[700],
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(loc.login_button),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : _openInstagramWebLogin,
                  child: Text(loc.open_instagram_button),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
