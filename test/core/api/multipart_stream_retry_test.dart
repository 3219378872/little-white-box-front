import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_adapter.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

class Client extends http.BaseClient {
  int uploads = 0;
  final bodies = <String>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) async {
    final body = utf8.decode(await r.finalize().toBytes());
    if (r.url.path.endsWith('/auth/refresh')) {
      return response('{"token":"a2","refreshToken":"r2"}', 200);
    }
    bodies.add(body);
    uploads++;
    return uploads == 1
        ? response('{"code":1004}', 401)
        : response('{"mediaId":1}', 200);
  }

  http.StreamedResponse response(String b, int s) =>
      http.StreamedResponse(Stream.value(utf8.encode(b)), s);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('401 reopens stream and keeps upload key and bytes', () async {
    SharedPreferences.setMockInitialValues({});
    onSessionInvalid = null;
    await setTokens(buildStoredTokens(accessToken: 'a1', refreshToken: 'r1'));
    final client = Client();
    setApiClient(client);
    var opens = 0;
    try {
      final id = await apiPostMultipart<int>(
        path: '/api/v1/media/audio',
        fieldName: 'file',
        filename: 'a.wav',
        openRead: () {
          opens++;
          return Stream.value(utf8.encode('file-payload'));
        },
        length: 12,
        fields: {'idempotencyKey': 'stable-key'},
        decodeData: (d) => d['mediaId'] as int,
      );
      expect(id, 1);
      expect(opens, 2);
      expect(client.uploads, 2);
      for (final body in client.bodies) {
        expect(body, contains('stable-key'));
        expect(body, contains('file-payload'));
      }
    } finally {
      setApiClient(http.Client());
    }
  });
}
