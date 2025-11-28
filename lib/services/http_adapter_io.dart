import 'package:dio/dio.dart';
import 'package:dio/io.dart';

HttpClientAdapter newAdapter() {
  return IOHttpClientAdapter();
}
