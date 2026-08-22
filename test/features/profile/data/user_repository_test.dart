import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/profile/data/user_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

import '../../../helpers/gateway_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  test('getUserProfile parses the v1 user payload', () async {
    final client = ScriptedGatewayClient.always({
      'id': 7,
      'username': 'admin',
      'nickname': '管理员',
      'avatarUrl': 'https://avatar/7.png',
      'bio': 'bio',
      'level': 3,
      'followerCount': 11,
      'followingCount': 12,
      'postCount': 13,
      'favoritesVisible': true,
    });
    setApiClient(client);
    final repository = UserRepository();

    final profile = await repository.getUserProfile(7);

    expect(client.requests.single.method, 'GET');
    expect(client.requests.single.url.path, '/api/v1/user/7');
    expect(profile.id, 7);
    expect(profile.nickname, '管理员');
    expect(profile.level, 3);
    expect(profile.followerCount, 11);
    expect(profile.postCount, 13);
    expect(profile.favoritesVisible, isTrue);
  });

  test('updateUserProfile puts nickname, avatar and bio', () async {
    final client = ScriptedGatewayClient.always(<String, dynamic>{});
    setApiClient(client);
    final repository = UserRepository();

    await repository.updateUserProfile(UpdateProfileReq(
      nickname: '新昵称',
      avatarUrl: 'https://avatar/new.png',
      bio: '新签名',
    ));

    final request = client.requests.single as http.Request;
    expect(request.method, 'PUT');
    expect(request.url.path, '/api/v1/user/profile');
    expect(jsonBodyOf(request), {
      'nickname': '新昵称',
      'avatarUrl': 'https://avatar/new.png',
      'bio': '新签名',
    });
  });

  test('follow and unfollow post/delete the same endpoint', () async {
    final client = ScriptedGatewayClient.always(<String, dynamic>{});
    setApiClient(client);
    final repository = UserRepository();

    await repository.followUser('8');
    await repository.unfollowUser('8');

    expect(client.requests[0].method, 'POST');
    expect(client.requests[0].url.path, '/api/v1/user/follow');
    expect(
      jsonBodyOf(client.requests[0] as http.Request),
      {'targetUserId': '8'},
    );
    expect(client.requests[1].method, 'DELETE');
    expect(client.requests[1].url.path, '/api/v1/user/follow');
    expect(
      jsonBodyOf(client.requests[1] as http.Request),
      {'targetUserId': '8'},
    );
  });

  test('fetchUserPosts and favorites keep the hand-built query', () async {
    final client = ScriptedGatewayClient.always({
      'list': <Object>[],
      'total': 0,
      'page': 2,
      'pageSize': 10,
    });
    setApiClient(client);
    final repository = UserRepository();

    await repository.fetchUserPosts(userId: 7, page: 2, pageSize: 10);
    await repository.fetchUserFavorites(userId: 7, page: 1, pageSize: 5);

    expect(client.requests[0].url.path, '/api/v1/users/7/posts');
    expect(client.requests[0].url.queryParameters, {
      'page': '2',
      'pageSize': '10',
      'sortBy': '1',
    });
    expect(client.requests[1].url.path, '/api/v1/users/7/favorites');
    expect(client.requests[1].url.queryParameters, {
      'page': '1',
      'pageSize': '5',
    });
  });
}
