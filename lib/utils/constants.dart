// lib/utils/constants.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8080';

Uri get apiBaseUri => Uri.parse(apiBaseUrl);

String get apiEnvironmentLabel {
  final host = apiBaseUri.host.toLowerCase();
  if (host.contains('staging')) return 'STAGE';
  if (host.contains('production')) return 'PROD';
  if (host == '10.0.2.2' || host == 'localhost' || host == '127.0.0.1') {
    return 'LOCAL';
  }
  return 'CUSTOM';
}

bool get isProductionApi => apiEnvironmentLabel == 'PROD';

Uri get collectGeoUri => Uri.parse('$apiBaseUrl/api/collect_device_geo');

Uri get deviceReportUri => Uri.parse('$apiBaseUrl/api/device_report');

String get geoServiceUrl =>
    dotenv.env['GEO_SERVICE_URL'] ?? 'https://ipapi.co/json/';
