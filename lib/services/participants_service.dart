// lib/services/participants_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import '../models/participant.dart';
import '../utils/constants.dart';
import '../utils/api_exception.dart';
import '../utils/device_info_util.dart';

class ParticipantsService {
  final _client = BrowserClient()..withCredentials = true;

  Future<List<Participant>> fetchParticipants(
    String postUrl, {
    required BuildContext context,
  }) async {
    // 0) Нормалізуємо URL (бек теж підправляє, але не завадить)
    postUrl = postUrl.trim();
    if (postUrl.isNotEmpty && !postUrl.endsWith('/')) {
      postUrl = '$postUrl/';
    }

    // 1) Device & geo з таймаутом і фолбеком
    debugPrint('🟦 [fetchParticipants] collecting device info...');
    Map<String, dynamic> deviceInfo;
    String? region;
    try {
      deviceInfo = await DeviceInfoUtil.collect(context: context)
          .timeout(const Duration(seconds: 6));
      region = deviceInfo['region'];
      debugPrint('🟩 [fetchParticipants] device collected, region=$region');
    } catch (e, st) {
      debugPrint('🟥 [fetchParticipants] device collect failed: $e\n$st');
      // Не ламаємо флоу — шлемо мінімум
      deviceInfo = <String, dynamic>{'source': 'fallback'};
      region = null;
    }

    // 2) Старт асинхронної задачі
    final uriStart = Uri.parse('$apiBaseUrl/api/fetch_participants_async');
    final payload = {
      'post_url': postUrl,
      'device_info': deviceInfo,
      'region': region,
    };

    debugPrint('🟦 [fetchParticipants] POST $uriStart');
    debugPrint('🟦 [fetchParticipants] body: ${jsonEncode(payload)}');

    http.Response startResp;
    try {
      startResp = await _client.post(
        uriStart,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('🟥 [fetchParticipants] network error on start: $e');
      throw ApiException('internal_error',
          detail: 'network_error_on_start: $e');
    }

    debugPrint(
        '🟨 [fetchParticipants] start status=${startResp.statusCode} body=${startResp.body}');
    if (startResp.statusCode != 202) {
      final err = _safeJson(startResp.body);
      throw ApiException(
        (err['error'] as String?) ?? 'unknown_error',
        detail: err['detail'] as String?,
      );
    }

    final jobId = (jsonDecode(startResp.body) as Map<String, dynamic>)['job_id']
        as String;
    debugPrint('🟩 [fetchParticipants] job_id=$jobId');

    // 3) Поллінг статусу
    final statusUri = Uri.parse('$apiBaseUrl/api/job_status/$jobId');
    String status = '';
    do {
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('🟦 [fetchParticipants] GET $statusUri');
      http.Response statusResp;
      try {
        statusResp = await _client.get(statusUri);
      } catch (e) {
        debugPrint('🟥 [fetchParticipants] network error on status: $e');
        throw ApiException('internal_error',
            detail: 'network_error_on_status: $e');
      }
      debugPrint(
          '🟨 [fetchParticipants] status code=${statusResp.statusCode} body=${statusResp.body}');
      if (statusResp.statusCode != 200) {
        throw ApiException('unknown_error', detail: 'Cannot fetch job status');
      }
      status = ((jsonDecode(statusResp.body) as Map<String, dynamic>)['status']
              as String)
          .toLowerCase();
    } while (status != 'finished');

    // 4) Результат
    final resultUri = Uri.parse('$apiBaseUrl/api/job_result/$jobId');
    debugPrint('🟦 [fetchParticipants] GET $resultUri');
    http.Response resultResp;
    try {
      resultResp = await _client.get(resultUri);
    } catch (e) {
      debugPrint('🟥 [fetchParticipants] network error on result: $e');
      throw ApiException('internal_error',
          detail: 'network_error_on_result: $e');
    }
    debugPrint(
        '🟨 [fetchParticipants] result code=${resultResp.statusCode} body=${resultResp.body}');

    if (resultResp.statusCode == 200) {
      final data = jsonDecode(resultResp.body) as Map<String, dynamic>;
      final raw = data['participants'];
      if (raw is! List) return <Participant>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(Participant.fromJson)
          .toList();
    } else {
      final err = _safeJson(resultResp.body);
      throw ApiException(
        (err['error'] as String?) ?? 'unknown_error',
        detail: err['detail'] as String?,
      );
    }
  }

  Map<String, dynamic> _safeJson(String body) {
    try {
      final m = jsonDecode(body);
      return (m is Map<String, dynamic>) ? m : <String, dynamic>{'raw': m};
    } catch (_) {
      return <String, dynamic>{'raw': body};
    }
  }
}
