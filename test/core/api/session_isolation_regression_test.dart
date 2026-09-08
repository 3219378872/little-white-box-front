import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the already-installed plugin's persistence completion boundary.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:xiaobaihe_app/core/api/api_adapter.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/api/v2_api_client.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

class _SwitchOnRefreshStore extends InMemorySharedPreferencesStore {
  final Future<void> Function() switchSession;
  bool switched = false;
  Future<void>? mutation;

  _SwitchOnRefreshStore(this.switchSession) : super.empty();

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    final result = await super.setValue(type, key, value);
    if (!switched &&
        key == 'flutter.tokens' &&
        value is String &&
        jsonDecode(value)['access_token'] == 'a-refreshed') {
      switched = true;
      mutation = switchSession();
    }
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    onSessionInvalid = null;
  });

  for (final transport in ['SDK', 'multipart', 'SSE']) {
    for (final logout in [false, true]) {
      test(
        '$transport never retries an old command after ${logout ? 'logout' : 'account switch'} during refresh persistence',
        () async {
          final store = _SwitchOnRefreshStore(() async {
            if (logout) {
              await removeTokens();
            } else {
              await setTokens(
                buildStoredTokens(
                  accessToken: 'b-access',
                  refreshToken: 'b-refresh',
                ),
              );
            }
          });
          SharedPreferencesStorePlatform.instance = store;
          await setTokens(
            buildStoredTokens(
              accessToken: 'a-access',
              refreshToken: 'a-refresh',
            ),
          );
          final authorizations = <String?>[];
          setApiClient(
            MockClient((request) async {
              if (request.url.path == '/api/v1/auth/refresh') {
                return http.Response(
                  '{"token":"a-refreshed","refreshToken":"a-new-refresh"}',
                  200,
                );
              }
              authorizations.add(request.headers['Authorization']);
              return http.Response('', 401);
            }),
          );
          final Future<void> operation = switch (transport) {
            'SDK' => const V2ApiClient().post('/api/v2/assistant/messages', {
              'message': 'A',
            }),
            'multipart' => apiPostMultipart<void>(
              path: '/api/v1/media/image',
              fieldName: 'file',
              filename: 'a.png',
              bytes: [1],
              decodeData: (_) {},
            ),
            _ => AssistantRepository().runEvents(runId: 123).drain<void>(),
          };
          await expectLater(
            operation,
            throwsA(
              isA<ApiException>().having(
                (error) => error.message,
                'message',
                contains('会话已变化'),
              ),
            ),
          );
          await store.mutation;
          expect(authorizations, ['Bearer a-access']);
          expect(
            (await getTokens())?.accessToken,
            logout ? isNull : 'b-access',
          );
        },
      );
    }
  }

  test(
    'an explicitly bound anonymous command cannot adopt a new login',
    () async {
      final original = await getTokenSessionContext();
      await setTokens(
        buildStoredTokens(accessToken: 'b-access', refreshToken: ''),
      );
      var sent = false;
      setApiClient(
        MockClient((_) async {
          sent = true;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        const V2ApiClient().post(
          '/api/v2/behavior/events',
          {},
          expectedSessionRevision: original.revision,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(sent, isFalse);
    },
  );
}
