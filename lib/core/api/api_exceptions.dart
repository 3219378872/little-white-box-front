import 'dart:convert';

import 'error_codes.dart';

/// 统一的接口错误：[message] 可直接展示给用户，[code] 为网关业务码（见 [ErrorCodes]），
/// 无业务码的传输/格式错误为 null。
class ApiException implements Exception {
  final String message;
  final int? code;

  const ApiException(this.message, {this.code});

  /// 解析 SDK `fail` 回调给出的原始字符串：是网关错误 JSON 时取 message/code，
  /// 否则整串作为消息。
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

  /// 令牌过期、无效或需要登录，调用方据此决定刷新令牌或引导重新登录。
  bool get isAuthError => ErrorCodes.isAuthError(code);

  @override
  String toString() => message;
}

/// 把任意异常转成可展示的提示文本，去掉 Dart 默认的 `Exception: ` 前缀。
String friendlyErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  final str = error.toString();
  if (str.startsWith('Exception: ')) return str.substring(11);
  return str;
}
