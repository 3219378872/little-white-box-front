import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';

void main() {
  test('parses fragmented token, source, and done SSE events', () async {
    final payload = [
      'data: {"type":"token","text":"你","conversationId":"c-1"}\n\n',
      'data: {"type":"source","source":{"sourceType":"post","sourceId":"7","title":"Source"},"conversationId":"c-1"}\n\n',
      'data: {"type":"done","conversationId":"c-1"}\n\n',
    ].join();
    final bytes = utf8.encode(payload);
    final client = _CapturingClient(
      (_) => http.StreamedResponse(
        Stream<List<int>>.fromIterable([
          bytes.sublist(0, 13),
          bytes.sublist(13, 31),
          bytes.sublist(31, 77),
          bytes.sublist(77),
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

    final events = await repository
        .chat(message: ' hello ', requestId: 'request-1', conversationId: 'c-0')
        .toList();

    expect(events.map((event) => event.type), [
      AssistantEventType.token,
      AssistantEventType.source,
      AssistantEventType.done,
    ]);
    expect(events[0].text, '你');
    expect(events[1].source?.sourceId, '7');
    expect(
      client.request?.url.toString(),
      'http://gateway.test/api/v2/assistant/chat',
    );
    expect(client.request?.headers['Authorization'], 'Bearer jwt-token');
    expect(client.request?.headers['Accept'], 'text/event-stream');
    expect(jsonDecode(client.request!.body), {
      'conversationId': 'c-0',
      'message': 'hello',
      'requestId': 'request-1',
      'mode': 'enhanced_search',
    });
  });

  test('reports a closed stream without a terminal event', () async {
    final client = _CapturingClient(
      (_) => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            'data: {"type":"token","text":"partial","conversationId":"c"}\n\n',
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
      repository.chat(message: 'hello', requestId: 'request-1').toList(),
      throwsA(
        isA<AssistantStreamException>().having(
          (error) => error.message,
          'message',
          contains('中断'),
        ),
      ),
    );
  });

  test('parses a structured error event as a terminal response', () async {
    final client = _CapturingClient(
      (_) => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            'data: {"type":"error","text":"quota reached","degraded":true,"errorCode":"QUOTA_EXCEEDED","conversationId":"c"}\n\n',
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

    final events = await repository
        .chat(message: 'hello', requestId: 'request-1')
        .toList();

    expect(events.single.type, AssistantEventType.error);
    expect(events.single.errorCode, 'QUOTA_EXCEEDED');
    expect(events.single.degraded, isTrue);
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
      final subscription = repository
          .chat(message: 'hello', requestId: 'request-1')
          .listen((event) {
            if (!token.isCompleted) token.complete();
          });

      await Future<void>.delayed(Duration.zero);
      controller.add(
        utf8.encode(
          'data: {"type":"token","text":"partial","conversationId":"c"}\n\n',
        ),
      );
      await token.future;
      await subscription.cancel();

      await expectLater(canceled.future, completes);
    },
  );
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
