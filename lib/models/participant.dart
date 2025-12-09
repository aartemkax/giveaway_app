// lib/models/participant.dart

import '../utils/constants.dart';

class Participant {
  final String username;
  final String profilePicUrl;

  const Participant({
    required this.username,
    required this.profilePicUrl,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    final raw = (json['profile_pic_url'] as String?)?.trim() ?? '';

    final fullUrl = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : '$apiBaseUrl$raw';

    return Participant(
      username: (json['username'] as String?)?.trim() ?? '',
      profilePicUrl: fullUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Participant &&
          runtimeType == other.runtimeType &&
          username == other.username;

  @override
  int get hashCode => username.hashCode;
}
