import 'dart:convert';
import 'package:http/http.dart' as http;

/// Модель одного учасника розіграшу
class Participant {
  final String username;
  final String profilePicUrl;

  Participant({required this.username, required this.profilePicUrl});

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      username: json['username'],
      profilePicUrl: json['profile_pic_url'],
    );
  }
}

/// Метод для отримання списку учасників по посиланню на пост
Future<List<Participant>> fetchParticipants(String postUrl) async {
  final response = await http.post(
    Uri.parse('http://127.0.0.1:5000/api/fetch_participants'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'post_url': postUrl}),
  );

  if (response.statusCode == 200) {
    final jsonBody = jsonDecode(response.body);
    final List<dynamic> participantsJson = jsonBody['participants'];

    return participantsJson
        .map((participant) => Participant.fromJson(participant))
        .toList();
  } else {
    throw Exception('Не вдалося завантажити учасників: ${response.statusCode}');
  }
}
