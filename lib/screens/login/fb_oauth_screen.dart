// lib/screens/login/fb_oauth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:giveaway_app/services/api_client.dart';

class FbOAuthScreen extends StatefulWidget {
  const FbOAuthScreen({super.key});

  @override
  State<FbOAuthScreen> createState() => _FbOAuthScreenState();
}

class _FbOAuthScreenState extends State<FbOAuthScreen> {
  String? _loginUrl;
  String? _redirectUri;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLoginUrl();
  }

  Future<void> _loadLoginUrl() async {
    try {
      await ApiClient().init();
      final dio = ApiClient().dio;

      final r = await dio.get('/api/fb/login_url');
      if (r.data is! Map) {
        throw StateError('fb/login_url malformed');
      }
      final url = (r.data as Map)['url'] as String?;
      if (url == null || url.isEmpty) {
        throw StateError('fb/login_url missing url');
      }

      final u = Uri.parse(url);
      final redirect = u.queryParameters['redirect_uri'] ??
          '${dio.options.baseUrl}/api/fb/callback';

      if (!mounted) return;
      setState(() {
        _loginUrl = url;
        _redirectUri = redirect;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _exchangeCode(String code) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final dio = ApiClient().dio;
      final redirectUri =
          _redirectUri ?? '${dio.options.baseUrl}/api/fb/callback';

      await dio.post(
        '/api/oauth/facebook/token',
        data: {'code': code, 'redirect_uri': redirectUri},
      );

      // швидка перевірка, що токен реально ліг у сесію
      await dio.get('/api/fb/_whoami');

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facebook OAuth')),
        body: Center(child: Text('OAuth init error: $_error')),
      );
    }

    if (_loginUrl == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Facebook OAuth')),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_loginUrl!)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
            ),
            shouldOverrideUrlLoading: (controller, action) async {
              final url = action.request.url?.toString() ?? '';
              final redirect = _redirectUri;

              if (redirect != null && url.startsWith(redirect)) {
                final uri = Uri.parse(url);
                final code = uri.queryParameters['code'];
                final hasError = uri.queryParameters['error'] != null;

                if (code != null && !hasError) {
                  await _exchangeCode(code);
                } else {
                  if (!context.mounted) return NavigationActionPolicy.CANCEL;
                  Navigator.of(context).pop(false);
                }
                return NavigationActionPolicy.CANCEL;
              }

              return NavigationActionPolicy.ALLOW;
            },
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
