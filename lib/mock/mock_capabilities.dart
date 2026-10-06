part of 'mock_router.dart';

// Agent 授权状态；种子用户默认已授权，未播种的用户视为未授权。
Map<String, dynamic> _consentOf(int userId) {
  return _copyMap(
    _agentConsent[userId] ??
        {
          'granted': false,
          'grantedAt': 0,
          'revokedAt': 0,
          'consentVersion': 0,
          'currentVersion': 2,
        },
  );
}

// 记忆列表，可按 target（memory 为 Agent 记忆、user 为用户画像）过滤，并附各分区容量。
Map<String, dynamic> _listMemory(int userId, String? target) {
  final items = [
    for (final item
        in _assistantMemories[userId] ?? const <Map<String, dynamic>>[])
      if (target == null || target.isEmpty || item['target'] == target)
        _copyMap(item),
  ];
  return {'items': items, 'capacities': _memoryCapacities(userId)};
}

// 各分区已用字符数与上限，供记忆页展示容量条。
List<Map<String, dynamic>> _memoryCapacities(int userId) {
  final items = _assistantMemories[userId] ?? const <Map<String, dynamic>>[];
  int used(String target) => items
      .where((item) => item['target'] == target)
      .fold<int>(0, (total, item) => total + '${item['content']}'.length);
  return [
    {'target': 'memory', 'used': used('memory'), 'limit': 2200},
    {'target': 'user', 'used': used('user'), 'limit': 1375},
  ];
}

// 新增记忆条目，并记录一条可撤销的变更。
Map<String, dynamic> _addMemory(int userId, Map<String, dynamic> body) {
  final target = body['target']?.toString() ?? '';
  final content = body['content']?.toString().trim() ?? '';
  if (target != 'memory' && target != 'user') {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if (content.isEmpty) throw const _MockBiz(400, 2, '参数错误');
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final entry = {
    'id': _nextMemoryId++,
    'target': target,
    'content': content,
    'version': 1,
    'createdAtMs': nowMs,
    'updatedAtMs': nowMs,
  };
  _assistantMemories.putIfAbsent(userId, () => []).add(entry);
  final changeId = _recordMemoryChange(userId, null, entry);
  return {'entry': _copyMap(entry), 'changeId': changeId};
}

// 修改记忆：传入 version 时做乐观并发校验，不一致返回 409；成功后版本加一并记录变更。
Map<String, dynamic> _replaceMemory(
  int userId,
  int id,
  Map<String, dynamic> body,
) {
  final items = _assistantMemories[userId];
  if (items == null) throw const _MockBiz(404, 4, '资源不存在');
  final index = items.indexWhere((item) => (item['id'] as num).toInt() == id);
  if (index < 0) throw const _MockBiz(404, 4, '资源不存在');
  final current = items[index];
  final expected = (body['version'] as num?)?.toInt();
  if (expected != null && expected != (current['version'] as num).toInt()) {
    throw const _MockBiz(409, 2008, '版本冲突');
  }
  final before = _copyMap(current);
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  items[index] = {
    ...current,
    'content': body['content']?.toString() ?? current['content'],
    'version': (current['version'] as num).toInt() + 1,
    'updatedAtMs': nowMs,
  };
  final changeId = _recordMemoryChange(userId, before, items[index]);
  return {'entry': _copyMap(items[index]), 'changeId': changeId};
}

// 删除记忆：版本可从查询参数或请求体读取，校验规则同 [_replaceMemory]。
Map<String, dynamic> _removeMemory(
  int userId,
  int id,
  Map<String, String> query,
  Map<String, dynamic> body,
) {
  final items = _assistantMemories[userId];
  if (items == null) throw const _MockBiz(404, 4, '资源不存在');
  final index = items.indexWhere((item) => (item['id'] as num).toInt() == id);
  if (index < 0) throw const _MockBiz(404, 4, '资源不存在');
  final expected =
      int.tryParse(query['version'] ?? '') ??
      (body['version'] as num?)?.toInt();
  final current = items[index];
  if (expected != null && expected != (current['version'] as num).toInt()) {
    throw const _MockBiz(409, 2008, '版本冲突');
  }
  final before = items.removeAt(index);
  final changeId = _recordMemoryChange(userId, before, null);
  return {'changeId': changeId};
}

// 批量执行 add/replace/remove，按顺序逐条应用；中途失败时之前的操作不回滚。
Map<String, dynamic> _batchMemory(int userId, Map<String, dynamic> body) {
  final ops = body['ops'];
  if (ops is! List || ops.isEmpty) throw const _MockBiz(400, 2, '参数错误');
  final entries = <Map<String, dynamic>>[];
  final changeIds = <int>[];
  for (final raw in ops) {
    if (raw is! Map) continue;
    final op = Map<String, dynamic>.from(raw);
    switch (op['op']?.toString()) {
      case 'add':
        final result = _addMemory(userId, op);
        entries.add(result['entry'] as Map<String, dynamic>);
        changeIds.add(result['changeId'] as int);
      case 'replace':
        final result = _replaceMemory(userId, (op['id'] as num).toInt(), op);
        entries.add(result['entry'] as Map<String, dynamic>);
        changeIds.add(result['changeId'] as int);
      case 'remove':
        final result = _removeMemory(userId, (op['id'] as num).toInt(), {}, op);
        changeIds.add(result['changeId'] as int);
      default:
        throw const _MockBiz(400, 2, '参数错误');
    }
  }
  return {'entries': entries, 'changeIds': changeIds};
}

// 记录变更前后快照（新增时 before 为空、删除时 after 为空），返回供撤销用的变更 ID。
int _recordMemoryChange(
  int userId,
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
) {
  final changeId = _nextChangeId++;
  _assistantMemoryChanges.putIfAbsent(userId, () => []).add({
    'id': changeId,
    'before': before == null ? null : _copyMap(before),
    'after': after == null ? null : _copyMap(after),
  });
  return changeId;
}

// 撤销一次变更：移除变更后的条目并恢复变更前快照；每个变更只能撤销一次。
Map<String, dynamic> _undoMemory(int userId, int changeId) {
  final changes = _assistantMemoryChanges[userId];
  if (changes == null) throw const _MockBiz(404, 4, '资源不存在');
  final index = changes.indexWhere(
    (item) => (item['id'] as num).toInt() == changeId,
  );
  if (index < 0) throw const _MockBiz(404, 4, '资源不存在');
  final change = changes.removeAt(index);
  final before = change['before'] is Map
      ? Map<String, dynamic>.from(change['before'] as Map)
      : null;
  final after = change['after'] is Map
      ? Map<String, dynamic>.from(change['after'] as Map)
      : null;
  final items = _assistantMemories.putIfAbsent(userId, () => []);
  if (after != null) {
    final id = (after['id'] as num).toInt();
    items.removeWhere((item) => (item['id'] as num).toInt() == id);
    if (before != null) items.add(_copyMap(before));
  } else if (before != null) {
    items.add(_copyMap(before));
  }
  if (before != null) return _copyMap(before);
  if (after != null) return _copyMap(after);
  throw const _MockBiz(404, 4, '资源不存在');
}
