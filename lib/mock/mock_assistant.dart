part of 'mock_router.dart';

Map<String, dynamic> _threadOf(int userId) {
  return _copyMap(
    _assistantThreads[userId] ??
        {
          'sessionId': 1,
          'unreadCount': 0,
          'lastMessageId': 0,
          'lastMessagePreview': '',
          'lastMessageAtMs': 0,
          'activeRunId': 0,
          'activeRunStatus': '',
          'activeRunPhase': '',
        },
  );
}

Map<String, dynamic> _markAssistantRead(int userId) {
  final thread = _assistantThreads.putIfAbsent(userId, _emptyThread);
  thread['unreadCount'] = 0;
  return {'unreadCount': 0};
}

Map<String, dynamic> _listAssistantMessages(
  int userId,
  Map<String, String> query,
) {
  final sessionId = query['sessionId'];
  final afterId = int.tryParse(query['afterId'] ?? '') ?? 0;
  final beforeId = int.tryParse(query['beforeId'] ?? '') ?? 0;
  if (afterId > 0 && beforeId > 0) {
    throw const _MockBiz(400, 2, '消息游标不能同时向前和向后');
  }
  final requestedLimit = int.tryParse(query['limit'] ?? '') ?? 50;
  final limit = requestedLimit <= 0 || requestedLimit > 100
      ? 50
      : requestedLimit;
  final filtered = [
    for (final item
        in _assistantMessages[userId] ?? const <Map<String, dynamic>>[])
      if (sessionId == null ||
          sessionId.isEmpty ||
          '${item['sessionId']}' == sessionId)
        if (afterId <= 0 || ((item['id'] as num).toInt() > afterId))
          if (beforeId <= 0 || ((item['id'] as num).toInt() < beforeId))
            _copyMap(item),
  ];
  final hasMore = filtered.length > limit;
  final items = afterId > 0
      ? filtered.take(limit).toList()
      : filtered
            .skip((filtered.length - limit).clamp(0, filtered.length))
            .toList();
  return {
    'messages': items,
    'hasMore': hasMore,
    'nextBeforeId': afterId > 0 || items.isEmpty ? 0 : items.first['id'],
  };
}

Map<String, dynamic> _postAssistantMessage(
  int userId,
  Map<String, dynamic> body,
) {
  final researchMessage = body['message']?.toString() ?? '';
  if (body['clientProtocolVersion'] == 2 &&
      (researchMessage.contains('比较') ||
          researchMessage.contains('选择') ||
          researchMessage.contains('先搜索') ||
          body['questionContext'] != null ||
          _activeResearchRun(userId) != null)) {
    return _postResearchMessage(userId, body);
  }
  final message = body['message']?.toString().trim() ?? '';
  if (message.isEmpty || message.length > 2000) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final attachments = (body['attachments'] as List<dynamic>? ?? const []);
  if (attachments.length > 9) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final thread = _assistantThreads.putIfAbsent(userId, _emptyThread);
  final sessionId = (thread['sessionId'] as num?)?.toInt() ?? 1;
  final activeRunId = (thread['activeRunId'] as num?)?.toInt() ?? 0;
  final phase = thread['activeRunPhase']?.toString() ?? '';
  final queue = _assistantQueue.putIfAbsent(userId, () => []);
  var disposition = 'started';
  if (activeRunId > 0) {
    if (phase == 'tool_executing' || message.contains('steer-me')) {
      disposition = 'steered';
    } else if (phase == 'compact' ||
        phase == 'attachment' ||
        attachments.isNotEmpty ||
        message.contains('queue-me')) {
      if (queue.length >= 32) {
        throw const _MockBiz(429, 2, '排队已满');
      }
      disposition = 'queued';
    } else {
      disposition = 'redirected';
      _completeRun(activeRunId);
    }
  }
  final messageId = _nextAssistantMessageId++;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final stored = {
    'id': messageId,
    'sessionId': sessionId,
    'runId': 0,
    'role': 'user',
    'kind': 'message',
    'content': message,
    'unread': false,
    'createdAtMs': nowMs,
    'changeId': 0,
  };
  _assistantMessages.putIfAbsent(userId, () => []).add(stored);
  var runId = activeRunId;
  if (disposition == 'queued') {
    runId = _nextAssistantRunId++;
    stored['runId'] = runId;
    queue.add({'runId': runId, 'messageId': messageId, 'message': message});
  } else if (disposition != 'steered') {
    runId = _nextAssistantRunId++;
    stored['runId'] = runId;
    _startRun(userId, runId, sessionId, message);
  } else {
    stored['runId'] = runId;
    thread['activeRunPhase'] = 'tool_executing';
  }
  thread['lastMessageId'] = messageId;
  thread['lastMessagePreview'] = message;
  thread['lastMessageAtMs'] = nowMs;
  if (disposition != 'queued') {
    thread['activeRunId'] = runId;
    thread['activeRunStatus'] = 'running';
    thread['activeRunPhase'] = disposition == 'steered'
        ? 'tool_executing'
        : 'model_request';
  }
  return {
    'messageId': messageId,
    'sessionId': sessionId,
    'runId': runId,
    'disposition': disposition,
  };
}

