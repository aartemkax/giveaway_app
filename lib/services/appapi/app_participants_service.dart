import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'package:giveaway_app/services/api_client.dart';
import 'package:giveaway_app/utils/constants.dart';
import '../../models/participant.dart';
import '../../utils/api_exception.dart';

class ParticipantsService {
  final Dio _dio;

  // За замовчуванням беремо спільний клієнт
  ParticipantsService() : _dio = ApiClient().dio;

  // Для DI через провайдери
  ParticipantsService.withDio(this._dio);

  Future<List<Participant>> fetchParticipants(
    String postUrl, {
    BuildContext? context, // не використовується, але залишимо як опційний
  }) async {
    try {
      final normalized = _normalizePostUrl(postUrl);

      // 1) старт асинхронної джоби
      final start = await _dio.post(
        '/api/fetch_participants_async',
        data: {'post_url': normalized},
      );

      if (start.statusCode != 202 || start.data is! Map) {
        throw ApiException('unknown_error',
            detail: 'unexpected start response');
      }

      final jobId = (start.data['job_id'] ?? '') as String;
      if (jobId.isEmpty) {
        throw ApiException('unknown_error', detail: 'empty job id');
      }

      // 2) полінг статусу
      final statusPath = '/api/job_status/$jobId';
      const pollEvery = Duration(seconds: 2);
      const maxWait = Duration(seconds: 90);
      final sw = Stopwatch()..start();

      while (true) {
        await Future.delayed(pollEvery);
        final stRes = await _dio.get(statusPath);

        if (stRes.statusCode != 200 || stRes.data is! Map) {
          throw ApiException('unknown_error', detail: 'bad status response');
        }

        final status = (stRes.data['status'] as String?)?.toLowerCase() ?? '';
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
              .whereType<Map>()
              .map((e) => _parseParticipant(Map<String, dynamic>.from(e)))
              .toList();
        }
        return <Participant>[];
      }

      if (res.statusCode == 202) {
        throw ApiException('timeout', detail: 'result_pending');
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

  // ——— helpers ———

  String _normalizePostUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.endsWith('/')) u = '$u/';
    return u;
  }

  Participant _parseParticipant(Map<String, dynamic> json) {
    final username = (json['username'] ?? '').toString();
    final rawPic = (json['profile_pic_url'] ?? '').toString();
    final picUrl = rawPic.isEmpty
        ? ''
        : (rawPic.startsWith('http') ? rawPic : '$apiBaseUrl$rawPic');
    return Participant(username: username, profilePicUrl: picUrl);
  }
}
