// lib/utils/constants.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Базовий URL бекенду з .env
/// Якщо змінної немає — використовується локальний дефолт.
String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8080';

/// URI для гео-запиту (бекенд дивиться на IP клієнта)
Uri get collectGeoUri => Uri.parse('$apiBaseUrl/api/collect_geo');

/// URI для емуляції девайса на сервері
Uri get deviceReportUri => Uri.parse('$apiBaseUrl/api/device_report');

/// Зовнішній GEO-сервіс для визначення IP/країни.
/// Якщо GEO_SERVICE_URL не заданий, використовується ipapi.co.
String get geoServiceUrl =>
    dotenv.env['GEO_SERVICE_URL'] ?? 'https://ipapi.co/json/';
