// lib/screens/password_login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/utils/api_exception.dart';
import 'package:giveaway_app/services/auth_service.dart';
import 'package:giveaway_app/services/device_service.dart';
import 'package:giveaway_app/utils/asset_paths.dart';

class PasswordLoginScreen extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;
  const PasswordLoginScreen({required this.onLocaleChanged, super.key});

  @override
  State<PasswordLoginScreen> createState() => _PasswordLoginScreenState();
}

class _PasswordLoginScreenState extends State<PasswordLoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text.trim();

    if (u.isEmpty || p.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.remind_enter_credentials)));
      return;
    }

    setState(() => _loading = true);

    Map<String, dynamic> raw = {};
    Map<String, dynamic> emu = {};
    try {
      raw = await DeviceService().collectFingerprint();
      emu = await DeviceService().emulateOnServer(raw);
    } catch (_) {
      // ігноруємо fingerprint-збій
    }

    try {
      await AuthService().login(u, p, deviceInfo: emu);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/participants');
    } on ApiException catch (e) {
      String msg;
      switch (e.code) {
        case 'invalid_credentials':
          msg = loc.error_invalid_credentials;
          break;
        case 'instagram_challenge':
        case 'suspicious_login':
          msg = loc.error_instagram_challenge;
          break;
        case 'internal_error':
          msg = loc.error_internal_error;
          break;
        default:
          msg = loc.error_generic(e.code);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                          AppLocalizations.supportedLocales.map((l) {
                        final label = l.languageCode == 'uk'
                            ? 'Українська'
                            : l.languageCode == 'fr'
                                ? 'Français'
                                : 'English';
                        return PopupMenuItem(value: l, child: Text(label));
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
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color.fromARGB(204, 255, 255, 255),
                    labelText: loc.password_label,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[700],
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
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
