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
          )
          as Map<String, dynamic>;
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

    final duplicate = mock_router.dispatchResponse(
      'POST',
      '/api/v1/like',
      jsonEncode({'targetId': 1, 'targetType': 1}),
      headers: headers,
    );
    expect(duplicate.statusCode, 400);
    expect(jsonDecode(duplicate.body)['code'], 3001);
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
