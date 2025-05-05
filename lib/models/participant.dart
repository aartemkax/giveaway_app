import '../utils/constants.dart';

class Participant {
  final String username;
  final String profilePicUrl;

  Participant({required this.username, required this.profilePicUrl});

  factory Participant.fromJson(Map<String, dynamic> json) {
    final relativeUrl = json['profile_pic_url'] as String;
    final fullUrl =
        relativeUrl.startsWith('http')
            ? relativeUrl
            : '$apiBaseUrl$relativeUrl';
    return Participant(
      username: json['username'] as String,
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
