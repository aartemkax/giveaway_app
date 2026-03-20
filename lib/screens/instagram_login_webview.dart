// lib/screens/instagram_login_webview.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import 'package:giveaway_app/services/appapi/app_auth_service.dart';
import 'package:giveaway_app/utils/api_exception.dart';

class InstagramLoginWebView extends StatefulWidget {
  final Map<String, dynamic>? deviceInfo;
  final String? instagramUsername;

  const InstagramLoginWebView({
    super.key,
    this.deviceInfo,
    this.instagramUsername,
  });
  @override
  State<InstagramLoginWebView> createState() => _InstagramLoginWebViewState();
}

class _InstagramLoginWebViewState extends State<InstagramLoginWebView> {
  final WebUri _instaUri = WebUri('https://www.instagram.com/accounts/login/');
  InAppWebViewController? _ctl;
  bool _sent = false;
  bool _failed = false;
  String? _apiError;

  String _sessionErrorText(Locale locale, String? code) {
    if (code == 'sessionid_challenge') {
      switch (locale.languageCode) {
        case 'uk':
          return 'Instagram не прийняв sessionid на сервері. Ймовірна причина: challenge або невідповідність IP/device context.';
        case 'fr':
          return 'Instagram a refuse le sessionid cote serveur. Cause probable: challenge ou mismatch IP/appareil.';
        default:
          return 'Instagram rejected the sessionid on the server. Likely cause: challenge or IP/device context mismatch.';
      }
    }
    if (code == 'invalid_sessionid') {
      switch (locale.languageCode) {
        case 'uk':
          return 'Sessionid невалідний або вже протух.';
        case 'fr':
          return 'Le sessionid est invalide ou expire.';
        default:
          return 'The sessionid is invalid or expired.';
      }
    }
    switch (locale.languageCode) {
      case 'uk':
        return 'Не вдалося увійти через sessionid.';
      case 'fr':
        return 'Connexion via sessionid impossible.';
      default:
        return 'Sessionid login failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Instagram Login')),
      body: Stack(
        children: [
          InAppWebView(
            onWebViewCreated: (c) => _ctl = c,
            initialUrlRequest: URLRequest(url: _instaUri),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              thirdPartyCookiesEnabled: true,
              sharedCookiesEnabled: true,
            ),
            onReceivedError: (controller, request, error) async {
              if (request.isForMainFrame == true) {
                setState(() => _failed = true);
              }
            },
            onLoadStop: (controller, url) async {
              final cookies = await CookieManager.instance()
                  .getCookies(url: WebUri('https://www.instagram.com/'));
              String sid = '';
              for (final c in cookies) {
                if (c.name == 'sessionid') {
                  sid = c.value ?? '';
                  break;
                }
              }
              if (!_sent && sid.isNotEmpty) {
                _sent = true;
                final code = await _sendSessionIdToApi(sid);
                if (!mounted) return;
                if (code == null) {
                  Navigator.of(context).pop(true);
                  return;
                }
                setState(() => _apiError = code);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_sessionErrorText(locale, code))),
                );
              }
            },
          ),
          if (_failed)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Не вдалося завантажити сторінку Instagram.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _failed = false);
                              _ctl?.loadUrl(
                                urlRequest: URLRequest(url: _instaUri),
                              );
                            },
                            child: const Text('Спробувати знову'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_apiError != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_sessionErrorText(locale, _apiError)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _sendSessionIdToApi(String sessionId) async {
    try {
      await AuthService().createAccountFromSessionId(
        sessionId,
        instagramUsername: widget.instagramUsername,
        deviceInfo: widget.deviceInfo,
      );
      return null;
    } on DioException catch (e) {
      return ApiException.fromDio(e).code;
    }
  }
}
