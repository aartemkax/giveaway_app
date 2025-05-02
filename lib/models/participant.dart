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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Participant &&
          runtimeType == other.runtimeType &&
          username == other.username;

  @override
  int get hashCode => username.hashCode;
}
