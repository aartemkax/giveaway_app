// lib/services/appapi/app_participants_service.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/services/api_client.dart';
import 'package:giveaway_app/utils/constants.dart';
import '../../models/participant.dart';
import '../../utils/api_exception.dart';

class ParticipantsService {
  final Dio _dio;

  ParticipantsService() : _dio = ApiClient().dio;

  ParticipantsService.withDio(this._dio);

  Future<List<Participant>> fetchParticipants(
    String postUrl, {
    BuildContext? context,
  }) async {
    try {
      final normalized = _normalizePostUrl(postUrl);
      final prefs = await SharedPreferences.getInstance();
      final activeAccountId =
          (prefs.getString('active_account_id') ?? '').trim();
      final startPath = activeAccountId.isNotEmpty
          ? '/api/admin/accounts/$activeAccountId/fetch_participants_async'
          : '/api/fetch_participants_async';

      final start = await _dio.post(
        startPath,
        data: {'post_url': normalized},
      );

      if (start.statusCode != 202 || start.data is! Map) {
        throw ApiException('unknown_error', detail: 'unexpected start response');
      }

      final jobId = (start.data['job_id'] ?? '') as String;
      if (jobId.isEmpty) {
        throw ApiException('unknown_error', detail: 'empty job id');
      }

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

      throw ApiException(
        'server_error',
        detail: 'code ${res.statusCode}: unexpected result',
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

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
