//lib/screens/fb_home_screen.dart
import 'package:flutter/material.dart';

class FbHomeScreen extends StatelessWidget {
  const FbHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
            'FB OAuth OK. Далі треба флоу через /api/ig/* (accounts/media/comments).'),
      ),
    );
  }
}
