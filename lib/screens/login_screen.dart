// lib/screens/login_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:giveaway_app/utils/asset_paths.dart';
import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/utils/instagram_launcher.dart';
import '../utils/api_exception.dart';
import '../services/auth_service.dart';
import 'package:giveaway_app/services/device_service.dart';

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

  void _showInstagramDialog(AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.error_instagram_challenge),
        content: Text(loc.error_instagram_challenge),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(loc.ok_button),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              InstagramLauncher.openInstagram(
                deepLink: 'instagram://settings',
                fallbackUrl: 'https://www.instagram.com/accounts/edit/',
              );
            },
            child: Text(loc.open_instagram_button),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.remind_enter_credentials)));
      return;
    }
    if (username.length < 3 || password.length < 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.validation_length(3, 6))));
      return;
    }

    setState(() => _loading = true);
    Map<String, dynamic> raw = {};
    Map<String, dynamic> emu = {};
    try {
      raw = await DeviceService().collectFingerprint();
      debugPrint('🔎 raw deviceInfo: ${jsonEncode(raw)}');
      emu = await DeviceService().emulateOnServer(raw);
      debugPrint('🔎 emulated deviceInfo: ${jsonEncode(emu)}');
    } catch (e) {
      debugPrint('⚠️ Device emulation failed: $e');
    }

    try {
      await AuthService().login(username, password, deviceInfo: emu);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/participants');
    } on ApiException catch (e) {
      String text;
      bool showButton = false;
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
          showButton = e.detail == 'submit_phone';
          break;
        default:
          text = e.code == 'internal_error'
              ? loc.error_internal_error
              : loc.error_generic(e.code);
      }
      if (!mounted) return;
      if (e.code == 'instagram_challenge') {
        _showInstagramDialog(loc);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            action: showButton
                ? SnackBarAction(
                    label: loc.ok_button,
                    onPressed: () {
                      InstagramLauncher.openInstagram(
                        deepLink: 'instagram://settings',
                        fallbackUrl:
                            'https://www.instagram.com/accounts/security_and_login/',
                      );
                    },
                  )
                : null,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.error_internal_error)));
    } finally {
      if (mounted) setState(() => _loading = false);
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
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
