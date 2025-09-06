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
  final WebUri _instaUri = WebUri("https://www.instagram.com/accounts/login/");
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instagram Login')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: _instaUri),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          thirdPartyCookiesEnabled: true,
          sharedCookiesEnabled: true,
        ),
        onLoadStop: (controller, url) async {
          final cookies = await CookieManager.instance().getCookies(
            url: WebUri("https://www.instagram.com/"),
          );
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
