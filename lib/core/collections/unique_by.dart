/// 按 [keyOf] 去重并保留首次出现的元素。
///
/// 分页合并、刷新快照等场景用它抵御服务端同页重复返回，键一般取 `jsonInt64Id(item.id)`。
List<T> uniqueBy<T, K>(Iterable<T> items, K Function(T item) keyOf) {
  final seen = <K>{};
  return [
    for (final item in items)
      if (seen.add(keyOf(item))) item,
  ];
}

/// 把 [additions] 中键未出现过的元素追加到 [current] 之后。
///
/// 加载更多时使用：[current] 原样保留，新页内部的重复也一并丢弃。
List<T> appendUniqueBy<T, K>(
  List<T> current,
  Iterable<T> additions,
  K Function(T item) keyOf,
) {
  final seen = {for (final item in current) keyOf(item)};
  return [
    ...current,
    for (final item in additions)
      if (seen.add(keyOf(item))) item,
  ];
}
