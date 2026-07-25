import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart' as mock_router;
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

void main() {
  test('post list exposes and persists the mock liked state', () {
    Map<String, dynamic> request(String method, String path, [Object? body]) {
      return jsonDecode(
            mock_router.dispatch(
              method,
              path,
              body == null ? '' : jsonEncode(body),
            ),
          )
          as Map<String, dynamic>;
    }

    PostItem firstPost() {
      final envelope = request('GET', '/api/v1/posts?page=1&pageSize=20');
      final data = envelope['data'] as Map<String, dynamic>;
      final list = data['list'] as List<dynamic>;
      return PostItem.fromJson(list.first as Map<String, dynamic>);
    }

    expect(firstPost().isLiked, isTrue);
    expect(firstPost().likeCount, 89);

    request('POST', '/api/v1/like', {'targetId': 1, 'targetType': 1});

    expect(firstPost().isLiked, isFalse);
    expect(firstPost().likeCount, 88);
    final detail = request('GET', '/api/v1/post/1');
    expect((detail['data'] as Map<String, dynamic>)['isLiked'], isFalse);

    request('POST', '/api/v1/like', {'targetId': 1, 'targetType': 1});

    expect(firstPost().isLiked, isTrue);
    expect(firstPost().likeCount, 89);
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
