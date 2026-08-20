import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/v2_api_client.dart';
import 'package:xiaobaihe_app/features/search/data/search_models.dart';
import 'package:xiaobaihe_app/features/search/data/search_repository.dart';

void main() {
  test('uses the all, users, and tags v2 contracts', () async {
    final client = _StubV2ApiClient([
      {
        'posts': [postJson(1)],
        'users': [userJson(2)],
        'tags': [tagJson('flutter')],
      },
      {
        'users': [userJson(3)],
        'total': 7,
      },
      {
        'tags': [tagJson('dart')],
      },
    ]);
    final repository = SearchRepository(client: client);

    final all = await repository.search(
      scope: SearchScope.all,
      keyword: '  query  ',
    );
    final users = await repository.search(
      scope: SearchScope.users,
      keyword: 'query',
      page: 2,
      pageSize: 10,
    );
    final tags = await repository.search(
      scope: SearchScope.tags,
      keyword: 'query',
      pageSize: 5,
    );

    expect(client.calls[0].path, '/api/v2/search');
    expect(client.calls[0].query, {
      'keyword': 'query',
      'page': 1,
      'pageSize': 20,
    });
    expect(client.calls[1].path, '/api/v2/search/users');
    expect(client.calls[1].query['page'], 2);
    expect(client.calls[2].path, '/api/v2/search/tags');
    expect(client.calls[2].query, {'keyword': 'query', 'limit': 5});
    expect(all.posts.single.id, 1);
    expect(all.posts.single.authorId, 11);
    expect(all.posts.single.authorName, 'Author');
    expect(all.posts.single.authorAvatar, 'https://avatar/1.png');
    expect(all.users.single.displayName, 'User 2');
    expect(all.tags.single.name, 'flutter');
    expect(users.total, 7);
    expect(tags.tags.single.name, 'dart');
  });
}

Map<String, dynamic> postJson(int id) => {
  'id': id,
  'title': 'Post $id',
  'contentHighlight': '<em>match</em>',
  'authorId': id + 10,
  'authorName': 'Author',
  'authorAvatar': 'https://avatar/$id.png',
  'likeCount': 2,
  'commentCount': 1,
  'createdAt': 1700000000,
};

Map<String, dynamic> userJson(int id) => {
  'id': id,
  'username': 'user$id',
  'nickname': 'User $id',
  'avatarUrl': '',
  'bio': 'Bio',
  'followerCount': 4,
};

Map<String, dynamic> tagJson(String name) => {'name': name, 'postCount': 3};

class _Call {
  final String path;
  final Map<String, Object?> query;

  const _Call(this.path, this.query);
}

class _StubV2ApiClient extends V2ApiClient {
  final List<Map<String, dynamic>> responses;
  final List<_Call> calls = [];

  _StubV2ApiClient(this.responses);

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    calls.add(_Call(path, Map.of(query)));
    return responses.removeAt(0);
  }
}
