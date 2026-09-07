part of 'mock_router.dart';

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

int _clampPage(int page) => page <= 0 ? 1 : page;

int _clampPageSize(int pageSize) => _clampPageSizeTo(pageSize, 20, 50);

int _clampPageSizeTo(int pageSize, int fallback, int max) {
  if (pageSize <= 0) return fallback;
  if (pageSize > max) return max;
  return pageSize;
}

int _pathId(String raw) {
  final value = int.tryParse(raw);
  if (value == null) throw const _MockBiz(400, 2, '参数错误');
  return value;
}

void _requireMethod(String actual, String expected) {
  if (actual != expected) throw const _MockBiz(405, 1, '未知错误');
}

void _requireAuth(_Auth auth) {
  if (!auth.isAuthenticated) throw const _MockBiz(401, 1006, '请先登录');
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

Map<String, dynamic> _copyMap(Map<String, dynamic> source) =>
    Map<String, dynamic>.from(source);

bool _isPositiveId(Object? value) => jsonInt64IsPositive(value);
