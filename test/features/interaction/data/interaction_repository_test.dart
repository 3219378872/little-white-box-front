import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/interaction/data/interaction_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../helpers/gateway_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  test('like and unlike share the v1 like endpoint with typed bodies',
      () async {
    final client = ScriptedGatewayClient.always(<String, dynamic>{});
    setApiClient(client);
    final repository = InteractionRepository();

    await repository.likeTarget('348206251022356480', 1);
    await repository.unlikeTarget('348206251022356480', 1);

    expect(client.requests[0].method, 'POST');
    expect(client.requests[0].url.path, '/api/v1/like');
    expect(jsonBodyOf(client.requests[0] as http.Request), {
      'targetId': '348206251022356480',
      'targetType': 1,
    });
    expect(client.requests[1].method, 'DELETE');
    expect(client.requests[1].url.path, '/api/v1/like');
    expect(jsonBodyOf(client.requests[1] as http.Request), {
      'targetId': '348206251022356480',
      'targetType': 1,
    });
  });

  test('favorite and unfavorite target posts through the favorite endpoint',
      () async {
    final client = ScriptedGatewayClient.always(<String, dynamic>{});
    setApiClient(client);
    final repository = InteractionRepository();

    await repository.favoritePost('9');
    await repository.unfavoritePost('9');

    expect(client.requests[0].method, 'POST');
    expect(client.requests[0].url.path, '/api/v1/favorite');
    expect(jsonBodyOf(client.requests[0] as http.Request), {'postId': '9'});
    expect(client.requests[1].method, 'DELETE');
    expect(client.requests[1].url.path, '/api/v1/favorite');
    expect(jsonBodyOf(client.requests[1] as http.Request), {'postId': '9'});
  });
}
