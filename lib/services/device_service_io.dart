import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:giveaway_app/utils/constants.dart';

class DeviceService {
  Future<Map<String, dynamic>> collectFingerprint() async {
    final info = <String, dynamic>{};
    final di = DeviceInfoPlugin();

    if (Platform.isAndroid) {
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
        'androidVersion': int.tryParse(i.systemVersion.split('.').first) ?? 0,
        'androidRelease': i.systemVersion,
        'manufacturer': 'Apple',
        'model': i.utsname.machine,
        'cpu': 'arm64',
        'userAgent': '',
        'platform': 'iOS',
      });
    } else {
      info.addAll({'platform': Platform.operatingSystem, 'userAgent': ''});
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
