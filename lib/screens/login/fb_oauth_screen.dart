// lib/screens/login/fb_oauth_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FbOAuthScreen extends StatefulWidget {
  const FbOAuthScreen({super.key});

  @override
  State<FbOAuthScreen> createState() => _FbOAuthScreenState();
}

class _FbOAuthScreenState extends State<FbOAuthScreen> {
  late final Dio _dio;
  late final String _fbAuthUrl;

  @override
  void initState() {
    super.initState();

    _dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL']!,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    final clientId = dotenv.env['FB_CLIENT_ID']!; // додай у .env
    final redirect = 'giveaway://oauth'; // має бути в FB App
    final scope = 'public_profile,email,instagram_basic';
    final state = DateTime.now().millisecondsSinceEpoch.toString();

    _fbAuthUrl = 'https://www.facebook.com/v20.0/dialog/oauth'
        '?client_id=$clientId'
        '&redirect_uri=$redirect'
        '&response_type=code'
        '&state=$state'
        '&scope=$scope';
  }

  Future<void> _exchangeCode(String code) async {
    await _dio.post(
      '/oauth/facebook/token',
      data: {'code': code, 'redirect_uri': 'giveaway://oauth'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Facebook OAuth')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_fbAuthUrl)),
        // FIX: без `const`, бо конструктор не const у v6.x
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url?.toString() ?? '';
          if (url.startsWith('giveaway://oauth')) {
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
