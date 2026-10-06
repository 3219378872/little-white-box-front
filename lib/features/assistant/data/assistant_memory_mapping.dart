part of 'assistant_repository.dart';

// 记忆接口的响应映射：集中列表、写入与撤销三处共用的 MemoryRecord 解析。

// 写入前拒绝未知目标，避免把无效 target 发给服务端。
void _requireMemoryTarget(String target) {
  if (!memoryTargets.contains(target)) {
    throw const ApiException('未知的记忆目标');
  }
}

// 单条记忆的宽松解析：缺失字段取空值，数字字段兼容字符串编码。
MemoryRecord _memoryRecordFromJson(Map<String, dynamic> map) {
  return MemoryRecord(
    id: map['id'] ?? 0,
    target: map['target']?.toString() ?? '',
    content: map['content']?.toString() ?? '',
    version: _asInt(map['version']),
    createdAtMs: _asInt(map['createdAtMs']),
    updatedAtMs: _asInt(map['updatedAtMs']),
  );
}

// 列表响应：丢弃客户端不认识的目标，容量按原样返回。
(List<MemoryRecord>, List<MemoryCapacity>) _memoryListFromResponse(
  Map<String, dynamic> response,
) {
  final items = <MemoryRecord>[];
  for (final item in _requiredList(response, 'items')) {
    final record = _memoryRecordFromJson(_requiredObject(item));
    if (!memoryTargets.contains(record.target)) continue;
    items.add(record);
  }
  final capacities = [
    for (final item in _requiredList(response, 'capacities'))
      _memoryCapacityFromJson(_requiredObject(item)),
  ];
  return (items, capacities);
}

MemoryCapacity _memoryCapacityFromJson(Map<String, dynamic> map) {
  return MemoryCapacity(
    target: map['target']?.toString() ?? '',
    used: _asInt(map['used']),
    limit: _asInt(map['limit']),
  );
}

// 写入响应：entry 可缺省（如删除），changeId 用于撤销。
MemoryWriteResult _memoryWriteFromResponse(Map<String, dynamic> response) {
  final raw = response['entry'];
  return MemoryWriteResult(
    entry: raw is Map
        ? _memoryRecordFromJson(Map<String, dynamic>.from(raw))
        : null,
    changeId: response['changeId'] ?? 0,
  );
}

// 撤销响应必须带回被恢复的记忆，否则视为格式错误。
MemoryRecord _undoneMemoryFromResponse(Map<String, dynamic> response) {
  final raw = response['entry'];
  if (raw is! Map) {
    throw const ApiException('撤销记忆响应格式无效');
  }
  return _memoryRecordFromJson(Map<String, dynamic>.from(raw));
}
