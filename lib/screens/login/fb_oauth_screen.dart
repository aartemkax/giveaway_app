// lib/screens/login/fb_oauth_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:giveaway_app/services/fb/fb_auth_service.dart';
import 'package:giveaway_app/utils/api_exception.dart';

class FbOAuthScreen extends StatefulWidget {
  const FbOAuthScreen({super.key});

  @override
  State<FbOAuthScreen> createState() => _FbOAuthScreenState();
}

class _FbOAuthScreenState extends State<FbOAuthScreen> {
  bool _loading = false;
  String? _lastError;

  Future<void> _startFbLogin() async {
    setState(() {
      _loading = true;
      _lastError = null;
    });
    try {
      final url = await FbAuthService().getLoginUrl();
      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) {
        setState(() => _lastError = 'Не вдалося відкрити браузер');
      }
    } on ApiException catch (e) {
      setState(() => _lastError = e.detail ?? e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkStatus() async {
    setState(() {
      _loading = true;
      _lastError = null;
    });
    try {
      final me = await FbAuthService()
          .whoAmI(); // { ok:true, name:..., id:... } — як зробиш на беку
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('auth_method', 'fb');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/participants');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _lastError =
          e.detail ?? 'Потрібно завершити вхід у браузері та повернутися');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Facebook OAuth')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Крок 1. Відкрий вхід у Facebook/Instagram Graph у браузері та авторизуйся.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _startFbLogin,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Увійти через Facebook (офіційно)'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Крок 2. Повернись в апку і натисни "Перевірити статус".',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : _checkStatus,
                child: const Text('Перевірити статус'),
              ),
            ),
            if (_lastError != null) ...[
              const SizedBox(height: 12),
              Text(_lastError!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
