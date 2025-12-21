// lib/screens/login/fb_oauth_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/services/api_client.dart';

class FbOAuthScreen extends StatefulWidget {
  const FbOAuthScreen({super.key});

  @override
  State<FbOAuthScreen> createState() => _FbOAuthScreenState();
}

class _FbOAuthScreenState extends State<FbOAuthScreen> {
  final Dio _dio = ApiClient().dio;

  String? _authUrl;
  String? _error;

  bool _exchanging = false;

  String get _redirectUri => (dotenv.env['FB_REDIRECT_URI'] ?? '').trim();

  @override
  void initState() {
    super.initState();
    _loadAuthUrl();
  }

  Future<void> _loadAuthUrl() async {
    try {
      if (_redirectUri.isEmpty) {
        throw StateError('FB_REDIRECT_URI не заданий у .env');
      }

      final r = await _dio.get('/api/fb/login_url');

      final data = r.data;
      final url = (data is Map) ? data['url'] : null;

      if (url is! String || url.trim().isEmpty) {
        throw StateError('Backend повернув некоректний login_url');
      }

      if (!mounted) return;
      setState(() {
        _authUrl = url.trim();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _exchangeCode(String code) async {
    await _dio.post(
      '/api/oauth/facebook/token',
      data: {'code': code, 'redirect_uri': _redirectUri},
    );

    // Фіксуємо “логін” локально, щоб initialRouteProvider не скидав на логін після restart/reconnect
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facebook OAuth')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!),
          ),
        ),
      );
    }

    if (_authUrl == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facebook OAuth')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Facebook OAuth')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_authUrl!)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
          thirdPartyCookiesEnabled: true,
          sharedCookiesEnabled: true,
        ),
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url?.toString() ?? '';

          // Перехоплюємо редірект на redirect_uri і забираємо code
          if (_redirectUri.isNotEmpty && url.startsWith(_redirectUri)) {
            // Захист від подвійного спрацювання (WebView може викликати кілька разів)
            if (_exchanging) return NavigationActionPolicy.CANCEL;
            _exchanging = true;

            final uri = Uri.parse(url);
            final code = uri.queryParameters['code'];
            final err = uri.queryParameters['error'];

            try {
              if (code != null && err == null) {
                await _exchangeCode(code);
                if (!context.mounted) return NavigationActionPolicy.CANCEL;
                Navigator.of(context).pop(true);
              } else {
                if (!context.mounted) return NavigationActionPolicy.CANCEL;
                Navigator.of(context).pop(false);
              }
            } catch (e) {
              if (!context.mounted) return NavigationActionPolicy.CANCEL;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('OAuth exchange failed: $e')),
              );
              Navigator.of(context).pop(false);
            }

            return NavigationActionPolicy.CANCEL;
          }

          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
