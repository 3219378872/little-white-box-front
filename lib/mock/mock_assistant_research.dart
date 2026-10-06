part of 'mock_router.dart';

// 线程当前的活动运行若是调研运行则返回它，否则 null。
Map<String, dynamic>? _activeResearchRun(int userId) {
  final id = _assistantThreads[userId]?['activeRunId'];
  final run = _assistantRuns[id];
  return run?['research'] == true ? run : null;
}

// 追问超过回答期限时把运行终止为 expired；在读取事件流时惰性检查。
void _expireResearch(int runId) {
  final question = _assistantRuns[runId]?['question'] as Map<String, dynamic>?;
  if (question != null &&
      question['status'] == 'pending' &&
      DateTime.now().millisecondsSinceEpoch >= question['deadlineMs']) {
    _terminateResearch(runId, 'expired', 'AGENT_RESOURCE_LIMIT', '等待回答已到达运行时限');
  }
}

// 以 [status] 结束待回答的追问并发出 questions_resolved；运行尚未终结时再发 error 事件
// （取消记为 cancelled，其余记为 error），并清除线程上的活动运行与追问。
void _terminateResearch(int runId, String status, String code, String text) {
  final run = _assistantRuns[runId]!;
  final question = run['question'] as Map<String, dynamic>?;
  if (question != null && question['status'] == 'pending') {
    question['status'] = status;
    _researchEvent(runId, 'questions_resolved', {
      'questionRequest': _copyMap(question),
    });
  }
  if (run['status'] == 'cancelled' ||
      run['status'] == 'error' ||
      run['status'] == 'completed') {
    return;
  }
  run['status'] = status == 'cancelled' ? 'cancelled' : 'error';
  _researchEvent(runId, 'error', {'text': text, 'errorCode': code});
  final thread = _assistantThreads[run['userId']];
  if (thread?['activeRunId'] == runId) {
    thread!.addAll({
      'activeRunId': 0,
      'activeRunStatus': '',
      'activeRunPhase': '',
    });
    thread.remove('questionRequest');
  }
}

// 向运行事件序列追加一条事件，seq 按序递增，供 SSE 续传。
void _researchEvent(int runId, String type, Map<String, dynamic> data) {
  final events = _assistantRunEvents.putIfAbsent(runId, () => []);
  events.add({
    'seq': events.length + 1,
    'type': type,
    'runId': runId,
    'sessionId': _assistantRuns[runId]!['sessionId'],
    ...data,
  });
}

