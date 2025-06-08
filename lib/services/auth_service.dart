// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/browser_client.dart';
import 'package:http/http.dart'; // для Response
import '../utils/constants.dart';
import '../utils/api_exception.dart';
import 'dart:developer' as developer;

/// Виняток для випадків додаткової верифікації Instagram
class InstagramChallengeException implements Exception {
  final String message;
  InstagramChallengeException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  // BrowserClient із включеними кукі
  final BrowserClient _client = BrowserClient()..withCredentials = true;

  /// Логіниться на бекенд.
  /// Викидає:
  ///  • InstagramChallengeException — якщо потрібна дод. верифікація
  ///  • ApiException(code, detail) — у всіх інших випадках
  Future<void> login(String username, String password) async {
    final uri = loginUri;
    final Response resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'password': password.trim(),
      }),
    );

    // успіх
    if (resp.statusCode == 200) {
      // *** DEBUG: перевіряємо, чи сесія збережена на сервері ***
      final debugResp =
          await _client.get(Uri.parse('\$apiBaseUrl/api/debug_session'));
      developer.log('DEBUG SESSION after login: \${debugResp.body}');
      return;
    }

    // розбираємо тіло помилки
    String error = 'unknown_error';
    String message = 'Невідома помилка';
    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      error = data['error'] ?? error;
      message = data['message'] ?? message;
    } catch (_) {}

    if (resp.statusCode == 401 && error == 'invalid_credentials') {
      throw ApiException('invalid_credentials', detail: message);
    }
    if (resp.statusCode == 412 && error == 'instagram_challenge') {
      throw InstagramChallengeException(message);
    }
    // усе інше
    throw ApiException(error, detail: message);
  }

  /// Отримати список учасників по URL посту.
  /// Викидає:
  ///  • InstagramChallengeException — якщо challenge
  ///  • ApiException(code, detail) — у всіх інших випадках
  Future<List<Map<String, String>>> fetchParticipants(String postUrl) async {
    final uri = loginUri;
    final Response resp = await _client.post(
      uri,
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

    // розбираємо тіло помилки
    String error = 'unknown_error';
    String message = 'Невідома помилка';
    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      error = data['error'] ?? error;
      message = data['message'] ?? message;
    } catch (_) {}

    if (resp.statusCode == 401 && error == 'login_required') {
      throw ApiException('login_required', detail: message);
    }
    if (resp.statusCode == 412 && error == 'instagram_challenge') {
      throw InstagramChallengeException(message);
    }
    if (resp.statusCode == 400) {
      throw ApiException('invalid_post_url', detail: message);
    }

    throw ApiException('server_error',
        detail: 'Код \${resp.statusCode}: \$message');
  }
}
