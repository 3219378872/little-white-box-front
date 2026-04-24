import 'dart:convert';

import 'error_codes.dart';

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

  bool get isAuthError => ErrorCodes.isAuthError(code);

  @override
  String toString() => message;
}
