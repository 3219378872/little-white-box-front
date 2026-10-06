import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

// 断言用户看到的是中文文案，英文诊断（FormatException、ClientException、类型转换）不外泄。
Matcher _userMessage(String message) =>
    isA<ApiException>().having((error) => error.message, 'message', message);

// 所有 REST 请求都返回同一份成功信封里的 [data]。
void _respondWith(Map<String, dynamic> data) {
  setApiClient(
    MockClient(
      (_) async => http.Response(
        jsonEncode({'code': 0, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  );
}

// 事件流客户端：直接用注入的 http.Client，绕开存储里的会话。
AssistantRepository _streamRepository(http.Client client) =>
    AssistantRepository(
      client: client,
      baseUrl: 'http://gateway.test',
      loadAccessToken: () async => 'test-token',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  test('a malformed history message is reported in Chinese', () async {
    _respondWith({
      'messages': [
        {'role': 'assistant'},
      ],
    });
    await expectLater(
      AssistantRepository().listMessages(),
      throwsA(_userMessage('Assistant 消息响应格式无效')),
    );
  });

  test('a malformed thread question is reported in Chinese', () async {
    _respondWith({
      'thread': {'questionRequest': <String, dynamic>{}},
    });
    await expectLater(
      AssistantRepository().getThread(),
      throwsA(_userMessage('Assistant 线程响应格式无效')),
    );
  });

  test(
    'an answer response without a question is reported in Chinese',
    () async {
      _respondWith(const {});
      await expectLater(
        AssistantRepository().answerQuestions(
          question: AssistantQuestionRequest.fromJson({
            'id': 'q1',
            'runId': 21,
          }),
          requestId: 'r1',
          answers: const [],
        ),
        throwsA(_userMessage('Assistant 提问响应格式无效')),
      );
    },
  );

  test('a stream connection failure hides the client exception', () async {
    final repository = _streamRepository(
      MockClient((_) async => throw http.ClientException('Connection refused')),
    );
    await expectLater(
      repository.runEvents(runId: 21).toList(),
      throwsA(
        isA<AssistantStreamException>()
            .having(
              (error) => error.message,
              'message',
              '无法连接 Assistant：网络连接失败，请检查网络后重试',
            )
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('a stream interrupted mid-way hides the client exception', () async {
    final repository = _streamRepository(
      MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream<List<int>>.error(http.ClientException('Connection closed')),
          200,
        ),
      ),
    );
    await expectLater(
      repository.runEvents(runId: 21).toList(),
      throwsA(
        isA<AssistantStreamException>()
            .having((error) => error.message, 'message', 'Assistant 连接中断，请重试')
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('a non-gateway rejection page is not shown verbatim', () async {
    final repository = _streamRepository(
      MockClient((_) async => http.Response('<html>Forbidden</html>', 403)),
    );
    await expectLater(
      repository.runEvents(runId: 21).toList(),
      throwsA(
        isA<AssistantStreamException>()
            .having((error) => error.message, 'message', '请求失败，请稍后重试')
            .having((error) => error.retryable, 'retryable', isFalse),
      ),
    );
  });
}
