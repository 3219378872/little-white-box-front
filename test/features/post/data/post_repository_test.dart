import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/features/post/data/post_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

import '../../../helpers/gateway_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  test('getPostDetail hits the v1 contract and keeps snowflake ids', () async {
    const snowflake = '348206251022356480';
    final client = ScriptedGatewayClient.always({
      'id': snowflake,
      'authorId': 2,
      'authorName': 'Author',
      'authorAvatar': '',
      'title': '联调帖',
      'content': '正文',
      'images': <String>[],
      'tags': <String>['go'],
      'status': 1,
      'viewCount': 10,
      'likeCount': 2,
      'commentCount': 1,
      'favoriteCount': 3,
      'isLiked': true,
      'createdAt': 1700000000,
    });
    setApiClient(client);
    final repository = PostRepository();

    final post = await repository.getPostDetail(snowflake);

    expect(client.requests.single.method, 'GET');
    expect(client.requests.single.url.path, '/api/v1/post/$snowflake');
    expect(post.id, snowflake);
    expect(post.title, '联调帖');
    expect(post.status, 1);
    expect(post.favoriteCount, 3);
    expect(post.isLiked, isTrue);
  });

  test('createNewPost posts the v2 draft contract', () async {
    final client =
        ScriptedGatewayClient.always({'postId': 7, 'status': 1, 'revision': 1});
    setApiClient(client);
    final repository = PostRepository();

    final resp = await repository.createNewPost(CreatePostReq(
      title: '标题',
      content: '正文',
      images: <String>['https://img/1.png'],
      tags: <String>['flutter'],
      status: 1,
      idempotencyKey: 'post-key-1',
      mediaIds: <Object>[11],
    ));

    final request = client.requests.single as http.Request;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v2/post');
    final body = jsonBodyOf(request);
    expect(body['title'], '标题');
    expect(body['images'], ['https://img/1.png']);
    expect(body['tags'], ['flutter']);
    expect(body['status'], 1);
    expect(body['idempotencyKey'], 'post-key-1');
    expect(body['mediaIds'], [11]);
    expect(resp.postId, 7);
    expect(resp.revision, 1);
  });

  test('updateExistingPost sends expectedRevision for optimistic locking',
      () async {
    final client = ScriptedGatewayClient.always({'status': 1, 'revision': 4});
    setApiClient(client);
    final repository = PostRepository();

    final resp = await repository.updateExistingPost(
      '7',
      UpdatePostV2Req(
        postId: '7',
        title: '新标题',
        content: '新正文',
        images: <String>[],
        tags: <String>[],
        status: 1,
        expectedRevision: 3,
        mediaIds: <Object>[],
      ),
    );

    final request = client.requests.single as http.Request;
    expect(request.method, 'PUT');
    expect(request.url.path, '/api/v2/post/7');
    final body = jsonBodyOf(request);
    expect(body['expectedRevision'], 3);
    expect(body['title'], '新标题');
    expect(resp.status, 1);
    expect(resp.revision, 4);
  });

  test('deleteExistingPost passes the expected revision in the body',
      () async {
    final client = ScriptedGatewayClient.always(<String, dynamic>{});
    setApiClient(client);
    final repository = PostRepository();

    await repository.deleteExistingPost('7', expectedRevision: 3);

    final request = client.requests.single as http.Request;
    expect(request.method, 'DELETE');
    expect(request.url.path, '/api/v2/post/7');
    expect(jsonBodyOf(request), {
      'postId': '7',
      'expectedRevision': 3,
    });
  });

  group('uploadImageMultipart', () {
    const uploadPayload = {
      'mediaId': 11,
      'url': 'https://media/11.png',
      'thumbnailUrl': 'https://media/11_thumb.png',
    };

    ScriptedGatewayClient clientWithPayload() =>
        ScriptedGatewayClient.always(uploadPayload);

    String capturedMime(ScriptedGatewayClient client, [int index = 0]) {
      final file =
          (client.requests[index] as http.MultipartRequest).files.single;
      expect(file.field, 'file');
      return file.contentType.mimeType;
    }

    test('infers the mime from the extension whitelist', () async {
      final client = clientWithPayload();
      setApiClient(client);
      final repository = PostRepository();

      final image = await repository.uploadImageMultipart(
        bytes: [0, 1, 2],
        filename: 'pic.JPG',
      );

      expect(client.requests.single.method, 'POST');
      expect(client.requests.single.url.path, '/api/v1/media/image');
      expect(
        (client.requests.single as http.MultipartRequest).files.single.filename,
        'pic.JPG',
      );
      expect(capturedMime(client), 'image/jpeg');
      expect(image.mediaId, 11);
      expect(image.url, 'https://media/11.png');
      expect(image.thumbnailUrl, 'https://media/11_thumb.png');

      await repository.uploadImageMultipart(bytes: [0], filename: 'pic.png');
      await repository.uploadImageMultipart(bytes: [0], filename: 'pic.webp');

      expect(capturedMime(client, 1), 'image/png');
      expect(capturedMime(client, 2), 'image/webp');
    });

    test('magic bytes are trusted once the extension is unknown', () async {
      final client = clientWithPayload();
      setApiClient(client);
      final repository = PostRepository();

      Future<void> upload(List<int> bytes) => repository.uploadImageMultipart(
            bytes: bytes,
            filename: 'unknown.bin',
          );

      await upload([0xFF, 0xD8, 0xFF, 0xE0]);
      await upload([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      ]);
      await upload([
        0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, //
        0x57, 0x45, 0x42, 0x50, //
      ]);
      await upload([0x00]);

      expect(capturedMime(client, 0), 'image/jpeg');
      expect(capturedMime(client, 1), 'image/png');
      expect(capturedMime(client, 2), 'image/webp');
      expect(capturedMime(client, 3), 'image/jpeg');
    });

    test('carries the stored access token as Bearer header', () async {
      SharedPreferences.setMockInitialValues({});
      final client = clientWithPayload();
      setApiClient(client);
      await setTokens(buildStoredTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      ));
      addTearDown(() async {
        await removeTokens();
      });

      await PostRepository().uploadImageMultipart(
        bytes: [0],
        filename: 'a.jpg',
      );

      expect(
        client.requests.single.headers['Authorization'],
        'Bearer access-1',
      );
    });

    test('rejects an upload response without an url', () async {
      final client = ScriptedGatewayClient.always({'mediaId': 11});
      setApiClient(client);

      await expectLater(
        PostRepository().uploadImageMultipart(
          bytes: [0],
          filename: 'a.jpg',
        ),
        throwsA(isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('missing url'),
        )),
      );
    });
  });
}