// 调研流程的发消息：需要 Agent 授权；同一 requestId 重放返回首次受理结果，
// 内容不同则 409。已有调研运行时，新消息作为 steered 并入并取代待答追问后直接出结果；
// 否则启动新运行，带 questionContext 或含「先搜索」时直接出结果，其余先发一个追问等待回答。
Map<String, dynamic> _postResearchMessage(
  int userId,
  Map<String, dynamic> body,
) {
  if (_consentOf(userId)['granted'] != true) {
    throw const _MockBiz(403, 6001, 'AGENT_NOT_AUTHORIZED');
  }
  final text = body['message']?.toString().trim() ?? '';
  final requestId = body['requestId']?.toString() ?? '';
  if (text.isEmpty || text.runes.length > 2000 || requestId.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  for (final run in _assistantRuns.values) {
    if (run['userId'] == userId && run['requestId'] == requestId) {
      if (run['command'] != jsonEncode(body)) {
        throw const _MockBiz(409, 2007, '请求内容冲突');
      }
      return _copyMap(run['accepted'] as Map<String, dynamic>);
    }
  }
  final thread = _assistantThreads.putIfAbsent(userId, _emptyThread);
  final sessionId = thread['sessionId'] as int;
  final active = _activeResearchRun(userId);
  final runId = active == null
      ? _nextAssistantRunId++
      : thread['activeRunId'] as int;
  final messageId = _nextAssistantMessageId++;
  final now = DateTime.now().millisecondsSinceEpoch;
  _assistantMessages.putIfAbsent(userId, () => []).add({
    'id': messageId,
    'runId': runId,
    'sessionId': sessionId,
    'role': 'user',
    'kind': 'message',
    'content': text,
    'unread': false,
    'createdAtMs': now,
  });
  final accepted = <String, dynamic>{
    'messageId': messageId,
    'sessionId': sessionId,
    'runId': runId,
    'disposition': active == null ? 'started' : 'steered',
  };
  if (active != null) {
    final question = active['question'] as Map<String, dynamic>?;
    if (question != null && question['status'] == 'pending') {
      question['status'] = 'superseded';
      _researchEvent(runId, 'questions_resolved', {
        'questionRequest': _copyMap(question),
      });
    }
    _finishResearch(runId);
    return accepted;
  }
  _assistantRuns[runId] = {
    'userId': userId,
    'sessionId': sessionId,
    'status': 'running',
    'phase': 'model_request',
    'research': true,
    'requestId': requestId,
    'command': jsonEncode(body),
    'accepted': accepted,
  };
  thread.addAll({
    'activeRunId': runId,
    'activeRunStatus': 'running',
    'activeRunPhase': 'model_request',
    'lastMessageId': messageId,
    'lastMessagePreview': text,
    'lastMessageAtMs': now,
  });
  _researchEvent(runId, 'run_started', {});
  if (body['questionContext'] != null || text.contains('先搜索')) {
    _finishResearch(runId);
    return accepted;
  }
  // 发出单题多选追问（30 分钟内回答），运行与线程进入 waiting_input。
  final questionMessageId = _nextAssistantMessageId++;
  final question = <String, dynamic>{
    'id': 'q-$runId',
    'runId': runId,
    'messageId': questionMessageId,
    'callId': 'ask-$runId',
    'status': 'pending',
    'deadlineMs': now + 30 * 60 * 1000,
    'createdAtMs': now,
    'answers': <Map<String, dynamic>>[],
    'questions': [
      {
        'id': 'priority',
        'text': '你更看重哪方面？',
        'selection': 'multiple',
        'options': [
          {'id': 'cost', 'label': '使用成本'},
          {'id': 'experience', 'label': '实际使用体验'},
          {'id': 'maintenance', 'label': '维护难度'},
        ],
      },
    ],
  };
  _assistantRuns[runId]!.addAll({
    'question': question,
    'status': 'waiting_input',
    'phase': 'waiting_input',
  });
  thread.addAll({
    'activeRunStatus': 'waiting_input',
    'activeRunPhase': 'waiting_input',
    'questionRequest': question,
  });
  _assistantMessages[userId]!.add({
    'id': questionMessageId,
    'runId': runId,
    'sessionId': sessionId,
    'role': 'assistant',
    'kind': 'question',
    'content': '你更看重哪方面？',
    'unread': false,
    'createdAtMs': now,
    'questionRequest': question,
  });
  _researchEvent(runId, 'questions_required', {
    'questionRequest': _copyMap(question),
  });
  return accepted;
}

// 回答追问：同一请求体重放直接返回当前追问；追问已回答或过期返回 409；
// 校验答案选项与处置方式后标记 answered 并生成结果。
Map<String, dynamic> _answerResearchQuestions(
  int userId,
  int runId,
  Map<String, dynamic> body,
) {
  final run = _assistantRuns[runId];
  if (run == null || run['userId'] != userId || run['research'] != true) {
    throw const _MockBiz(404, 4, '资源不存在');
  }
  if (_consentOf(userId)['granted'] != true) {
    throw const _MockBiz(403, 6001, 'AGENT_NOT_AUTHORIZED');
  }
  final question = run['question'] as Map<String, dynamic>;
  if (body['questionRequestId'] != question['id']) {
    throw const _MockBiz(404, 4, '问题不存在');
  }
  final digest = jsonEncode(body);
  if (run['answerCommand'] == digest) {
    return {'questionRequest': _copyMap(question)};
  }
  if (question['status'] != 'pending' ||
      DateTime.now().millisecondsSinceEpoch >=
          (question['deadlineMs'] as int)) {
    throw const _MockBiz(409, 2007, '问题已回答或过期');
  }
  final answers = body['answers'];
  if (answers is! List ||
      answers.length != 1 ||
      body['requestId']?.toString().isEmpty != false) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final answer = answers.single as Map;
  final disposition = answer['disposition'];
  final selected = answer['selectedOptionIds'] as List? ?? [];
  if (answer['questionId'] != 'priority' ||
      !{
        'answered',
        'unknown',
        'no_preference',
        'skipped',
      }.contains(disposition) ||
      selected.any(
        (id) => !{'cost', 'experience', 'maintenance'}.contains(id),
      ) ||
      selected.toSet().length != selected.length ||
      (disposition != 'answered' && selected.isNotEmpty) ||
      (disposition == 'answered' &&
          selected.isEmpty &&
          (answer['text']?.toString().trim() ?? '').isEmpty)) {
    throw const _MockBiz(400, 2, '答案无效');
  }
  question['answers'] = answers;
  question['status'] = 'answered';
  run['answerCommand'] = digest;
  _researchEvent(runId, 'questions_resolved', {
    'questionRequest': _copyMap(question),
  });
  _finishResearch(runId);
  return {'questionRequest': _copyMap(question)};
}

// 生成调研结果：取前两篇已发布帖子作为来源与引用块（无帖子时给出局限说明），
// 依次发出工具调用、工具结果、答案提交与 done 事件，写入回答消息并完成运行。
void _finishResearch(int runId) {
  final run = _assistantRuns[runId]!;
  final userId = run['userId'] as int;
  final sessionId = run['sessionId'] as int;
  final posts = _publishedPosts();
  final messageId = _nextAssistantMessageId++;
  final sources = <Map<String, dynamic>>[];
  final blocks = <Map<String, dynamic>>[];
  if (posts.isEmpty) {
    blocks.add({
      'id': 'b1',
      'kind': 'limitation',
      'text': '社区暂时没有可引用的帖子。',
      'citations': [],
    });
  }
  for (var i = 0; i < posts.length && i < 2; i++) {
    final post = posts[i];
    final handle = 'src-$runId-${post['id']}';
    final evidence = 'ev-$runId-${post['id']}';
    final excerpt = String.fromCharCodes(
      (post['content']?.toString() ?? '').runes.take(360),
    );
    sources.add({
      'handle': handle,
      'kind': 'post',
      'authorityId': '${post['id']}',
      'title': post['title'] ?? '',
      'revision': post['revision'] ?? 1,
      'url': '/post/${post['id']}',
      'thumbnailUrl': (post['images'] as List?)?.firstOrNull ?? '',
      'author': post['authorName'] ?? '',
      'available': true,
      'excerpts': [
        {
          'id': evidence,
          'handle': handle,
          'kind': 'post',
          'text': excerpt,
          'retrievedAtMs': DateTime.now().millisecondsSinceEpoch,
        },
      ],
    });
    blocks.add({
      'id': 'b${i + 1}',
      'kind': 'experience',
      'text': excerpt,
      'citations': [
        {
          'handle': handle,
          'evidenceIds': [evidence],
        },
      ],
    });
  }
  final presentation = {
    'version': 1,
    'runId': runId,
    'messageId': messageId,
    'blocks': blocks,
    'sources': sources,
  };
  final text = blocks.map((block) => block['text']).join('\n\n');
  _researchEvent(runId, 'tool_call', {
    'toolCall': {
      'callId': 'search-$runId',
      'tool': 'search_posts',
      'summary': '检索社区资料',
    },
  });
  _researchEvent(runId, 'tool_result', {
    'toolCall': {
      'callId': 'search-$runId',
      'tool': 'search_posts',
      'summary': '已取得社区资料',
    },
  });
  _researchEvent(runId, 'answer_committed', {
    'text': text,
    'answerPresentation': presentation,
  });
  _researchEvent(runId, 'done', {
    'text': text,
    'answerPresentation': presentation,
  });
  _assistantMessages[userId]!.add({
    'id': messageId,
    'sessionId': sessionId,
    'runId': runId,
    'role': 'assistant',
    'kind': 'message',
    'content': text,
    'unread': false,
    'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    'answerPresentation': presentation,
  });
  _assistantThreads[userId]!.remove('questionRequest');
  _assistantThreads[userId]!.addAll({
    'lastMessageId': messageId,
    'lastMessagePreview': text,
    'lastMessageAtMs': DateTime.now().millisecondsSinceEpoch,
  });
  _completeRun(runId);
}
