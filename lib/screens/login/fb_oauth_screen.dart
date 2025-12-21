// lib/screens/login/fb_oauth_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:giveaway_app/services/api_client.dart';
import 'package:giveaway_app/utils/constants.dart';

class FbOAuthScreen extends StatefulWidget {
  const FbOAuthScreen({super.key});

  @override
  State<FbOAuthScreen> createState() => _FbOAuthScreenState();
}

class _FbOAuthScreenState extends State<FbOAuthScreen> {
  late final Dio _dio;
  String? _fbAuthUrl;
  bool _busy = false;

  // redirect_uri, який віддає бек у login_url
  String get _redirectPrefix => '$apiBaseUrl/api/fb/callback';

  @override
  void initState() {
    super.initState();
    _dio = ApiClient().dio;
    _loadAuthUrl();
  }

  Future<void> _loadAuthUrl() async {
    try {
      final r = await _dio.get('/api/fb/login_url');
      final url = (r.data as Map)['url'] as String?;
      if (!mounted) return;
      setState(() => _fbAuthUrl = url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _fbAuthUrl = null);
    }
  }

  Future<bool> _exchangeCode(String code) async {
    if (_busy) return false;
    _busy = true;
    try {
      await _dio.post(
        '/api/oauth/facebook/token',
        data: {'code': code, 'redirect_uri': _redirectPrefix},
      );

      // sanity-check: токен реально в сесії?
      final who = await _dio.get('/api/fb/_whoami');
      return who.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _fbAuthUrl;
    if (url == null) {
      return const Scaffold(
        body: Center(child: Text('FB OAuth URL not available')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Facebook OAuth')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
        shouldOverrideUrlLoading: (controller, action) async {
          final u = action.request.url?.toString() ?? '';

          if (u.startsWith(_redirectPrefix)) {
            final uri = Uri.parse(u);
            final code = uri.queryParameters['code'];
            final hasError = uri.queryParameters['error'] != null;

            if (code != null && !hasError) {
              final ok = await _exchangeCode(code);
              if (!context.mounted) return NavigationActionPolicy.CANCEL;
              Navigator.of(context).pop(ok);
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
