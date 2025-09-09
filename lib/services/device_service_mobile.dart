import 'package:device_info_plus/device_info_plus.dart';
import 'package:giveaway_app/services/api_client.dart';
import 'package:dio/dio.dart';

class DeviceService {
  final _dev = DeviceInfoPlugin();

  Future<Map<String, dynamic>> collectFingerprint() async {
    // Мінімальний відбиток, без доступу до заборонених полів
    try {
      final info = await _dev.deviceInfo;
      final m = info.data; // already Map<String, dynamic>
      return {
        'source': 'mobile',
        'model': m['model'],
        'brand': m['brand'] ?? m['manufacturer'],
        'os': m['version'] ?? m['systemVersion'] ?? '',
        'timezoneOffset': DateTime.now().timeZoneOffset.inMinutes,
        'screen': {
          // можеш замінити на реальні значення через MediaQuery у UI; тут заглушки
          'width': 0,
          'height': 0,
          'pixelRatio': 0,
        },
      };
    } catch (_) {
      return {
        'source': 'mobile',
        'timezoneOffset': DateTime.now().timeZoneOffset.inMinutes,
      };
    }
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
      // пропускаємо
    }
    return raw;
  }
}
