import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart' as mock;

void main() {
  setUp(mock.resetMockState);
  mock.MockRouterResponse request(
    String method,
    String path, [
    Map<String, dynamic> body = const {},
    int userId = 1,
  ]) => mock.dispatchResponse(
    method,
    path,
    jsonEncode(body),
    headers: {
      'content-type': 'application/json',
      'Authorization': 'Bearer ${mock.mockAccessTokenForUser(userId)}',
    },
  );
  Map<String, dynamic> decode(mock.MockRouterResponse response) =>
      jsonDecode(response.body) as Map<String, dynamic>;
  test(
    'research mock waits for real choices and preserves answer snapshots',
    () {
      expect(
        request('POST', '/api/v2/assistant/consent', {
          'granted': true,
        }).statusCode,
        200,
      );
      final accepted = decode(
        request('POST', '/api/v2/assistant/messages', {
          'message': '比较社区中的方案',
          'requestId': 'research-1',
          'clientProtocolVersion': 2,
        }),
      );
      final runId = accepted['runId'];
      final thread =
          decode(request('GET', '/api/v2/assistant/thread'))['thread'] as Map;
      expect(thread['activeRunPhase'], 'waiting_input');
      final question = thread['questionRequest'] as Map;
      final before = request('GET', '/api/v2/assistant/runs/$runId/events');
      expect(before.body, contains('questions_required'));
      expect(before.body, isNot(contains('answer_committed')));
      final command = {
        'questionRequestId': question['id'],
        'requestId': 'answer-1',
        'answers': [
          {
            'questionId': 'priority',
            'disposition': 'unknown',
            'selectedOptionIds': [],
            'text': '',
          },
        ],
      };
      expect(
        request(
          'POST',
          '/api/v2/assistant/runs/$runId/answers',
          command,
          2,
        ).statusCode,
        404,
      );
      expect(
        request(
          'POST',
          '/api/v2/assistant/runs/$runId/answers',
          command,
        ).statusCode,
        200,
      );
      expect(
        request(
          'POST',
          '/api/v2/assistant/runs/$runId/answers',
          command,
        ).statusCode,
        200,
      );
      expect(
        request('POST', '/api/v2/assistant/runs/$runId/answers', {
          ...command,
          'requestId': 'different',
        }).statusCode,
        409,
      );
      final history =
          decode(request('GET', '/api/v2/assistant/messages'))['messages']
              as List;
      expect(
        history.where((message) => message['answerPresentation'] != null),
        hasLength(1),
      );
      final replay = request('GET', '/api/v2/assistant/runs/$runId/events');
      expect(replay.body, contains('answer_committed'));
    },
  );
}
