// lib/services/participants_service.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'package:giveaway_app/services/api_client.dart';
import '../models/participant.dart';
import '../utils/api_exception.dart';

class ParticipantsService {
  final Dio _dio = ApiClient().dio;

  Future<List<Participant>> fetchParticipants(
    String postUrl, {
    required BuildContext context,
  }) async {
    postUrl = postUrl.trim();
    if (postUrl.isNotEmpty && !postUrl.endsWith('/')) {
      postUrl = '$postUrl/';
    }

    try {
      // 1) старт джоби
      final start = await _dio.post(
        '/api/fetch_participants_async',
        data: {'post_url': postUrl},
      );

      if (start.statusCode != 202 || start.data is! Map) {
        throw ApiException('unknown_error',
            detail: 'unexpected start response');
      }

      final jobId = (start.data['job_id'] ?? '') as String;
      if (jobId.isEmpty) {
        throw ApiException('unknown_error', detail: 'empty job id');
      }

      // 2) полінг
      final statusPath = '/api/job_status/$jobId';
      const pollEvery = Duration(seconds: 2);
      const maxWait = Duration(seconds: 90);
      final sw = Stopwatch()..start();

      while (true) {
        await Future.delayed(pollEvery);
        final r = await _dio.get(statusPath);
        if (r.statusCode != 200 || r.data is! Map) {
          throw ApiException('unknown_error', detail: 'bad status response');
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

      // 3) результат
      final res = await _dio.get('/api/job_result/$jobId');

      if (res.statusCode == 200 && res.data is Map) {
        final raw = (res.data['participants']);
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map(Participant.fromJson)
              .toList();
        }
        return <Participant>[];
      }

      if (res.data is Map) {
        final m = res.data as Map;
        final code = (m['error'] as String?) ?? 'server_error';
        final detail = m['detail'] as String?;
        throw ApiException(code, detail: detail);
      }

      throw ApiException('server_error',
          detail: 'code ${res.statusCode}: unexpected result');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
