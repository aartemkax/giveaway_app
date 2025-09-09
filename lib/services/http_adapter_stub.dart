import 'package:dio/dio.dart';

HttpClientAdapter newAdapter() {
  // Заглушка — має бути перекрита умовними імпортами.
  throw UnsupportedError('No adapter for this platform');
}
