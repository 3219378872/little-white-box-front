part of 'mock_router.dart';

// 读取整数查询参数：缺省或空串用默认值，非整数按参数错误拒绝。
int _queryInt(
  Map<String, String> query,
  String key, {
  required int defaultValue,
}) {
  if (!query.containsKey(key) || query[key]!.isEmpty) return defaultValue;
  final value = int.tryParse(query[key]!);
  if (value == null) throw const _MockBiz(400, 2, '参数错误');
  return value;
}

// 页码与页大小的宽松钳制，非法值回落到默认而不是报错。
int _clampPage(int page) => page <= 0 ? 1 : page;

int _clampPageSize(int pageSize) => _clampPageSizeTo(pageSize, 20, 50);

int _clampPageSizeTo(int pageSize, int fallback, int max) {
  if (pageSize <= 0) return fallback;
  if (pageSize > max) return max;
  return pageSize;
}

// 路径中的实体 ID 必须是整数，否则按参数错误拒绝。
int _pathId(String raw) {
  final value = int.tryParse(raw);
  if (value == null) throw const _MockBiz(400, 2, '参数错误');
  return value;
}

// 方法不匹配时返回 405。
void _requireMethod(String actual, String expected) {
  if (actual != expected) throw const _MockBiz(405, 1, '未知错误');
}

// 受保护接口要求有效登录，否则返回 401/1006，触发客户端刷新或登录流程。
void _requireAuth(_Auth auth) {
  if (!auth.isAuthenticated) throw const _MockBiz(401, 1006, '请先登录');
}

// 宽松读取字符串数组，非数组视为空。
List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

// 浅拷贝种子实体，避免处理函数改写共享的种子常量。
Map<String, dynamic> _copyMap(Map<String, dynamic> source) =>
    Map<String, dynamic>.from(source);

bool _isPositiveId(Object? value) => jsonInt64IsPositive(value);
