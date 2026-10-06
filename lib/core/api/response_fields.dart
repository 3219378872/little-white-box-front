import 'api_exceptions.dart';

/// 在仓储边界解码响应：模型抛出的契约错误（[FormatException]、缺字段导致的类型转换失败）
/// 统一转成带中文 [message] 的 [ApiException]，英文原文只留在 detail；解码中主动抛出的
/// [ApiException] 原样透传。
T decodeResponse<T>(String message, T Function() decode) {
  try {
    return decode();
  } on FormatException catch (error) {
    throw ApiException(message, detail: error.toString());
  } on TypeError catch (error) {
    throw ApiException(message, detail: error.toString());
  }
}

/// Required fields are checked before applying Go's nil-slice compatibility.
/// A missing field is a contract failure, not an empty collection or zero count.
List<dynamic> requiredResponseList(Map<String, dynamic> response, String key) {
  if (!response.containsKey(key)) {
    throw FormatException('missing $key');
  }
  final value = response[key];
  if (value == null) return const [];
  if (value is! List) throw FormatException('invalid $key');
  return value;
}

/// 读取必填的非负计数字段；缺失、类型不符或为负都视为契约错误抛 [FormatException]。
int requiredResponseCount(Map<String, dynamic> response, String key) {
  final value = response[key];
  if (value is! int || value < 0) {
    throw FormatException('invalid $key');
  }
  return value;
}
