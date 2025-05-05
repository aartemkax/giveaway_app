import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/participant.dart';
import '../utils/constants.dart';

/// Надсилає POST на /api/fetch_participants і повертає список учасників.
Future<List<Participant>> fetchParticipants(String postUrl) async {
  final uri = Uri.parse('$apiBaseUrl/api/fetch_participants');
  final resp = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'post_url': postUrl}),
  );
  if (resp.statusCode != 200) {
    throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
  }
  final json = jsonDecode(resp.body) as Map<String, dynamic>;
  final list = json['participants'] as List<dynamic>;
  return list.map((e) => Participant.fromJson(e)).toList();
}
