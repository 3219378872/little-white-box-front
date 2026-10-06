import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/search_repository.dart';

/// 搜索数据源；测试与 Mock 入口在此替换实现，notifier 只依赖接口。
final searchRepositoryProvider = Provider<SearchDataSource>((ref) {
  return const SearchRepository();
});
