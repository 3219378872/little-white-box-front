import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/v2_api_client.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/data/tokens.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('encodes query values and normalizes JWT as Bearer auth', () async {
    final client = _CapturingClient({'items': <Object>[]});
    setApiClient(client);
    await setTokens(
      Tokens(
        accessToken: 'jwt-token',
        accessExpire: 0,
        refreshToken: '',
        refreshExpire: 0,
        refreshAfter: 0,
      ),
    );

    await const V2ApiClient().get(
      '/api/v2/feed/recommend',
      query: {'cursor': 'opaque / + ==', 'pageSize': 20, 'empty': ''},
    );

    expect(client.request?.url.queryParameters, {
      'cursor': 'opaque / + ==',
      'pageSize': '20',
    });
    expect(client.request?.headers['Authorization'], 'Bearer jwt-token');
  });

  test('does not duplicate an existing Bearer prefix', () async {
    final client = _CapturingClient({});
    setApiClient(client);
    await setTokens(
      Tokens(
        accessToken: 'Bearer jwt-token',
        accessExpire: 0,
        refreshToken: '',
        refreshExpire: 0,
        refreshAfter: 0,
      ),
    );

    await const V2ApiClient().post('/api/v2/behavior/events', {});

    expect(client.request?.headers['Authorization'], 'Bearer jwt-token');
  });
}

class _CapturingClient extends http.BaseClient {
  final Map<String, dynamic> response;
  http.BaseRequest? request;

  _CapturingClient(this.response);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(response))),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}
