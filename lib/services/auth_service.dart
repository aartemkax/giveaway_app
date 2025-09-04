// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart';
import 'package:giveaway_app/services/device_service.dart';
import 'package:giveaway_app/utils/constants.dart';
import 'package:giveaway_app/utils/api_exception.dart';
import 'package:giveaway_app/utils/device_info_util.dart';
import 'dart:developer' as developer;

/// Виняток на випадок, коли Instagram вимагає challenge
class InstagramChallengeException implements Exception {
  final String message;
  InstagramChallengeException(this.message);
  @override
  String toString() => 'InstagramChallengeException: \$message';
}

class AuthService {
  final BrowserClient _client = BrowserClient()..withCredentials = true;
  final DeviceService _deviceWeb = DeviceService();

  /// Логіниться на бекенд, передаючи готовий fingerprint або збираючи, якщо не передано
  Future<void> login(
    String username,
    String password, {
    Map<String, dynamic>? deviceInfo,
    BuildContext? context,
  }) async {
    Map<String, dynamic> info = deviceInfo ?? {};

    // Якщо fingerprint не передано, збираємо
    if (info.isEmpty) {
      if (kIsWeb) {
        info = await _deviceWeb.collectFingerprint();
      } else {
        info = await DeviceInfoUtil.collect(context: context);
      }
    }
    developer.log('🔎 deviceInfo: ${jsonEncode(info)}');

    final body = jsonEncode({
      'username': username.trim(),
      'password': password.trim(),
      'deviceInfo': info,
    });

    final resp = await _client.post(
      loginUri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (resp.statusCode == 200) {
      await _client.get(debugSessionUri);
      return;
    }

    String error = 'unknown_error';
    String detail = 'Невідома помилка';
    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      error = data['error'] ?? error;
      detail = data['detail'] ?? data['message'] ?? detail;
    } catch (_) {}

    if (resp.statusCode == 401 && error == 'invalid_credentials') {
      throw ApiException('invalid_credentials', detail: detail);
    }
    if (resp.statusCode == 412 && error == 'instagram_challenge') {
      throw InstagramChallengeException(detail);
    }
    throw ApiException(error, detail: detail);
  }

  /// Відправка challenge-коду (email або sms)
  Future<void> sendChallengeCode({required String method}) async {
    final uri = Uri.parse('\$apiBaseUrl/api/challenge/send');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'method': method}),
    );
    if (resp.statusCode != 200) {
      throw ApiException('challenge_send_failed',
          detail: 'Failed to send challenge code');
    }
  }

  /// Перевірка challenge-коду, введеного користувачем
  Future<void> verifyChallengeCode(String code) async {
    final uri = Uri.parse('\$apiBaseUrl/api/challenge/verify');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    if (resp.statusCode != 200) {
      throw ApiException('challenge_verify_failed',
          detail: 'Invalid challenge code');
    }
  }

  /// Асинхронно збирає учасників
  Future<List<Map<String, String>>> fetchParticipants(String postUrl) async {
    final resp = await _client.post(
      fetchParticipantsAsyncUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'post_url': postUrl.trim()}),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return List<Map<String, String>>.from(
        (data['participants'] as List)
            .map((e) => Map<String, String>.from(e as Map)),
      );
    }

    String error = 'unknown_error';
    String detail = 'Невідома помилка';
    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      error = data['error'] ?? error;
      detail = data['detail'] ?? data['message'] ?? detail;
    } catch (_) {}

    if (resp.statusCode == 401 && error == 'login_required') {
      throw ApiException('login_required', detail: detail);
    }
    if (resp.statusCode == 412 && error == 'instagram_challenge') {
      throw InstagramChallengeException(detail);
    }
    if (resp.statusCode == 400 && error == 'invalid_post_url') {
      throw ApiException('invalid_post_url', detail: detail);
    }

    throw ApiException('server_error',
        detail: 'Код \${resp.statusCode}: \$detail');
  }
}
