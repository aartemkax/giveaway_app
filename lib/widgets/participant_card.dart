import 'package:flutter/material.dart';
import '../models/participant.dart';
import '../utils/constants.dart';

class ParticipantCard extends StatelessWidget {
  final Participant participant;
  const ParticipantCard(this.participant, {super.key});

  @override
  Widget build(BuildContext ctx) {
    final url =
        participant.profilePicUrl.startsWith('http')
            ? participant.profilePicUrl
            : '$apiBaseUrl${participant.profilePicUrl}';

    return Column(
      children: [
        CircleAvatar(radius: 50, backgroundImage: NetworkImage(url)),
        const SizedBox(height: 8),
        Text(
          participant.username,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
