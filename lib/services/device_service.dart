// lib/services/device_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;

import 'package:giveaway_app/utils/constants.dart'; // ← ДОДАЙ

class DeviceService {
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
        'userAgent': html.window.navigator.userAgent,
        'platform': html.window.navigator.platform,
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
      info.addAll({
        'appVersion': i.systemVersion,
        'androidVersion': int.parse(i.systemVersion.split('.').first),
        'androidRelease': i.systemVersion,
        'manufacturer': 'Apple',
        'model': i.utsname.machine,
        'cpu': 'arm64',
        'userAgent': '',
        'platform': 'iOS',
      });
    }

    final pd = PlatformDispatcher.instance;
    final view = pd.views.first;
    final dp = view.devicePixelRatio;
    final size = view.physicalSize;
    info['screen'] = {
      'width': size.width / dp,
      'height': size.height / dp,
      'pixelRatio': dp,
    };
    info['locale'] = pd.locale.toLanguageTag();
    info['timezoneOffset'] = DateTime.now().timeZoneOffset.inMinutes;

    // GEO по IP — тепер через constants
    final r1 = await http.post(
      collectGeoUri, // ← ось тут
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'deviceInfo': info}),
    );
    if (r1.statusCode == 200) {
      final body = jsonDecode(r1.body) as Map<String, dynamic>;
      final geo = body['geo'] as Map<String, dynamic>? ?? {};
      info['geo'] = geo;
      info['country_iso'] =
          (geo['country_code'] ?? '').toString().toUpperCase();
    }

    return info;
  }

  Future<Map<String, dynamic>> emulateOnServer(
      Map<String, dynamic> info) async {
    final r2 = await http.post(
      deviceReportUri, // ← і тут
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'deviceInfo': info}),
    );
    return jsonDecode(r2.body) as Map<String, dynamic>;
  }
}
