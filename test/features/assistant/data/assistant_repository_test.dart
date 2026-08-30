import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_adapter.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    onAuthError = null;
    setApiClient(http.Client());
  });

  test('parses fragmented token, source_card, and done SSE events', () async {
    final payload = [
      'id: 1\ndata: {"type":"token","text":"你","runId":21,"seq":1}\n\n',
      'id: 2\ndata: {"type":"source_card","sourceCard":{"handle":"src-7","kind":"post","authorityId":"7","title":"Source","revision":3},"runId":21,"seq":2}\n\n',
      'id: 3\ndata: {"type":"done","runId":21,"seq":3}\n\n',
    ].join();
    final bytes = utf8.encode(payload);
    final client = _CapturingClient(
      (_) => http.StreamedResponse(
        Stream<List<int>>.fromIterable([
          bytes.sublist(0, 13),
          bytes.sublist(13, 40),
          bytes.sublist(40),
        ]),
        200,
        headers: const {'content-type': 'text/event-stream'},
      ),
    );
    final repository = AssistantRepository(
      client: client,
      baseUrl: 'http://gateway.test',
      loadAccessToken: () async => 'jwt-token',
    );

    final events = await repository.runEvents(runId: 21, afterSeq: 4).toList();

    expect(events.map((event) => event.type), [
      AssistantEventType.token,
      AssistantEventType.sourceCard,
      AssistantEventType.done,
    ]);
    expect(events[0].text, '你');
    expect(events[1].sourceCard?.authorityId, '7');
    expect(
      client.request?.url.toString(),
      'http://gateway.test/api/v2/assistant/runs/21/events?afterSeq=4',
    );
    expect(client.request?.headers['Authorization'], 'Bearer jwt-token');
    expect(client.request?.headers['Accept'], 'text/event-stream');
    expect(client.request?.headers['Last-Event-ID'], '4');
  });

  test('parses response reset and replacement stream ids', () async {
    final client = _CapturingClient(
      (_) => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            [
              'data: {"type":"token","text":"partial","streamId":"attempt-1","seq":1}\n\n',
              'data: {"type":"response_reset","streamId":"attempt-1","seq":2}\n\n',
              'data: {"type":"token","text":"final","streamId":"attempt-2","seq":3}\n\n',
              'data: {"type":"done","seq":4}\n\n',
            ].join(),
          ),
        ),
        200,
      ),
    );
    final repository = AssistantRepository(
      client: client,
      baseUrl: 'http://gateway.test',
      loadAccessToken: () async => null,
    );

    final events = await repository.runEvents(runId: 21).toList();

    expect(events.map((event) => event.type), [
      AssistantEventType.token,
      AssistantEventType.responseReset,
      AssistantEventType.token,
      AssistantEventType.done,
    ]);
    expect(events[0].streamId, 'attempt-1');
    expect(events[1].streamId, 'attempt-1');
    expect(events[2].streamId, 'attempt-2');
  });

  test('rejects response reset without a stream id', () async {
    final client = _CapturingClient(
      (_) => http.StreamedResponse(
        Stream.value(
          utf8.encode('data: {"type":"response_reset","seq":1}\n\n'),
        ),
        200,
      ),
    );
    final repository = AssistantRepository(
      client: client,
      baseUrl: 'http://gateway.test',
      loadAccessToken: () async => null,
    );

    await expectLater(
      repository.runEvents(runId: 21).toList(),
      throwsA(
        isA<AssistantStreamException>().having(
          (error) => error.message,
          'message',
          contains('无效事件'),
        ),
      ),
    );
  });

  test('reports a closed stream without a terminal event', () async {
    final client = _CapturingClient(
      (_) => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            'data: {"type":"token","text":"partial","runId":21,"seq":1}\n\n',
          ),
        ),
        200,
      ),
    );
    final repository = AssistantRepository(
      client: client,
      baseUrl: 'http://gateway.test',
      loadAccessToken: () async => null,
    );

    await expectLater(
      repository.runEvents(runId: 21).toList(),
      throwsA(
        isA<AssistantStreamException>().having(
          (error) => error.message,
          'message',
          contains('中断'),
        ),
      ),
    );
  });

  test('skips unknown SSE types instead of terminating the stream', () async {
    final client = _CapturingClient(
      (_) => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            [
              'data: {"type":"future_event","text":"ignore me"}\n\n',
              'data: {"type":"token","text":"ok","seq":1}\n\n',
              'data: {"type":"done","seq":2}\n\n',
            ].join(),
          ),
        ),
        200,
      ),
    );
    final repository = AssistantRepository(
      client: client,
      baseUrl: 'http://gateway.test',
      loadAccessToken: () async => null,
    );

    final events = await repository.runEvents(runId: 21).toList();
    expect(events.map((event) => event.type), [
      AssistantEventType.token,
      AssistantEventType.done,
    ]);
  });

  test('parses a structured error event as a terminal response', () async {
    final client = _CapturingClient(
      (_) => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            'data: {"type":"error","text":"quota reached","degraded":true,"errorCode":"QUOTA_EXCEEDED"}\n\n',
          ),
        ),
        200,
      ),
    );
    final repository = AssistantRepository(
      client: client,
      baseUrl: 'http://gateway.test',
      loadAccessToken: () async => null,
    );

    final events = await repository.runEvents(runId: 21).toList();
    expect(events.single.type, AssistantEventType.error);
    expect(events.single.errorCode, 'QUOTA_EXCEEDED');
  });

  test('post sends contextPostId with requestId and attachments', () async {
    late Map<String, dynamic> body;
    final apiClient = _JsonApiClient((request) async {
      body = Map<String, dynamic>.from(
        jsonDecode(request.body) as Map<String, dynamic>,
      );
      return http.Response(
        jsonEncode({
          'messageId': 11,
          'sessionId': 12,
          'runId': 13,
          'disposition': 'started',
        }),
        200,
      );
    });
    setApiClient(apiClient);
    final repository = AssistantRepository();

    await repository.postMessage(
      message: 'explain this post',
      requestId: 'request-1',
      contextPostId: '9007199254740993',
      attachments: const [
        AssistantAttachment(mediaId: 7, url: 'https://media/7'),
      ],
    );

    expect(body['requestId'], 'request-1');
    expect(body['contextPostId'].toString(), '9007199254740993');
    expect(body['attachments'], hasLength(1));
  });

  test('message cursors use beforeId and afterId exclusively', () async {
    final requests = <Uri>[];
    final apiClient = _JsonApiClient((request) async {
      requests.add(request.url);
      return http.Response(
        jsonEncode({
          'messages': [
            {'id': 9, 'sessionId': 2, 'role': 'assistant', 'content': 'hi'},
          ],
          'hasMore': true,
          'nextBeforeId': 9,
        }),
        200,
      );
    });
    setApiClient(apiClient);
    final repository = AssistantRepository();

    final initial = await repository.listMessages(sessionId: 2);
    final older = await repository.listMessages(sessionId: 2, beforeId: 9);
    final newer = await repository.listMessages(sessionId: 2, afterId: 9);

    expect(initial.hasMore, isTrue);
    expect(initial.nextBeforeId, 9);
    expect(requests[0].queryParameters, isNot(contains('beforeId')));
    expect(requests[1].queryParameters['beforeId'], '9');
    expect(requests[1].queryParameters, isNot(contains('afterId')));
    expect(requests[2].queryParameters['afterId'], '9');
    expect(requests[2].queryParameters, isNot(contains('beforeId')));
    await expectLater(
      repository.listMessages(beforeId: 9, afterId: 10),
      throwsA(isA<ApiException>()),
    );
    expect(older.messages.single.id, 9);
    expect(newer.messages.single.id, 9);
  });

  test(
    'canceling the event subscription cancels the HTTP body stream',
    () async {
      final canceled = Completer<void>();
      final controller = StreamController<List<int>>(
        onCancel: () {
          if (!canceled.isCompleted) canceled.complete();
        },
      );
      addTearDown(controller.close);
      final client = _CapturingClient(
        (_) => http.StreamedResponse(controller.stream, 200),
      );
      final repository = AssistantRepository(
        client: client,
        baseUrl: 'http://gateway.test',
        loadAccessToken: () async => null,
      );
      final token = Completer<void>();
      final subscription = repository.runEvents(runId: 21).listen((event) {
        if (!token.isCompleted) token.complete();
      });

      await Future<void>.delayed(Duration.zero);
      controller.add(
        utf8.encode('data: {"type":"token","text":"partial","seq":1}\n\n'),
      );
      await token.future;
      await subscription.cancel();

      await expectLater(canceled.future, completes);
    },
  );

  test('refresh network failure keeps Assistant session', () async {
    var authError = false;
    onAuthError = () async {
      authError = true;
    };
    final client = _RoutingClient((request) async {
      if (request.url.path == '/api/v1/auth/refresh') {
        throw http.ClientException('network down', request.url);
      }
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(jsonEncode({'code': 1004, 'message': 'token expired'})),
        ),
        401,
      );
    });
    setApiClient(client);
    await setTokens(
      buildStoredTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );
    final repository = AssistantRepository(baseUrl: 'http://gateway.test');

    await expectLater(
      repository.runEvents(runId: 21).toList(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('会话刷新失败'),
        ),
      ),
    );

    expect(authError, isFalse);
    expect((await getTokens())?.refreshToken, 'refresh-1');
  });
}

class _CapturingClient extends http.BaseClient {
  final http.StreamedResponse Function(http.Request) response;
  http.Request? request;

  _CapturingClient(this.response);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request as http.Request;
    return response(this.request!);
  }
}

class _RoutingClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;

  _RoutingClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() {}
}

class _JsonApiClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request) handler;

  _JsonApiClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final copied = request as http.Request;
    final response = await handler(copied);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
