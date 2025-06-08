// lib/utils/instagram_launcher.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InstagramLauncher {
  /// Спроба відкрити офіційний Instagram-додаток за схемою [deepLink].
  /// Якщо він не встановлений, відкриваємо [fallbackUrl] у браузері.
  static Future<void> openInstagram({
    required String deepLink,
    required String fallbackUrl,
  }) async {
    // Перетворюємо рядок у Uri
    final uriApp = Uri.parse(deepLink);
    final uriWeb = Uri.parse(fallbackUrl);

    // Перевіряємо, чи можемо відкрити URI-схему Instagram (deepLink)
    if (await canLaunchUrl(uriApp)) {
      // Відкриваємо Instagram-додаток:
      await launchUrl(uriApp, mode: LaunchMode.externalApplication);
    } else {
      // Якщо схема не розпізнана (додаток не встановлений), відкриваємо fallback у браузері
      if (await canLaunchUrl(uriWeb)) {
        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
      } else {
        // Якщо з якоїсь причини не запускається навіть веб-лінк — можна показати SnackBar або AlertDialog
        debugPrint('Не вдалося відкрити Instagram: $fallbackUrl');
      }
    }
  }
}
