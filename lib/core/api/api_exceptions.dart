import 'dart:async';
import 'dart:convert';

import 'error_codes.dart';

/// 网络不可达（断网、连接被拒、浏览器拦截跨域等）时展示的文案。
const networkErrorMessage = '网络连接失败，请检查网络后重试';

/// 响应不符合契约（缺字段、类型不符）时展示的文案；具体原因只留在 [ApiException.detail]。
const unrecognizedResponseMessage = '服务返回了无法识别的数据';

/// 无业务码且不是中文文案的 HTTP 失败（代理错误页、裸状态码）展示的文案。
const requestFailedMessage = '请求失败，请稍后重试';

/// 无业务码的 401：网关之外的鉴权失败，只能提示重新登录。
const sessionExpiredMessage = '登录已失效，请重新登录';

// 判断文案是否已是面向用户的中文；英文文本只可能是传输层或解码的诊断信息。
final _chinese = RegExp(r'[\u4e00-\u9fff]');

// SDK 与 multipart 层对裸状态码的统一写法：`http 502`。
final _bareHttpStatus = RegExp(r'^http (\d{3})$');

// 客户端网络异常的 toString 前缀（package:http 与 dart:io）。
final _networkError = RegExp(
  r'^(ClientException|SocketException|HandshakeException|HttpException)\b',
);

/// 统一的接口错误：[message] 可直接展示给用户，[code] 为网关业务码（见 [ErrorCodes]），
/// 无业务码的传输/格式错误为 null；[detail] 保留原始英文诊断，只用于调试，不展示。
class ApiException implements Exception {
  final String message;
  final int? code;
  final String? detail;

  const ApiException(this.message, {this.code, this.detail});

  /// 解析 SDK `fail` 回调给出的原始字符串：是网关错误 JSON 时取 message/code，
  /// 否则是 SDK 捕获的客户端异常（网络、解码）的 toString，转成中文文案。
  factory ApiException.parse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return ApiException.fromClientError(raw);
    }
    if (decoded is! Map<String, dynamic>) {
      return ApiException.fromClientError(raw);
    }
    final code = decoded['code'];
    final message = decoded['message'];
    return ApiException.http(
      message is String ? message : raw,
      code: code is int ? code : null,
    );
  }

  /// HTTP 失败的统一出口：有业务码或已是中文的文案原样保留；无业务码的英文文本
  /// （裸状态码、代理错误页）换成中文，原文放进 [detail]。
  factory ApiException.http(String message, {int? code}) {
    if (code != null || _chinese.hasMatch(message)) {
      return ApiException(message, code: code);
    }
    final status = _bareHttpStatus.firstMatch(message.trim())?.group(1);
    if (status == '401') {
      return ApiException(sessionExpiredMessage, detail: message);
    }
    return ApiException(
      status == null
          ? requestFailedMessage
          : '$requestFailedMessage（HTTP $status）',
      detail: message,
    );
  }

  /// 客户端侧失败（网络异常、响应解码错误）的统一出口：按类别给中文文案，
  /// [error] 可以是异常对象，也可以是 SDK 转交的 toString 文本。
  factory ApiException.fromClientError(Object error) {
    if (error is ApiException) return error;
    final text = error.toString();
    if (error is TimeoutException) {
      return ApiException('请求超时，请重试', detail: text);
    }
    if (_networkError.hasMatch(text)) {
      return ApiException(networkErrorMessage, detail: text);
    }
    return ApiException(unrecognizedResponseMessage, detail: text);
  }

  /// 令牌过期、无效或需要登录，调用方据此决定刷新令牌或引导重新登录。
  bool get isAuthError => ErrorCodes.isAuthError(code);

  @override
  String toString() => message;
}

/// 把任意异常转成可展示的提示文本，去掉 Dart 默认的 `Exception: ` 前缀。
///
/// 仓储边界之外漏到界面的解码、网络与超时异常，按 [ApiException.fromClientError]
/// 同一套分类换成中文，避免英文诊断直接展示。
String friendlyErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (_isClientError(error)) return ApiException.fromClientError(error).message;
  final str = error.toString();
  if (str.startsWith('Exception: ')) return str.substring(11);
  return str;
}

// 需要按客户端失败分类的异常：解码错误、类型转换错误、超时与网络异常。
bool _isClientError(Object error) =>
    error is FormatException ||
    error is TypeError ||
    error is TimeoutException ||
    _networkError.hasMatch(error.toString());
