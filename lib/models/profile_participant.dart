// lib/models/profile_participant.dart
class ProfileParticipant {
  final String username;
  final String profilePicUrl;

  ProfileParticipant({required this.username, required this.profilePicUrl});

  factory ProfileParticipant.fromJson(Map<String, dynamic> j, String baseUrl) {
    final rel = (j['profile_pic_url'] ?? '').toString();
    final full = rel.startsWith('http') ? rel : '$baseUrl$rel';
    return ProfileParticipant(username: j['username'], profilePicUrl: full);
  }
}
