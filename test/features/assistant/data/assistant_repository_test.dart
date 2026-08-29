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
