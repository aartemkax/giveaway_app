// lib/services/participants_service.dart

import 'dart:convert';
import 'package:http/browser_client.dart';
import '../models/participant.dart';
import '../utils/constants.dart';
import '../utils/api_exception.dart';

// BrowserClient з включеними кукі
final _webClient = BrowserClient()..withCredentials = true;

Future<List<Participant>> fetchParticipants(String postUrl) async {
  final uri =
      fetchUri; // має бути типу Uri.parse("http://localhost:5000/api/fetch_participants")
  final resp = await _webClient.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'post_url': postUrl.trim()}),
  );

  if (resp.statusCode == 200) {
    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    // Якщо ключ "participants" не містить List — повертаємо порожній список
    if (data['participants'] is! List) {
      return <Participant>[];
    }

    // Отримаємо сирий список і відфільтруємо лише Map<String, dynamic>
    final rawList = (data['participants'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (rawList.isEmpty) {
      return <Participant>[];
    }

    // Конвертуємо в Participant
    return rawList.map(Participant.fromJson).toList();
  }

  // Обробка помилкових статусів
  String code = 'unknown_error';
  String message = 'Невідома помилка';

  try {
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    code = data['error'] as String? ?? code;
    message = data['message'] as String? ?? message;
  } catch (_) {
    // Якщо тіло не JSON — лишаємо дефолтні code/message
  }

  switch (resp.statusCode) {
    case 400:
      if (code == 'post_unavailable') {
        throw ApiException('post_unavailable', detail: message);
      }
      throw ApiException('invalid_post_url', detail: message);

    case 401:
      throw ApiException('login_required', detail: message);

    case 403:
      throw ApiException('proxy_blocked', detail: message);

    case 429:
      throw ApiException('rate_limited', detail: message);

    case 412:
      throw ApiException(code, detail: message);

    default:
      if (code == 'unknown_error') {
        throw ApiException('unknown_error', detail: message);
      } else {
        throw ApiException(code, detail: message);
      }
  }
}
