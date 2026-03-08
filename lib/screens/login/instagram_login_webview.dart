// lib/screens/login/instagram_login_webview.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import 'package:giveaway_app/services/api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class InstagramLoginWebView extends StatefulWidget {
  const InstagramLoginWebView({super.key});
  @override
  State<InstagramLoginWebView> createState() => _InstagramLoginWebViewState();
}

class _InstagramLoginWebViewState extends State<InstagramLoginWebView> {
  final WebUri _instaUri = WebUri('https://www.instagram.com/accounts/login/');
  bool _canTryImport(WebUri? url) {
  final u = (url?.toString() ?? '').toLowerCase();

  if (u.isEmpty) return false;
  if (u.contains('/accounts/login')) return false;
  if (u.contains('/challenge/')) return false;
  if (u.contains('/checkpoint/')) return false;

  return u.startsWith('https://www.instagram.com/');
}

Future<void> _handleImportResult(bool ok, {String? message}) async {
  if (!mounted) return;

  if (message != null && message.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  await Future.delayed(const Duration(milliseconds: 100));
  if (!mounted) return;
  Navigator.of(context).pop(ok);
}
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instagram Login')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: _instaUri),
        initialSettings: InAppWebViewSettings(
          // <— без const
          javaScriptEnabled: true,
          thirdPartyCookiesEnabled: true,
          sharedCookiesEnabled: true,
        ),
        onReceivedError: (controller, request, error) async {
          if (request.isForMainFrame == true) {
            final uri = Uri.parse('https://www.instagram.com/accounts/login/');
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        onLoadStop: (controller, url) async {
  if (_sent) return;
  if (!_canTryImport(url)) return;

  final cookies = await CookieManager.instance()
      .getCookies(url: WebUri('https://www.instagram.com/'));

  String sid = '';
  String dsUserId = '';

  for (final c in cookies) {
    if (c.name == 'sessionid') {
      sid = c.value ?? '';
    }
    if (c.name == 'ds_user_id') {
      dsUserId = c.value ?? '';
    }
  }

  if (sid.isEmpty || dsUserId.isEmpty) {
    return;
  }

  _sent = true;

  final result = await _sendSessionIdToApi(sid);

  if (result.$1 == true) {
    await _handleImportResult(true);
    return;
  }

  await _handleImportResult(false, message: result.$2);
},
      ),
    );
  }

  Future<(bool, String?)> _sendSessionIdToApi(String sessionId) async {
  try {
    final sid = Uri.decodeComponent(sessionId.trim());

    await ApiClient().dio.post(
      '/api/login_by_sessionid',
      data: {'sessionid': sid},
    );

    return (true, null);
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;

    if (code == 412 && data is Map && data['error'] == 'instagram_challenge') {
      return (
        false,
        'Instagram відхилив цю сесію через challenge/checkpoint. Це не баг UI.'
      );
    }

    if (code == 401 && data is Map && data['error'] == 'invalid_sessionid') {
      return (
        false,
        'Сесія Instagram вже недійсна.'
      );
    }

    return (
      false,
      'Помилка імпорту сесії: ${e.message}'
    );
  } catch (e) {
    return (
      false,
      'Помилка імпорту сесії: $e'
    );
  }
}
}
