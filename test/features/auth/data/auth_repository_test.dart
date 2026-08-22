import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/features/auth/data/auth_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../helpers/gateway_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  test('password login posts the loginType=1 contract', () async {
    final client = ScriptedGatewayClient.always({
      'userId': 1,
      'token': 'access-1',
      'refreshToken': 'refresh-1',
    });
    setApiClient(client);
    final repository = AuthRepository();

    final resp = await repository.loginWithPassword('admin', '123456');

    final request = client.requests.single as http.Request;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/auth/login');
    expect(jsonBodyOf(request), {
      'username': 'admin',
      'password': '123456',
      'phone': '',
      'verifyCode': '',
      'loginType': 1,
    });
    expect(resp.userId, 1);
    expect(resp.token, 'access-1');
    expect(resp.refreshToken, 'refresh-1');
  });

  test('verify-code login switches to loginType=2', () async {
    final client = ScriptedGatewayClient.always({'userId': 2});
    setApiClient(client);
    final repository = AuthRepository();

    await repository.loginWithVerifyCode('13800000000', '246810');

    expect(jsonBodyOf(client.requests.single as http.Request), {
      'username': '',
      'password': '',
      'phone': '13800000000',
      'verifyCode': '246810',
      'loginType': 2,
    });
  });

  test('register and sendCode use the auth verify-code endpoints', () async {
    final client = ScriptedGatewayClient.always({
      'userId': 9,
      'token': 't',
      'refreshToken': 'r',
    });
    setApiClient(client);
    final repository = AuthRepository();

    final registered = await repository.registerUser(
      username: 'neo',
      password: 'secret',
      phone: '13800000001',
      verifyCode: '123456',
    );
    await repository.sendCode('13800000002', 2);

    expect(client.requests[0].url.path, '/api/v1/auth/register');
    expect(jsonBodyOf(client.requests[0] as http.Request), {
      'username': 'neo',
      'password': 'secret',
      'phone': '13800000001',
      'verifyCode': '123456',
    });
    expect(registered.userId, 9);

    expect(client.requests[1].method, 'POST');
    expect(client.requests[1].url.path, '/api/v1/auth/verify-code');
    expect(jsonBodyOf(client.requests[1] as http.Request), {
      'phone': '13800000002',
      'type': 2,
    });
  });

  test('business failures surface as ApiException with the gateway code',
      () async {
    final client = ScriptedGatewayClient((request) async => jsonResponse(
          {'code': 1003, 'message': '密码错误'},
          401,
        ));
    setApiClient(client);
    final repository = AuthRepository();

    await expectLater(
      repository.loginWithPassword('admin', 'wrong'),
      throwsA(isA<ApiException>()
          .having((error) => error.code, 'code', 1003)
          .having((error) => error.message, 'message', '密码错误')),
    );
  });
}
