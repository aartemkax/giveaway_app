import 'dart:html' as html show window;
import 'package:dio/dio.dart';
import 'package:giveaway_app/services/api_client.dart';

class DeviceService {
  Future<Map<String, dynamic>> collectFingerprint() async {
    final nav = html.window.navigator;
    return {
      'source': 'web',
      'userAgent': nav.userAgent,
      'platform': nav.platform ?? '',
      'languages': nav.languages ?? const <String>[],
      'hardwareConcurrency': (nav as dynamic).hardwareConcurrency ?? 0,
      'timezoneOffset': DateTime.now().timeZoneOffset.inMinutes,
      'screen': {
        'width': html.window.screen?.width ?? 0,
        'height': html.window.screen?.height ?? 0,
        'pixelRatio': html.window.devicePixelRatio,
      },
    };
  }

  Future<Map<String, dynamic>> emulateOnServer(Map<String, dynamic> raw) async {
    try {
      final r = await ApiClient().dio.post(
        '/api/device_report',
        data: {'deviceInfo': raw},
      );
      if (r.statusCode == 200 && r.data is Map) {
        return Map<String, dynamic>.from(r.data as Map);
      }
    } on DioException {
      // ігноруємо — повернемо raw
    }
    return raw;
  }
}
