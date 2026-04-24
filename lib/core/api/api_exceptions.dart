import 'dart:convert';

class ApiException implements Exception {
  final String message;
  final int? code;

  const ApiException(this.message, {this.code});

  factory ApiException.parse(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ApiException(
        (map['message'] as String?) ?? raw,
        code: map['code'] as int?,
      );
    } catch (_) {
      return ApiException(raw);
    }
  }

  bool get isAuthError =>
      code != null && (code == 1004 || code == 1005 || code == 1006);

  @override
  String toString() => message;
}
