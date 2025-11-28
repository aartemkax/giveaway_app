import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:giveaway_app/utils/constants.dart';

class DeviceService {
  Future<Map<String, dynamic>> collectFingerprint() async {
    final info = <String, dynamic>{};
    final di = DeviceInfoPlugin();
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

    try {
      final r1 = await http.post(
        collectGeoUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceInfo': info}),
      );
      if (r1.statusCode == 200) {
        final body = jsonDecode(r1.body) as Map<String, dynamic>;
        final geo = (body['geo'] as Map?)?.cast<String, dynamic>() ?? {};
        info['geo'] = geo;
        info['country_iso'] =
            (geo['country_code'] ?? '').toString().toUpperCase();
      }
    } catch (_) {}
    return info;
  }

  Future<Map<String, dynamic>> emulateOnServer(
      Map<String, dynamic> info) async {
    final r2 = await http.post(
      deviceReportUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'deviceInfo': info}),
    );
    return (jsonDecode(r2.body) as Map).cast<String, dynamic>();
  }
}
