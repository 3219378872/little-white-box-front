import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart' as mock_router;
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

void main() {
  setUp(mock_router.resetMockState);

  test('post list exposes and persists the mock liked state', () {
    final headers = {
      'Authorization': 'Bearer ${mock_router.mockAccessTokenForUser(1)}',
    };

    Map<String, dynamic> request(String method, String path, [Object? body]) {
      return jsonDecode(
        mock_router.dispatch(
          method,
          path,
          body == null ? '' : jsonEncode(body),
          headers: headers,
        ),
      ) as Map<String, dynamic>;
    }

    PostItem firstPost() {
      final data = request('GET', '/api/v1/posts?page=1&pageSize=20');
      final list = data['list'] as List<dynamic>;
      return PostItem.fromJson(list.first as Map<String, dynamic>);
    }

    expect(firstPost().isLiked, isTrue);
    expect(firstPost().likeCount, 89);

    request('DELETE', '/api/v1/like', {'targetId': 1, 'targetType': 1});

    expect(firstPost().isLiked, isFalse);
    expect(firstPost().likeCount, 88);
    final detail = request('GET', '/api/v1/post/1');
    expect(detail['isLiked'], isFalse);

    request('POST', '/api/v1/like', {'targetId': 1, 'targetType': 1});

    expect(firstPost().isLiked, isTrue);
    expect(firstPost().likeCount, 89);

    // 与后端一致：重复点赞直接成功且不重复计数。
    final duplicate = mock_router.dispatchResponse(
      'POST',
      '/api/v1/like',
      jsonEncode({'targetId': 1, 'targetType': 1}),
      headers: headers,
    );
    expect(duplicate.statusCode, 200);
    expect(firstPost().likeCount, 89);
  });

  test('like, unlike, favorite and unfavorite are idempotent', () {
    final headers = {
      'Authorization': 'Bearer ${mock_router.mockAccessTokenForUser(1)}',
    };

    // 返回状态码，重复操作也应成功。
    int send(String method, String path, Map<String, Object> body) {
      return mock_router
          .dispatchResponse(method, path, jsonEncode(body), headers: headers)
          .statusCode;
    }

    PostItem post(int id) => PostItem.fromJson(
      jsonDecode(
        mock_router.dispatch('GET', '/api/v1/post/$id', '', headers: headers),
      ) as Map<String, dynamic>,
    );

    // 先取消到未赞状态，再重复取消与重复点赞，计数只随实际变化。
    final like = {'targetId': 2, 'targetType': 1};
    send('DELETE', '/api/v1/like', like);
    final unliked = post(2).likeCount;
    expect(send('DELETE', '/api/v1/like', like), 200);
    expect(post(2).likeCount, unliked);
    expect(send('POST', '/api/v1/like', like), 200);
    expect(send('POST', '/api/v1/like', like), 200);
    expect(post(2).likeCount, unliked + 1);

    // 收藏同理。
    final favorite = {'postId': 2};
    send('DELETE', '/api/v1/favorite', favorite);
    final unfavorited = post(2).favoriteCount;
    expect(send('DELETE', '/api/v1/favorite', favorite), 200);
    expect(post(2).favoriteCount, unfavorited);
    expect(send('POST', '/api/v1/favorite', favorite), 200);
    expect(send('POST', '/api/v1/favorite', favorite), 200);
    expect(post(2).favoriteCount, unfavorited + 1);
  });

  test('authors may like their own posts like on the backend', () {
    final authorId =
        (jsonDecode(mock_router.dispatch('GET', '/api/v1/post/1', ''))
                as Map<String, dynamic>)['authorId']
            as int;
    final response = mock_router.dispatchResponse(
      'POST',
      '/api/v1/like',
      jsonEncode({'targetId': 1, 'targetType': 1}),
      headers: {
        'Authorization':
            'Bearer ${mock_router.mockAccessTokenForUser(authorId)}',
      },
    );
    expect(response.statusCode, 200);
  });

  test('unexpected mock failures return the backend system error text', () {
    // targetId 类型不对会在路由里抛 TypeError，兜底应与后端 errx.SystemError 一致。
    final response = mock_router.dispatchResponse(
      'POST',
      '/api/v1/like',
      jsonEncode({'targetId': 'x', 'targetType': 1}),
      headers: {
        'Authorization': 'Bearer ${mock_router.mockAccessTokenForUser(1)}',
      },
    );
    expect(response.statusCode, 500);
    expect(jsonDecode(response.body), {'code': 3, 'message': '系统错误'});
  });

  test('like and write routes require Bearer auth', () {
    final unauthorized = mock_router.dispatchResponse(
      'POST',
      '/api/v1/like',
      jsonEncode({'targetId': 1, 'targetType': 1}),
    );
    expect(unauthorized.statusCode, 401);
    expect(jsonDecode(unauthorized.body)['code'], 1006);
  });

  test('PostItem defaults missing isLiked to false and serializes it', () {
    final post = PostItem.fromJson({
      'id': 7,
      'authorId': 1,
      'authorName': '用户',
      'title': '标题',
    });

    expect(post.isLiked, isFalse);
    expect(post.toJson()['isLiked'], isFalse);
  });
}
