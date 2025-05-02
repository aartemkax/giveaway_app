// lib/services/api_service.dart

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

  if (resp.statusCode != 200) {
    throw Exception('Failed to fetch: ${resp.statusCode}');
  }
  final body = jsonDecode(resp.body) as Map<String, dynamic>;
  final list = body['participants'] as List<dynamic>;
  return list
      .map((j) => Participant.fromJson(j as Map<String, dynamic>))
      .toList();
}
