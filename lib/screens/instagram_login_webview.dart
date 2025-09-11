// lib/screens/instagram_login_webview.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import 'package:giveaway_app/services/api_client.dart';

class InstagramLoginWebView extends StatefulWidget {
  const InstagramLoginWebView({super.key});
  @override
  State<InstagramLoginWebView> createState() => _InstagramLoginWebViewState();
}

class _InstagramLoginWebViewState extends State<InstagramLoginWebView> {
  final WebUri _instaUri = WebUri('https://www.instagram.com/accounts/login/');
  InAppWebViewController? _ctl;
  bool _sent = false;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
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
              sharedCookiesEnabled: true, // важливо для iOS
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
                final ok = await _sendSessionIdToApi(sid);
                if (!mounted) return;
                Navigator.of(context).pop(ok);
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
        ],
      ),
    );
  }

  Future<bool> _sendSessionIdToApi(String sessionId) async {
    try {
      await ApiClient()
          .dio
          .post('/api/login_by_sessionid', data: {'sessionid': sessionId});
      return true;
    } on DioException {
      return false;
    }
  }
}
