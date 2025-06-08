// lib/widgets/async_avatar.dart

import 'package:flutter/material.dart';
// Імпортуємо AssetPaths
import 'package:giveaway_app/utils/asset_paths.dart';

class AsyncAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;

  const AsyncAvatar({
    required this.imageUrl,
    required this.size,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: FadeInImage.assetNetwork(
        // Використовуємо константу з AssetPaths
        placeholder: AssetPaths.placeholderAvatar,
        image: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
