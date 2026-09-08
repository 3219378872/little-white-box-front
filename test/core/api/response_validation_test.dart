import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/api/v2_api_client.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final body in [
    '',
    '<html>not an API</html>',
    '{',
    'null',
    '[]',
    '42',
    '{"code":6,"message":"unavailable"}',
    '{"code":"bad"}',
    '{"data":[]}',
    '{"data":null}',
  ]) {
    test('rejects malformed or failed HTTP 200 body: $body', () async {
      await setTokens(
        buildStoredTokens(accessToken: 'access', refreshToken: ''),
      );
      setApiClient(MockClient((_) async => http.Response(body, 200)));
      final repository = AssistantRepository();
      await expectLater(
        repository.cancelRun(123),
        throwsA(isA<ApiException>()),
      );
      await expectLater(repository.listMemory(), throwsA(isA<ApiException>()));
      await expectLater(repository.listWatches(), throwsA(isA<ApiException>()));
      await expectLater(
        repository.markThreadRead(),
        throwsA(isA<ApiException>()),
      );
      expect((await getTokens())?.accessToken, 'access');
    });
  }
  for (final body in ['{}', '{"code":0,"data":{}}', '{"code":0,"data":null}']) {
    test('accepts a valid void response: $body', () async {
      setApiClient(MockClient((_) async => http.Response(body, 200)));
      await AssistantRepository().cancelRun(123);
      expect(await const V2ApiClient().post('/void', {}), isEmpty);
    });
  }
  test(
    'missing list and unread fields are not successful empty states',
    () async {
      setApiClient(MockClient((_) async => http.Response('{}', 200)));
      final repository = AssistantRepository();
      await expectLater(repository.listMemory(), throwsA(isA<ApiException>()));
      await expectLater(repository.listWatches(), throwsA(isA<ApiException>()));
      await expectLater(
        repository.listMessages(),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        repository.markThreadRead(),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test('explicit Go nil slices remain valid empty lists', () async {
    setApiClient(
      MockClient(
        (_) async => http.Response(
          '{"items":null,"capacities":null,"tasks":null,"messages":null,"unreadCount":0}',
          200,
        ),
      ),
    );
    final repository = AssistantRepository();
    expect((await repository.listMemory()).$1, isEmpty);
    expect(await repository.listWatches(), isEmpty);
    expect((await repository.listMessages()).messages, isEmpty);
    expect(await repository.markThreadRead(), 0);
  });
}
