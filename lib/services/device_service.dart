// lib/services/device_service.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show WidgetsBinding;

import 'package:giveaway_app/services/api_client.dart';
import 'package:giveaway_app/utils/constants.dart';
export 'device_service_io.dart'
    if (dart.library.html) 'device_service_web.dart';

class DeviceService {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> collectFingerprint() async {
    final info = <String, dynamic>{};
    final di = DeviceInfoPlugin();

    if (kIsWeb) {
      final web = await di.webBrowserInfo;
      info.addAll({
        'appVersion': web.appVersion ?? '',
        'androidVersion': 0,
        'androidRelease': web.userAgent ?? '',
        'manufacturer': web.vendor ?? 'Browser',
        'model': web.product ?? 'Browser',
        'cpu': '',
        'userAgent': web.userAgent ?? '',
        'platform': 'Web',
      });
    } else if (Platform.isAndroid) {
      final a = await di.androidInfo;
      info.addAll({
        'appVersion': a.version.release,
        'androidVersion': a.version.sdkInt,
        'androidRelease': a.version.release,
        'manufacturer': a.manufacturer,
        'model': a.model,
        'cpu': a.hardware,
        'userAgent': '',
        'platform': 'Android',
      });
    } else if (Platform.isIOS) {
      final i = await di.iosInfo;
      final major = int.tryParse(i.systemVersion.split('.').first) ?? 0;
      info.addAll({
        'appVersion': i.systemVersion,
        'androidVersion': major,
        'androidRelease': i.systemVersion,
        'manufacturer': 'Apple',
        'model': i.utsname.machine,
        'cpu': 'arm64',
        'userAgent': '',
        'platform': 'iOS',
      });
    } else {
      info.addAll({
        'appVersion': '',
        'androidVersion': 0,
        'androidRelease': '',
        'manufacturer': 'Unknown',
        'model': 'Unknown',
        'cpu': '',
        'userAgent': '',
        'platform': 'Other',
      });
    }

    final binding = WidgetsBinding.instance;
    final views = binding.platformDispatcher.views;
    if (views.isNotEmpty) {
      final view = views.first;
      final dp = view.devicePixelRatio;
      final size = view.physicalSize;
      info['screen'] = {
        'width': size.width / dp,
        'height': size.height / dp,
        'pixelRatio': dp,
      };
    } else {
      info['screen'] = {'width': 0, 'height': 0, 'pixelRatio': 1.0};
    }

    final locale = binding.platformDispatcher.locale;
    info['locale'] = locale.toLanguageTag();
    info['timezoneOffset'] = DateTime.now().timeZoneOffset.inMinutes;

    try {
      final r1 = await _dio.postUri(
        collectGeoUri,
        data: {'deviceInfo': info},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (r1.statusCode == 200 && r1.data is Map) {
        final body = r1.data as Map;
        final geo = (body['geo'] as Map?)?.cast<String, dynamic>() ?? {};
        info['geo'] = geo;
        info['country_iso'] =
            (geo['country_code'] ?? '').toString().toUpperCase();
      }
    } catch (_) {
      // GEO опційний — ігноруємо
    }

    return info;
  }

  Future<Map<String, dynamic>> emulateOnServer(
      Map<String, dynamic> info) async {
    final r2 = await _dio.postUri(
      deviceReportUri,
      data: {'deviceInfo': info},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    if (r2.statusCode == 200 && r2.data is Map) {
      return (r2.data as Map).cast<String, dynamic>();
    }
    throw Exception('device_report failed: ${r2.statusCode}');
  }
}
