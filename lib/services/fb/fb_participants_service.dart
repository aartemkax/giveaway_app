//lib/services/fb/fb_participants_service.dart
import 'package:dio/dio.dart';
import '../../models/participant.dart';
import '../api_client.dart';
import '../../utils/api_exception.dart';

class FbParticipantsService {
  final Dio _dio;

  FbParticipantsService() : _dio = ApiClient().dio;
  FbParticipantsService.withDio(this._dio);

  Future<List<Participant>> fetchCommentsAll({
    required String mediaId,
    required String pageId,
  }) async {
    try {
      final r = await _dio.get(
        '/api/ig/comments_all',
        queryParameters: {'media_id': mediaId, 'page_id': pageId},
      );

      if (r.statusCode == 200 && r.data is Map) {
        final data = r.data as Map;
        final raw = data['participants'];
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => Participant.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        }
        return <Participant>[];
      }

      if (r.data is Map) {
        final m = r.data as Map;
        final code = (m['error'] as String?) ?? 'server_error';
        final detail = m['detail'] as String?;
        throw ApiException(code, detail: detail ?? 'HTTP ${r.statusCode}');
      }

      throw ApiException('server_error', detail: 'HTTP ${r.statusCode}');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> runDraw({
    required String mediaId,
    required String pageId,
    required String uniqueBy, // 'user' | 'comment' | 'both'
    int winners = 1,
    String? seed,
    List<String>? requiredHashtags,
    int minMentions = 0,
    List<String>? denylist,
    String? startedAt,
    String? endedAt,
  }) async {
    try {
      final r = await _dio.post(
        '/api/ig/run_draw',
        data: {
          'media_id': mediaId,
          'page_id': pageId,
          'filter': {
            'required_hashtags': requiredHashtags ?? <String>[],
            'min_mentions': minMentions,
            'denylist': denylist ?? <String>[],
            'started_at': startedAt,
            'ended_at': endedAt,
            'unique_by': uniqueBy,
          },
          'winners': winners,
          'seed': seed,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (r.statusCode == 200 && r.data is Map) {
        return Map<String, dynamic>.from(r.data as Map);
      }

      if (r.data is Map) {
        final m = r.data as Map;
        final code = (m['error'] as String?) ?? 'server_error';
        final detail = m['detail'] as String?;
        throw ApiException(code, detail: detail ?? 'HTTP ${r.statusCode}');
      }

      throw ApiException('server_error', detail: 'HTTP ${r.statusCode}');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
