import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/profile/data/personalization_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../helpers/gateway_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  test('reads and writes the v2 me personalization preference', () async {
    final client = ScriptedGatewayClient.always(<String, dynamic>{
      'enabled': true,
      'optedOutAt': 0,
    });
    setApiClient(client);
    final repository = PersonalizationRepository();

    final preference = await repository.getPreference();
    await repository.setPreference(enabled: false);

    expect(preference.enabled, isTrue);

    final getCall = client.requests[0];
    expect(getCall.method, 'GET');
    expect(getCall.url.path, '/api/v2/me/personalization');

    final putCall = client.requests[1] as http.Request;
    expect(putCall.method, 'PUT');
    expect(putCall.url.path, '/api/v2/me/personalization');
    expect(jsonBodyOf(putCall), {'enabled': false});
  });
}
