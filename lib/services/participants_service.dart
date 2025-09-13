// lib/services/participants_service.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'package:giveaway_app/services/api_client.dart';
import '../models/participant.dart';
import '../utils/api_exception.dart';

class ParticipantsService {
  final Dio _dio = ApiClient().dio;

  // Чітка перевірка посилання на пост
  static final RegExp _igPostRe = RegExp(
    r'^https?:\/\/(www\.)?instagram\.com\/p\/[^\/\s]+\/?$',
    caseSensitive: false,
  );

  bool _isValidPostUrl(String url) => _igPostRe.hasMatch(url.trim());

  Future<List<Participant>> fetchParticipants(
    String postUrl, {
    required BuildContext context,
  }) async {
    // 1) Клієнтська валідація
    postUrl = postUrl.trim();
    if (postUrl.isEmpty || !_isValidPostUrl(postUrl)) {
      throw ApiException('invalid_post_url');
    }
    if (!postUrl.endsWith('/')) postUrl = '$postUrl/';

    try {
      // 2) Старт джоби
      final start = await _dio.post(
        '/api/fetch_participants_async',
        data: {'post_url': postUrl},
      );

      // Нормальна відповідь — 202
      if (start.statusCode != 202 || start.data is! Map) {
        // Якщо бек дав зрозумілий error — віддай його
        if (start.data is Map && (start.data['error'] as String?) != null) {
          final code = start.data['error'] as String;
          final detail = start.data['detail'] as String?;
          throw ApiException(code, detail: detail);
        }
        throw ApiException('server_error', detail: 'unexpected start response');
      }

      final jobId = (start.data['job_id'] ?? '') as String;
      if (jobId.isEmpty) {
        throw ApiException('server_error', detail: 'empty job id');
      }

      // 3) Полінг статусу
      final statusPath = '/api/job_status/$jobId';
      const pollEvery = Duration(seconds: 2);
      const maxWait = Duration(seconds: 90);
      final sw = Stopwatch()..start();

      while (true) {
        await Future.delayed(pollEvery);
        final r = await _dio.get(statusPath);

        if (r.statusCode != 200 || r.data is! Map) {
          throw ApiException('server_error', detail: 'bad status response');
        }

        final status = (r.data['status'] as String?)?.toLowerCase() ?? '';
        if (status == 'finished') break;
        if (status == 'failed') {
          throw ApiException('internal_error', detail: 'job_failed');
        }
        if (sw.elapsed > maxWait) {
          throw ApiException('timeout', detail: 'job_status_timeout');
        }
      }

      // 4) Результат
      final res = await _dio.get('/api/job_result/$jobId');

      if (res.statusCode == 200 && res.data is Map) {
        final raw = res.data['participants'];
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map(Participant.fromJson)
              .toList();
        }
        return <Participant>[];
      }

      // Якщо бек віддав помилку структуровано — підніми її як ApiException
      if (res.data is Map && (res.data['error'] as String?) != null) {
        final code = res.data['error'] as String;
        final detail = res.data['detail'] as String?;
        throw ApiException(code, detail: detail);
      }

      throw ApiException('server_error',
          detail: 'code ${res.statusCode}: unexpected result');
    } on DioException catch (e) {
      // Мапінг 400 invalid_post_url з бекенду
      final r = e.response;
      if (r?.statusCode == 400 &&
          r?.data is Map &&
          (r!.data['error'] as String?) == 'invalid_post_url') {
        throw ApiException('invalid_post_url',
            detail: r.data['detail'] as String?);
      }
      throw ApiException.fromDio(e);
    }
  }
}
