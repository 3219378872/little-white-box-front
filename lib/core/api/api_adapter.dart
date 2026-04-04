import 'dart:async';
import 'api_exceptions.dart';

/// 将 SDK 的 ok/fail/eventually 回调模式转换为 Future<T>
///
/// 用法示例:
///   final resp = await apiCall<LoginResp>(
///     (ok, fail, eventually) => login(
///       LoginReq(...),
///       ok: ok, fail: fail, eventually: eventually,
///     ),
///   );
Future<T> apiCall<T>(
  void Function(
    Function(T) ok,
    Function(String) fail,
    Function eventually,
  ) caller,
) {
  final completer = Completer<T>();
  caller(
    (data) {
      if (!completer.isCompleted) completer.complete(data);
    },
    (error) {
      if (!completer.isCompleted) completer.completeError(ApiException(error));
    },
    () {
      if (!completer.isCompleted) {
        completer.completeError(const ApiException('请求未返回结果'));
      }
    },
  );
  return completer.future;
}

/// 带超时的 API 调用
Future<T> apiCallWithTimeout<T>(
  void Function(
    Function(T) ok,
    Function(String) fail,
    Function eventually,
  ) caller, {
  Duration timeout = const Duration(seconds: 15),
}) {
  return apiCall<T>(caller).timeout(
    timeout,
    onTimeout: () => throw const ApiException('请求超时'),
  );
}
