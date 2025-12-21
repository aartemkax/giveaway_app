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
  String? _authUrl;
  String? _redirectUri;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAuthUrl();
  }

  Future<void> _loadAuthUrl() async {
    try {
      await ApiClient().init();
      final r = await ApiClient().dio.get('/api/fb/login_url');

      final data = (r.data is Map) ? (r.data as Map) : <String, dynamic>{};
      final url = data['url'] as String?;

      if (url == null || url.isEmpty) {
        throw StateError('fb login_url malformed');
      }

      final redirect = Uri.parse(url).queryParameters['redirect_uri'];
      if (redirect == null || redirect.isEmpty) {
        throw StateError('redirect_uri missing in fb login_url');
      }

      setState(() {
        _authUrl = url;
        _redirectUri = redirect;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _exchangeCode(String code) async {
    await ApiClient().dio.post(
      '/api/oauth/facebook/token',
      data: {'code': code, 'redirect_uri': _redirectUri},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _authUrl == null || _redirectUri == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facebook OAuth')),
        body: Center(child: Text(_error ?? 'Facebook OAuth not configured')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Facebook OAuth')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_authUrl!)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
        ),
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url?.toString() ?? '';

          // редірект на твій бек callback
          if (url.startsWith(_redirectUri!)) {
            final uri = Uri.parse(url);
            final code = uri.queryParameters['code'];
            final err = uri.queryParameters['error'];

            if (code != null && err == null) {
              try {
                await _exchangeCode(code);
                if (!context.mounted) return NavigationActionPolicy.CANCEL;
                Navigator.of(context).pop(true);
              } catch (_) {
                if (!context.mounted) return NavigationActionPolicy.CANCEL;
                Navigator.of(context).pop(false);
              }
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
