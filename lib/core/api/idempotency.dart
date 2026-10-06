import 'dart:math';

/// 生成定长 base36 幂等键，供表单提交、审核决定等只需不重复的场景复用。
String newIdempotencyKey([int length = 16]) {
  final random = Random.secure();
  return List.generate(
    length,
    (_) => random.nextInt(36).toRadixString(36),
  ).join();
}

/// 生成 `<prefix>-<微秒时间戳>-<随机十六进制>` 形式的请求 ID。
///
/// 前缀标明来源（消息、助手、上传、客户端身份），便于在服务端日志中区分；
/// [randomBytes] 为随机段字节数，[timestampRadix] 保留各调用方既有的时间戳进制。
String newPrefixedRequestId(
  String prefix, {
  int randomBytes = 16,
  int timestampRadix = 16,
}) {
  final random = Random.secure();
  // 每字节两位十六进制，长度固定为 randomBytes * 2。
  final suffix = List<String>.generate(
    randomBytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(
    timestampRadix,
  );
  return '$prefix-$timestamp-$suffix';
}
