// lib/utils/constants.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Base URL of the Flask backend (loaded from .env or fallback to localhost)
String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080';

/// Geo-IP service URL (loaded from .env or fallback)
String get geoServiceUrl =>
    dotenv.env['GEO_SERVICE_URL'] ?? 'https://ipapi.co/json/';

/// Endpoint URIs
Uri get loginUri => Uri.parse('$apiBaseUrl/api/login');
Uri get debugSessionUri => Uri.parse('$apiBaseUrl/api/debug_session');
Uri get collectGeoUri => Uri.parse('$apiBaseUrl/api/collect_device_geo');
Uri get deviceReportUri => Uri.parse('$apiBaseUrl/api/device_report');
Uri get fetchParticipantsAsyncUri =>
    Uri.parse('$apiBaseUrl/api/fetch_participants_async');

/// Constructed job status/result URIs
Uri jobStatusUri(String jobId) =>
    Uri.parse('$apiBaseUrl/api/job_status/$jobId');
Uri jobResultUri(String jobId) =>
    Uri.parse('$apiBaseUrl/api/job_result/$jobId');
