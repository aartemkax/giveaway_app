// lib/utils/constants.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// URL вашого бекенду (після dotenv.load() буде прочитано .env)
String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000';

/// eндпоінти
Uri get loginUri => Uri.parse('$apiBaseUrl/api/login');
Uri get fetchUri => Uri.parse('$apiBaseUrl/api/fetch_participants');
