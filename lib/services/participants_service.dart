// lib/services/participants_service.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'package:giveaway_app/services/api_client.dart';
import '../models/participant.dart';
import '../utils/api_exception.dart';

class ParticipantsService {
  final Dio _dio = ApiClient().dio;

  static final RegExp _igPostRe = RegExp(
    r'^https?:\/\/(www\.)?instagram\.com\/p\/[^\/\s]+\/?$',
    caseSensitive: false,
  );
  bool _isValidPostUrl(String url) => _igPostRe.hasMatch(url.trim());

  int _retryAfterSeconds(Response r, dynamic body) {
    final h = r.headers.value('retry-after');
    final hv = h == null ? null : int.tryParse(h.trim());
    if (hv != null && hv >= 0) return hv;
    if (body is Map && body['retryAfter'] is int)
      return body['retryAfter'] as int;
    return 3600; // фолбек під RQ_DEFAULT_RESULT_TTL
  }

  Future<List<Participant>> fetchParticipants(
    String postUrl, {
    required BuildContext context,
  }) async {
    postUrl = postUrl.trim();
    if (postUrl.isEmpty || !_isValidPostUrl(postUrl)) {
      throw ApiException('invalid_post_url');
    }
    if (!postUrl.endsWith('/')) postUrl = '$postUrl/';

    try {
      // 1) Старт джоби
      final start = await _dio.post(
        '/api/fetch_participants_async',
        data: {'post_url': postUrl},
      );

      // Явна обробка 429 від бекенду (обмеження черги або IG-rate-limit)
      if (start.statusCode == 429) {
        final body = start.data is Map
            ? (start.data as Map).cast<String, dynamic>()
            : null;
        final code = (body?['error'] as String?) ??
            'too_many_jobs'; // дефолт — ліміт черги
        final ra = _retryAfterSeconds(start, body);
        final det = body?['detail'] as String?;
        throw ApiException(code, detail: det, status: 429, retryAfterSec: ra);
      }

      if (start.statusCode != 202 || start.data is! Map) {
        if (start.data is Map && (start.data['error'] as String?) != null) {
          final code = start.data['error'] as String;
          final detail = start.data['detail'] as String?;
          throw ApiException(code, detail: detail, status: start.statusCode);
        }
        throw ApiException('server_error',
            detail: 'unexpected start response', status: start.statusCode);
      }

      final jobId = (start.data['job_id'] ?? '') as String;
      if (jobId.isEmpty) {
        throw ApiException('server_error', detail: 'empty job id');
      }

      // 2) Полінг статусу
      final statusPath = '/api/job_status/$jobId';
      const pollEvery = Duration(seconds: 2);
      const maxWait = Duration(seconds: 90);
      final sw = Stopwatch()..start();

      while (true) {
        await Future.delayed(pollEvery);
        final r = await _dio.get(statusPath);

        if (r.statusCode != 200 || r.data is! Map) {
          throw ApiException('server_error',
              detail: 'bad status response', status: r.statusCode);
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

      // 3) Результат
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

      if (res.data is Map && (res.data['error'] as String?) != null) {
        final code = res.data['error'] as String;
        final detail = res.data['detail'] as String?;
        throw ApiException(code, detail: detail, status: res.statusCode);
      }

      throw ApiException('server_error',
          detail: 'code ${res.statusCode}: unexpected result',
          status: res.statusCode);
    } on DioException catch (e) {
      final r = e.response;

      // Прямий 429 через DioException (Ingress/CDN або бекенд)
      if (r?.statusCode == 429) {
        final body =
            r?.data is Map ? (r!.data as Map).cast<String, dynamic>() : null;
        final code = (body?['error'] as String?) ??
            'too_many_jobs'; // або 'rate_limited' якщо бек так віддає
        final ra = (r != null) ? _retryAfterSeconds(r, body) : 3600;
        final det = body?['detail'] as String?;
        throw ApiException(code, detail: det, status: 429, retryAfterSec: ra);
      }

      // 400 invalid_post_url — як і було
      if (r?.statusCode == 400 &&
          r?.data is Map &&
          (r!.data['error'] as String?) == 'invalid_post_url') {
        throw ApiException('invalid_post_url',
            detail: r.data['detail'] as String?, status: 400);
      }

      throw ApiException.fromDio(e);
    }
  }
}
