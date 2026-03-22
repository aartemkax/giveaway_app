// Legacy stub screen: disabled Instagram web login placeholder.
// Not wired into the active route flow and not for new work.

import 'package:flutter/material.dart';

class InstagramLoginWebView extends StatelessWidget {
  const InstagramLoginWebView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instagram Web Login')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Цей сценарій вимкнено. Використовуй логін через username/password.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