void _startRun(int userId, int runId, int sessionId, String message) {
  final sourcePost = _publishedPosts().isEmpty
      ? <String, dynamic>{'id': 1, 'title': '示例帖', 'revision': 1, 'authorId': 2}
      : _publishedPosts().first;
  final events = <Map<String, dynamic>>[
    {'seq': 1, 'type': 'run_started', 'runId': runId, 'sessionId': sessionId},
  ];
  const chunkSize = 6;
  const streamId = 'mock-stream';
  final answer = '我根据社区内容找到了与“$message”相关的信息。';
  final pending = StringBuffer();
  var pendingCount = 0;
  void flushToken() {
    if (pending.isEmpty) return;
    events.add({
      'seq': events.length + 1,
      'type': 'token',
      'text': pending.toString(),
      'streamId': streamId,
      'runId': runId,
      'sessionId': sessionId,
    });
    pending.clear();
    pendingCount = 0;
  }

  for (final grapheme in answer.characters) {
    pending.write(grapheme);
    pendingCount++;
    if (pendingCount >= chunkSize) flushToken();
  }
  flushToken();
  events.add({
    'seq': events.length + 1,
    'type': 'source_card',
    'runId': runId,
    'sessionId': sessionId,
    'sourceCard': {
      'handle': 'src-${sourcePost['id']}',
      'kind': 'post',
      'authorityId': '${sourcePost['id']}',
      'title': sourcePost['title'] ?? '',
      'revision': sourcePost['revision'] ?? 1,
    },
  });
  if (message.contains('删除') || message.contains('delete')) {
    events.addAll([
      {
        'seq': events.length + 1,
        'type': 'tool_call',
        'runId': runId,
        'sessionId': sessionId,
        'toolCall': {
          'callId': 'mock-call-search',
          'tool': 'search_posts',
          'summary': '搜索帖子',
        },
      },
      {
        'seq': events.length + 1,
        'type': 'confirm_required',
        'runId': runId,
        'sessionId': sessionId,
        'toolCall': {
          'callId': 'mock-call-delete',
          'tool': 'delete_post',
          'summary': '请求删除帖子 #${sourcePost['id']}',
        },
      },
    ]);
  } else if (message.contains('memory')) {
    events.add({
      'seq': events.length + 1,
      'type': 'memory_changed',
      'runId': runId,
      'sessionId': sessionId,
      'text': '已更新记忆',
      'changeId': 1,
    });
  }
  if (!message.contains('steer-me') && !message.contains('hang')) {
    events.add({
      'seq': events.length + 1,
      'type': 'done',
      'runId': runId,
      'sessionId': sessionId,
    });
  }
  _assistantRunEvents[runId] = events;
  _assistantRuns[runId] = {
    'userId': userId,
    'sessionId': sessionId,
    'status': message.contains('hang') ? 'running' : 'completed',
    'phase': message.contains('steer-me') ? 'tool_executing' : 'model_request',
  };
}

MockRouterResponse _streamAssistantRunEvents(
  int userId,
  int runId,
  Map<String, String> query,
  Map<String, String> headers,
) {
  final run = _assistantRuns[runId];
  if (run == null || run['userId'] != userId) {
    throw const _MockBiz(404, 4, '资源不存在');
  }
  if (run['research'] == true) {
    _expireResearch(runId);
  }
  final lastHeader = headers['last-event-id'] ?? headers['Last-Event-ID'] ?? '';
  final afterSeq = int.tryParse(query['afterSeq'] ?? lastHeader) ?? 0;
  final events = [
    for (final event
        in _assistantRunEvents[runId] ?? const <Map<String, dynamic>>[])
      if (((event['seq'] as num?)?.toInt() ?? 0) > afterSeq) event,
  ];
  final body = events.map((event) {
    final seq = event['seq'];
    return 'id: $seq\ndata: ${jsonEncode(event)}\n\n';
  }).join();
  return MockRouterResponse(
    body: body,
    statusCode: 200,
    headers: {
      'content-type': 'text/event-stream',
      'cache-control': 'no-cache',
      'x-auth-state': 'authenticated',
    },
  );
}

void _cancelAssistantRun(int userId, int runId) {
  final run = _assistantRuns[runId];
  if (run == null || run['userId'] != userId) {
    throw const _MockBiz(404, 4, '资源不存在');
  }
  if (run['research'] == true) {
    _terminateResearch(runId, 'cancelled', 'CANCELLED', '已停止');
    return;
  }
  run['status'] = 'cancelled';
  _completeRun(runId);
}

void _confirmAssistantRun(int userId, int runId, Map<String, dynamic> body) {
  final callId = body['callId']?.toString() ?? '';
  if (callId.isEmpty) throw const _MockBiz(400, 2, '参数错误');
  final run = _assistantRuns[runId];
  if (run == null || run['userId'] != userId) {
    throw const _MockBiz(404, 4, '资源不存在');
  }
}

void _completeRun(int runId) {
  final run = _assistantRuns[runId];
  if (run == null) return;
  run['status'] = 'completed';
  final userId = run['userId'] as int;
  final thread = _assistantThreads[userId];
  if (thread != null && thread['activeRunId'] == runId) {
    thread['activeRunId'] = 0;
    thread['activeRunStatus'] = '';
    thread['activeRunPhase'] = '';
  }
}

void _deleteAssistantHistory(int userId) {
  final runs = [
    for (final entry in _assistantRuns.entries)
      if (entry.value['userId'] == userId) entry.key,
  ];
  for (final runId in runs) {
    _assistantRuns.remove(runId);
    _assistantRunEvents.remove(runId);
  }
  _assistantMessages[userId] = [];
  final thread = _assistantThreads.putIfAbsent(userId, _emptyThread);
  thread['lastMessageId'] = 0;
  thread['lastMessagePreview'] = '';
  thread['unreadCount'] = 0;
  thread['activeRunId'] = 0;
  thread.remove('questionRequest');
}

Map<String, dynamic> _emptyThread() => {
  'sessionId': 1,
  'unreadCount': 0,
  'lastMessageId': 0,
  'lastMessagePreview': '',
  'lastMessageAtMs': 0,
  'activeRunId': 0,
  'activeRunStatus': '',
  'activeRunPhase': '',
};
