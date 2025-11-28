// lib/utils/error_messages.dart
import 'package:flutter/widgets.dart';
import 'package:giveaway_app/l10n/app_localizations.dart';
import 'api_exception.dart';

String humanizeApiError(BuildContext context, ApiException e) {
  final t = AppLocalizations.of(context)!;

  if (e.status == 429) {
    if (e.code == 'rate_limited') {
      return t.error_rate_limited;
    }
    if (e.code == 'too_many_jobs') {
      final sec = (e.retryAfterSec ?? 60).clamp(0, 24 * 3600);
      final mm = (sec ~/ 60).toString().padLeft(2, '0');
      final ss = (sec % 60).toString().padLeft(2, '0');
      final active = e.active ?? 0;
      final limit = e.limit ?? 0;

      // Якщо немає t.error_too_many_jobs — даємо дефолтний текст тут
      return 'Ліміт черги вичерпано: активних $active із $limit. '
          'Спробуйте через $mm:$ss.';
    }
  }
  return t.error_generic(e.code);
}
