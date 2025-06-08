// lib/utils/api_exception.dart

/// Виняток для обробки помилок від API
class ApiException implements Exception {
  /// код помилки з відповіді сервера, наприклад "invalid_post_url"
  final String code;

  /// додаткова деталь (опційно), зазвичай текстове повідомлення
  final String? detail;

  ApiException(this.code, {this.detail});

  @override
  String toString() => 'ApiException(code: $code, detail: $detail)';
}
