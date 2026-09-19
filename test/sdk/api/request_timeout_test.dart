import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

import '../../helpers/gateway_fake.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    onSessionInvalid = null;
  });
  tearDown(() => setApiClient(http.Client()));

  for (final method in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
    testWidgets('$method has a deadline and ignores late success', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      setApiClient(ScriptedGatewayClient((_) => response.future));
      var successes = 0;
      var finished = 0;
      final errors = <String>[];
      final pending = _request(
        method,
        ok: (_) => successes++,
        fail: errors.add,
        eventually: () => finished++,
      );
      await tester.pump();
      await tester.pump(apiRequestTimeout);
      await pending;
      expect(ApiException.parse(errors.single).message, '请求超时，请重试');
      expect(finished, 1);
      expect(successes, 0);
      response.complete(jsonResponse(okEnvelope({'late': true})));
      await tester.pump();
      expect(successes, 0);
      expect(finished, 1);
    });
  }

  testWidgets('deadline includes a stalled response body', (tester) async {
    final body = StreamController<List<int>>();
    setApiClient(_StreamingClient(body.stream));
    String? failure;
    final pending = apiGet('/slow-body', fail: (error) => failure = error);
    await tester.pump();
    await tester.pump(apiRequestTimeout);
    await pending;
    expect(ApiException.parse(failure!).message, '请求超时，请重试');
    body.add([123, 125]);
    await body.close();
    await tester.pump();
  });

  testWidgets(
    'refresh timeout releases all waiters, retains tokens and permits another refresh',
    (tester) async {
      await setTokens(
        buildStoredTokens(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        ),
      );
      final snapshot = (await getTokenSnapshot())!;
      final old = Completer<http.Response>();
      var refreshes = 0;
      var invalidations = 0;
      onSessionInvalid = (_) async => invalidations++;
      final client = ScriptedGatewayClient((request) async {
        refreshes++;
        if (refreshes == 1) return old.future;
        return jsonResponse(
          okEnvelope({'token': 'new-access', 'refreshToken': 'new-refresh'}),
        );
      });
      setApiClient(client);
      expect(snapshot.tokens.refreshToken, 'old-refresh');
      final first = refreshSessionTokensFor(snapshot);
      final second = refreshSessionTokensFor(snapshot);
      await tester.pump();
      expect(
        refreshes,
        1,
        reason: 'Requests: ${client.requests.map((r) => r.url)}',
      );
      expect(client.requests.single.url.path, '/api/v1/auth/refresh');
      await tester.pump(apiRequestTimeout);
      expect(await first, SessionRefreshResult.unavailable);
      expect(await second, SessionRefreshResult.unavailable);
      expect((await getTokens())!.refreshToken, 'old-refresh');
      expect(invalidations, 0);
      final retry = refreshSessionTokensFor(snapshot);
      await tester.pump();
      expect(await retry, SessionRefreshResult.refreshed);
      expect(refreshes, 2);
      old.complete(
        jsonResponse(
          okEnvelope({'token': 'late-access', 'refreshToken': 'late-refresh'}),
        ),
      );
      await tester.pump();
      expect((await getTokens())!.accessToken, 'new-access');
      expect((await getTokens())!.refreshToken, 'new-refresh');
      onSessionInvalid = null;
    },
  );
}

Future<dynamic> _request(
  String method, {
  required void Function(Map<String, dynamic>) ok,
  required void Function(String) fail,
  required void Function() eventually,
}) => switch (method) {
  'POST' => apiPost('/slow', {}, ok: ok, fail: fail, eventually: eventually),
  'PUT' => apiPut('/slow', {}, ok: ok, fail: fail, eventually: eventually),
  'PATCH' => apiPatch('/slow', {}, ok: ok, fail: fail, eventually: eventually),
  'DELETE' => apiDelete(
    '/slow',
    {},
    ok: ok,
    fail: fail,
    eventually: eventually,
  ),
  _ => apiGet('/slow', ok: ok, fail: fail, eventually: eventually),
};

class _StreamingClient extends http.BaseClient {
  final Stream<List<int>> body;
  _StreamingClient(this.body);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(body, 200);
}
