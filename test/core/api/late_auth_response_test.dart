import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_adapter.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/api/v2_api_client.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    onSessionInvalid = null;
  });
  tearDown(() => setApiClient(http.Client()));

  for (final transport in ['SDK', 'multipart', 'SSE']) {
    for (final rejectedAgain in [false, true]) {
      test('$transport late 401 reuses rotated credentials for one retry '
          '(rejected again: $rejectedAgain)', () async {
        await setTokens(
          buildStoredTokens(accessToken: 'a1', refreshToken: 'r1'),
        );
        final original = (await getTokenSnapshot())!;
        final started = Completer<void>();
        final release = Completer<void>();
        final authorizations = <String?>[];
        var refreshes = 0;
        setApiClient(
          _ScriptedClient((request) async {
            if (request.url.path == '/api/v1/auth/refresh') {
              refreshes++;
              return _response('{"token":"a2","refreshToken":"r2"}', 200);
            }
            authorizations.add(request.headers['Authorization']);
            if (authorizations.length == 1) {
              started.complete();
              await release.future;
              return _response('{"code":1004}', 401);
            }
            if (rejectedAgain) return _response('{"code":1005}', 401);
            return _response(
              transport == 'SSE'
                  ? 'data: {"type":"done","runId":123,"seq":1}\n\n'
                  : '{"ok":true}',
              200,
            );
          }),
        );
        final Future<void> request = switch (transport) {
          'SDK' => const V2ApiClient().post('/slow', {}).then((_) {}),
          'multipart' => apiPostMultipart<void>(
            path: '/api/v1/media/image',
            fieldName: 'file',
            filename: 'a.png',
            bytes: [1],
            decodeData: (_) {},
          ),
          _ => AssistantRepository().runEvents(runId: 123).drain<void>(),
        };
        final expectation = expectLater(
          request,
          rejectedAgain ? throwsA(isA<ApiException>()) : completes,
        );
        await started.future;
        // Another request completes its refresh before this one's 401 arrives.
        expect(
          await refreshSessionTokensFor(original),
          SessionRefreshResult.refreshed,
        );
        expect((await getTokenSnapshot())?.revision, original.revision);
        release.complete();
        await expectation;
        expect(authorizations, ['Bearer a1', 'Bearer a2']);
        expect(refreshes, 1, reason: 'no second refresh for a late 401');
        expect((await getTokens())?.accessToken, rejectedAgain ? isNull : 'a2');
      });
    }
  }
}

class _ScriptedClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  _ScriptedClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

http.StreamedResponse _response(String body, int status) =>
    http.StreamedResponse(Stream.value(utf8.encode(body)), status);
