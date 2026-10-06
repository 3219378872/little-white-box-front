import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/features/post/application/post_editor_controller.dart';
import 'package:xiaobaihe_app/features/post/data/post_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

// 1x1 PNG，用于触发真实的 MIME 推断与上传路径。
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhf'
  'DwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

// 记录发帖与上传请求；前 [failCreates] 次发帖返回可重试的网络错误。
class _RecordingPostRepository extends PostRepository {
  int failCreates;
  final List<CreatePostReq> creates = [];
  int uploads = 0;

  _RecordingPostRepository({this.failCreates = 0});

  @override
  Future<CreatePostResp> createNewPost(CreatePostReq req) async {
    creates.add(req);
    if (failCreates > 0) {
      failCreates--;
      throw const ApiException('temporary');
    }
    return CreatePostResp(postId: 7, status: 1, revision: 1);
  }

  @override
  Future<UploadedImage> uploadImageMultipart({
    required List<int> bytes,
    required String filename,
  }) async {
    uploads++;
    return UploadedImage(mediaId: 50 + uploads, url: 'https://m/$uploads.png');
  }
}

void main() {
  test('create retries reuse the key until the command changes', () async {
    final repo = _RecordingPostRepository(failCreates: 2);
    final controller = PostEditorController(repository: repo);

    for (var i = 0; i < 2; i++) {
      await expectLater(
        controller.publish(title: '命令 A', content: '正文'),
        throwsA(isA<ApiException>()),
      );
    }
    final outcome = await controller.publish(title: '命令 B', content: '正文');

    expect(outcome, PostPublishOutcome.created);
    final keys = repo.creates.map((req) => req.idempotencyKey).toList();
    expect(keys[0], keys[1]);
    expect(keys[2], isNot(keys[1]));
  });

  test('a successful create retires the key for the next post', () async {
    final repo = _RecordingPostRepository();
    final controller = PostEditorController(repository: repo);

    await controller.publish(title: '同一标题', content: '正文');
    await controller.publish(title: '同一标题', content: '正文');

    expect(
      repo.creates[0].idempotencyKey,
      isNot(repo.creates[1].idempotencyKey),
    );
  });

  test('retries reuse uploaded images for the same selection', () async {
    final repo = _RecordingPostRepository(failCreates: 1);
    final controller = PostEditorController(repository: repo)
      ..addLocalImage(XFile.fromData(_pixel, name: 'pixel.png'));

    await expectLater(
      controller.publish(title: 'T', content: 'C'),
      throwsA(isA<ApiException>()),
    );
    await controller.publish(title: 'T', content: 'C');

    expect(repo.uploads, 1);
    expect(repo.creates.last.images, ['https://m/1.png']);
    expect(repo.creates[0].idempotencyKey, repo.creates[1].idempotencyKey);
  });

  test('invalid drafts are rejected before any request', () async {
    final repo = _RecordingPostRepository();
    final controller = PostEditorController(repository: repo);

    await expectLater(
      controller.publish(title: '  ', content: '正文'),
      throwsA(isA<PostDraftInvalidException>()),
    );
    expect(repo.creates, isEmpty);
    expect(controller.state.isSubmitting, isFalse);
  });

  test('tags are trimmed, unique and bounded', () {
    final controller = PostEditorController(
      repository: _RecordingPostRepository(),
    );

    expect(controller.addTag(' go '), isTrue);
    expect(controller.addTag('go'), isFalse);
    expect(controller.addTag(''), isFalse);
    expect(controller.addTag('x' * (postTagMaxLength + 1)), isFalse);
    for (var i = 1; i < postTagMaxCount; i++) {
      controller.addTag('t$i');
    }
    expect(controller.addTag('overflow'), isFalse);
    expect(controller.state.tags.first, 'go');
    expect(controller.state.tags, hasLength(postTagMaxCount));
  });
}
