part of 'mock_router.dart';

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

Map<String, dynamic> _listMemory(int userId, String? target) {
  final items = [
    for (final item
        in _assistantMemories[userId] ?? const <Map<String, dynamic>>[])
      if (target == null || target.isEmpty || item['target'] == target)
        _copyMap(item),
  ];
  return {'items': items, 'capacities': _memoryCapacities(userId)};
}

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

Map<String, dynamic> _createWatch(int userId, Map<String, dynamic> body) {
  final condition = body['conditionType']?.toString() ?? '';
  final targetType = body['targetType']?.toString() ?? '';
  final expected = _watchConditions[condition];
  if (expected == null || expected != targetType) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final targetId = body['targetId'];
  final targetText = body['targetText']?.toString() ?? '';
  if ((condition == 'author_new_post' || condition == 'post_revised') &&
      !_isPositiveId(targetId)) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if (condition == 'author_new_post' &&
      jsonInt64Id(targetId) == jsonInt64Id(userId)) {
    throw const _MockBiz(400, 6005, '不能关注自己的动态');
  }
  if (condition == 'post_revised') {
    final postId = int.tryParse(jsonInt64Id(targetId));
    Map<String, dynamic>? post;
    if (postId != null) {
      for (final item in _posts) {
        if ((item['id'] as num?)?.toInt() == postId) {
          post = item;
          break;
        }
      }
    }
    if (post != null && jsonInt64Id(post['authorId']) == jsonInt64Id(userId)) {
      throw const _MockBiz(400, 6005, '不能关注自己的动态');
    }
  }
  if ((condition == 'tag_new_post' || condition == 'keyword_new_post') &&
      targetText.trim().isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final tasks = _assistantWatches.putIfAbsent(userId, () => []);
  for (final existing in tasks) {
    if (existing['conditionType'] == condition &&
        existing['targetType'] == targetType &&
        '${existing['targetId']}' == '${targetId ?? 0}' &&
        existing['targetText'] == targetText) {
      throw const _MockBiz(409, 2008, '追踪任务已存在');
    }
  }
  final task = {
    'id': _nextWatchId++,
    'conditionType': condition,
    'targetType': targetType,
    'targetId': _isPositiveId(targetId) ? int.parse(jsonInt64Id(targetId)) : 0,
    'targetText': targetText,
    'enabled': true,
    'version': 1,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };
  tasks.add(task);
  return task;
}

Map<String, dynamic> _updateWatch(
  int userId,
  int id,
  Map<String, dynamic> body,
) {
  final tasks = _assistantWatches[userId];
  if (tasks == null) throw const _MockBiz(404, 4, '资源不存在');
  final index = tasks.indexWhere((item) => (item['id'] as num).toInt() == id);
  if (index < 0) throw const _MockBiz(404, 4, '资源不存在');
  final expectedVersion = (body['expectedVersion'] as num?)?.toInt() ?? 0;
  final currentVersion = (tasks[index]['version'] as num?)?.toInt() ?? 0;
  if (expectedVersion <= 0 || expectedVersion != currentVersion) {
    throw const _MockBiz(409, 2007, '内容版本冲突');
  }
  tasks[index] = {
    ...tasks[index],
    'enabled': body['enabled'] == true,
    'version': currentVersion + 1,
  };
  return tasks[index];
}

void _deleteWatch(int userId, int id, Map<String, dynamic> body) {
  final tasks = _assistantWatches[userId];
  if (tasks == null) throw const _MockBiz(404, 4, '资源不存在');
  final index = tasks.indexWhere((item) => (item['id'] as num).toInt() == id);
  if (index < 0) throw const _MockBiz(404, 4, '资源不存在');
  final expectedVersion = (body['expectedVersion'] as num?)?.toInt() ?? 0;
  final currentVersion = (tasks[index]['version'] as num?)?.toInt() ?? 0;
  if (expectedVersion <= 0 || expectedVersion != currentVersion) {
    throw const _MockBiz(409, 2007, '内容版本冲突');
  }
  tasks.removeAt(index);
}
