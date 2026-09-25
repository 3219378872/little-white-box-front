import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_adapter.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    onSessionInvalid = null;
  });
  tearDown(() => setApiClient(http.Client()));

  for (final status in [200, 401]) {
    testWidgets(
      'multipart deadline covers headers and body; ignores late HTTP $status',
      (tester) async {
        await setTokens(
          buildStoredTokens(accessToken: 'access', refreshToken: 'refresh'),
        );
        final headers = Completer<http.StreamedResponse>();
        final body = StreamController<List<int>>();
        var requests = 0;
        var decodedResponses = 0;
        setApiClient(
          _StreamingClient((_) {
            requests++;
            return headers.future;
          }),
        );
        final pending = apiPostMultipart<void>(
          path: '/api/v1/media/image',
          fieldName: 'file',
          filename: 'a.png',
          bytes: [1],
          timeout: const Duration(seconds: 10),
          decodeData: (_) => decodedResponses++,
        );
        final failure = expectLater(
          pending,
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              '请求超时，请重试',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        headers.complete(http.StreamedResponse(body.stream, status));
        await tester.pump();
        // The body only gets the remaining four seconds, not a new deadline.
        await tester.pump(const Duration(seconds: 4));
        await failure;
        body.add(
          utf8.encode(status == 200 ? '{"mediaId":1}' : '{"code":1004}'),
        );
        await body.close();
        await tester.pump();
        expect(requests, 1, reason: 'late 401 must not refresh or retry');
        expect(decodedResponses, 0);
        expect((await getTokens())?.accessToken, 'access');
      },
    );
  }
}

class _StreamingClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  _StreamingClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
