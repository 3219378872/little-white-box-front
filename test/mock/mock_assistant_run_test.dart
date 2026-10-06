import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart' as mock;

// 普通 Agent 运行的 mock 生命周期：取消须像服务端一样以 cancelled 终结，
// 而不是被随后的完成收尾改写为 completed。
void main() {
  setUp(mock.resetMockState);

  mock.MockRouterResponse request(
    String method,
    String path, [
    Map<String, dynamic> body = const {},
  ]) => mock.dispatchResponse(
    method,
    path,
    jsonEncode(body),
    headers: {
      'content-type': 'application/json',
      'Authorization': 'Bearer ${mock.mockAccessTokenForUser(1)}',
    },
  );

  // 发送一条普通消息并返回新运行 ID。
  Object start(String message) {
    final accepted = jsonDecode(
      request('POST', '/api/v2/assistant/messages', {
        'message': message,
        'requestId': 'req-$message',
      }).body,
    ) as Map<String, dynamic>;
    return accepted['runId'] as Object;
  }

  // 解析运行的 SSE 事件体。
  List<Map<String, dynamic>> events(Object runId) => [
    for (final line in LineSplitter.split(
      request('GET', '/api/v2/assistant/runs/$runId/events').body,
    ))
      if (line.startsWith('data: '))
        jsonDecode(line.substring(6)) as Map<String, dynamic>,
  ];

  test('cancelling a running run ends it as cancelled exactly once', () {
    final runId = start('hang on');
    expect(events(runId).last['type'], isNot('error'));

    expect(
      request('POST', '/api/v2/assistant/runs/$runId/cancel').statusCode,
      200,
    );
    final terminal = events(runId).last;
    expect(terminal['type'], 'error');
    expect(terminal['errorCode'], 'CANCELLED');
    final thread =
        jsonDecode(request('GET', '/api/v2/assistant/thread').body)['thread']
            as Map;
    expect(thread['activeRunId'], 0);

    // 已是 cancelled 的运行再次取消不追加终止事件。
    final count = events(runId).length;
    request('POST', '/api/v2/assistant/runs/$runId/cancel');
    expect(events(runId), hasLength(count));
  });

  test('cancelling a finished run keeps its done terminal', () {
    final runId = start('finished question');
    expect(events(runId).last['type'], 'done');

    request('POST', '/api/v2/assistant/runs/$runId/cancel');
    expect(events(runId).last['type'], 'done');
  });
  group('delete confirmation', () {
    // 返回某运行中指定调用的 tool_result 结果码列表。
    List<Object?> outcomes(Object runId) => [
      for (final event in events(runId))
        if (event['type'] == 'tool_result' &&
            (event['toolCall'] as Map)['callId'] == 'mock-call-delete')
          (event['toolCall'] as Map)['summary'],
    ];

    int confirm(Object runId, bool approved) => request(
      'POST',
      '/api/v2/assistant/runs/$runId/confirm',
      {'callId': 'mock-call-delete', 'approved': approved},
    ).statusCode;

    test('a delete run waits for confirmation without finishing', () {
      final runId = start('删除帖子');
      expect(events(runId).last['type'], 'confirm_required');
    });

    test('rejecting hands the call back as rejected and finishes', () {
      final runId = start('删除帖子');
      expect(confirm(runId, false), 200);
      expect(outcomes(runId), ['rejected']);
      expect(events(runId).last['type'], 'done');
      final thread =
          jsonDecode(request('GET', '/api/v2/assistant/thread').body)['thread']
              as Map;
      expect(thread['activeRunId'], 0);
      // 已结清的确认不能再次提交。
      expect(confirm(runId, true), 400);
      expect(outcomes(runId), ['rejected']);
    });

    test('approving finishes the call as success', () {
      final runId = start('删除帖子');
      expect(confirm(runId, true), 200);
      expect(outcomes(runId), ['success']);
      expect(events(runId).last['type'], 'done');
    });

    test(
      'an expired confirmation finishes as expired and rejects approval',
      () {
        final runId = start('删除帖子 expire-confirm');
        expect(outcomes(runId), ['expired']);
        expect(events(runId).last['type'], 'done');
        expect(confirm(runId, true), 400);
        expect(outcomes(runId), ['expired']);
      },
    );
  });
}
