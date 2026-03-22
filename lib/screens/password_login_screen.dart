// Active screen: current Instagram username/password login flow.
// lib/screens/password_login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/utils/api_exception.dart';
import 'package:giveaway_app/services/appapi/app_auth_service.dart';
import 'package:giveaway_app/services/device_service.dart';
import 'package:giveaway_app/utils/asset_paths.dart';
import 'package:giveaway_app/screens/instagram_login_webview.dart';

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
  String? _challengeMessage;
  Map<String, dynamic>? _lastDeviceInfo;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _sessionFallbackText(Locale locale) {
    switch (locale.languageCode) {
      case 'uk':
        return 'Instagram просить додаткову перевірку. Використай вхід через sessionid у веб-переглядачі.';
      case 'fr':
        return 'Instagram demande une verification supplementaire. Utilisez la connexion via sessionid dans la vue web.';
      default:
        return 'Instagram requested additional verification. Use sessionid login in the web view.';
    }
  }

  String _sessionFallbackButton(Locale locale) {
    switch (locale.languageCode) {
      case 'uk':
        return 'Увійти через sessionid';
      case 'fr':
        return 'Se connecter via sessionid';
      default:
        return 'Login via sessionid';
    }
  }

  String _sessionFallbackFailed(Locale locale) {
    switch (locale.languageCode) {
      case 'uk':
        return 'Вхід через sessionid не вдався.';
      case 'fr':
        return 'La connexion via sessionid a echoue.';
      default:
        return 'Sessionid login failed.';
    }
  }

  Future<void> _openSessionLogin() async {
    final locale = Localizations.localeOf(context);
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InstagramLoginWebView(
          deviceInfo: _lastDeviceInfo,
          instagramUsername: _userCtrl.text.trim(),
        ),
      ),
    );

    if (!mounted) return;

    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/participants');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_sessionFallbackFailed(locale))),
    );
  }

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text.trim();

    if (u.isEmpty || p.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.remind_enter_credentials)));
      return;
    }

    setState(() {
      _loading = true;
      _challengeMessage = null;
    });

    Map<String, dynamic> raw = {};
    Map<String, dynamic> emu = {};
    try {
      raw = await DeviceService().collectFingerprint();
      emu = await DeviceService().emulateOnServer(raw);
      _lastDeviceInfo = emu;
    } catch (_) {
      // ignore fingerprint failure
    }

    try {
      await AuthService().login(u, p, deviceInfo: emu);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/participants');
    } on ApiException catch (e) {
      String msg;
      final needsSessionFallback = e.code == 'instagram_challenge' ||
          e.code == 'suspicious_login' ||
          e.code == 'invalid_credentials';

      switch (e.code) {
        case 'invalid_credentials':
          msg =
              '${loc.error_invalid_credentials} ${_sessionFallbackText(locale)}';
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

      if (needsSessionFallback) {
        setState(() => _challengeMessage = msg);
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
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
                if (_challengeMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(220, 255, 255, 255),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _challengeMessage!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_sessionFallbackText(locale)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _openSessionLogin,
                            icon: const Icon(Icons.open_in_browser),
                            label: Text(_sessionFallbackButton(locale)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
