// lib/screens/login/fb_oauth_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:giveaway_app/services/api_client.dart';

class FbOAuthScreen extends StatefulWidget {
  const FbOAuthScreen({super.key});

  @override
  State<FbOAuthScreen> createState() => _FbOAuthScreenState();
}

class _FbOAuthScreenState extends State<FbOAuthScreen> {
  late final Dio _dio;
  String? _fbAuthUrl;

  String get _redirectUri => dotenv.env['FB_REDIRECT_URI']!;

  @override
  void initState() {
    super.initState();

    // Використовуємо спільний Dio з cookie-jar
    _dio = ApiClient().dio;

    final clientId = dotenv.env['FB_CLIENT_ID'];
    if (clientId == null || clientId.isEmpty) {
      // Конфіг немає – краще кинути явну помилку, ніж ловити null.
      throw StateError('FB_CLIENT_ID не заданий у .env');
    }

    final state = DateTime.now().millisecondsSinceEpoch.toString();
    final scope = Uri.encodeComponent('public_profile,email,instagram_basic');

    _fbAuthUrl = 'https://www.facebook.com/v20.0/dialog/oauth'
        '?client_id=$clientId'
        '&redirect_uri=$_redirectUri'
        '&response_type=code'
        '&state=$state'
        '&scope=$scope';
  }

  Future<void> _exchangeCode(String code) async {
    await _dio.post(
      '/api/oauth/facebook/token',
      data: {'code': code, 'redirect_uri': _redirectUri},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Якщо зламаний конфіг і URL не зібрався
    if (_fbAuthUrl == null) {
      return const Scaffold(
        body: Center(
          child: Text('Facebook OAuth is not configured'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Facebook OAuth')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_fbAuthUrl!)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url?.toString() ?? '';

          // перехоплюємо редірект туди, що вказали як redirect_uri
          if (url.startsWith(_redirectUri)) {
            final uri = Uri.parse(url);
            final code = uri.queryParameters['code'];
            final hasError = uri.queryParameters['error'] != null;

            if (code != null && !hasError) {
              await _exchangeCode(code);
              if (!context.mounted) return NavigationActionPolicy.CANCEL;
              Navigator.of(context).pop(true);
            } else {
              if (!context.mounted) return NavigationActionPolicy.CANCEL;
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
