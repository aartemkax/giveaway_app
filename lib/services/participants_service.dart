import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/participant.dart';
import '../utils/constants.dart';

Future<List<Participant>> fetchParticipants(String postUrl) async {
  final uri = Uri.parse('$apiBaseUrl/api/fetch_participants');
  final resp = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'post_url': postUrl}),
  );
  if (resp.statusCode == 200) {
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['participants'] as List)
        .map((j) => Participant.fromJson(j))
        .toList();
  }
  final err = jsonDecode(resp.body)['error'] as String;
  switch (resp.statusCode) {
    case 400:
      throw Exception('Неправильний запит: $err');
    case 403:
      throw Exception('Доступ заборонено: $err');
    case 429:
      throw Exception('Забагато запитів: $err');
    default:
      throw Exception('Серверна помилка ${resp.statusCode}: $err');
  }
}
