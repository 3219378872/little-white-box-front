import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/comment/data/comment_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

import '../../../helpers/gateway_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  test('fetchComments keeps the hand-built v1 query contract', () async {
    final client = ScriptedGatewayClient.always({
      'list': [
        {
          'id': '555000111222333',
          'userId': 7,
          'userName': '评论人',
          'userAvatar': '',
          'parentId': 0,
          'replyUserId': 0,
          'content': '沙发',
          'likeCount': 1,
          'createdAt': 1700000000,
        },
      ],
      'total': 21,
      'page': 2,
      'pageSize': 10,
    });
    setApiClient(client);
    final repository = CommentRepository();

    final page = await repository.fetchComments(
      postId: '348206251022356480',
      page: 2,
      pageSize: 10,
      sortBy: 1,
    );

    final request = client.requests.single;
    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/comments/348206251022356480');
    expect(request.url.queryParameters, {
      'page': '2',
      'pageSize': '10',
      'sortBy': '1',
    });
    expect(page.total, 21);
    expect(page.page, 2);
    expect(page.pageSize, 10);
    expect(page.list.single.id, '555000111222333');
    expect(page.list.single.userName, '评论人');
    expect(page.list.single.content, '沙发');
  });

  test('createNewComment posts the idempotent create contract', () async {
    final client = ScriptedGatewayClient.always({'commentId': 55});
    setApiClient(client);
    final repository = CommentRepository();

    final resp = await repository.createNewComment(CreateCommentReq(
      postId: '9',
      parentId: 0,
      replyUserId: 0,
      content: '  沙发  ',
      idempotencyKey: 'comment-key-1',
    ));

    final request = client.requests.single as http.Request;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/comment');
    expect(jsonBodyOf(request), {
      'postId': '9',
      'parentId': 0,
      'replyUserId': 0,
      'content': '  沙发  ',
      'idempotencyKey': 'comment-key-1',
    });
    expect(resp.commentId, 55);
  });

  test('deleteExistingComment targets the comment id path', () async {
    final client = ScriptedGatewayClient.always(<String, dynamic>{});
    setApiClient(client);
    final repository = CommentRepository();

    await repository.deleteExistingComment('55');

    final request = client.requests.single as http.Request;
    expect(request.method, 'DELETE');
    expect(request.url.path, '/api/v1/comment/55');
    expect(jsonBodyOf(request), {'commentId': '55'});
  });
}
