// lib/utils/device_info_util.dart

import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';

class DeviceInfoUtil {
  static Future<Map<String, dynamic>> collect({
    BuildContext? context,
  }) async {
    final plugin = DeviceInfoPlugin();
    String userAgent = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iOS'
            : 'Unknown';

    final info = <String, dynamic>{};

    if (Platform.isAndroid) {
      final a = await plugin.androidInfo;
      info.addAll({
        'androidVersion': a.version.sdkInt.toString(),
        'androidRelease': a.version.release,
        'manufacturer': a.manufacturer,
        'model': a.model,
      });
      userAgent = 'Android ${a.version.release}; ${a.manufacturer} ${a.model}';
    } else if (Platform.isIOS) {
      final i = await plugin.iosInfo;
      info.addAll({
        'iosVersion': i.systemVersion,
        'model': i.utsname.machine,
      });
      userAgent = 'iOS ${i.systemVersion}; ${i.utsname.machine}';
    }

    // DPI + resolution через MediaQuery (якщо передали контекст)
    if (context != null && context.mounted) {
      final mq = MediaQuery.of(context);
      info.addAll({
        'dpi': mq.devicePixelRatio.toString(),
        'resolution': '${mq.size.width.toInt()}x${mq.size.height.toInt()}',
      });
    }

    // Зовнішній IP + регіон через GEO_SERVICE_URL / geoServiceUrl
    try {
      final resp = await http.get(Uri.parse(geoServiceUrl));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        info['ip'] = data['ip'];
        info['region'] = data['country_code'];
      }
    } catch (_) {
      // silent fail
    }

    info['userAgent'] = userAgent;
    return info;
  }
}
