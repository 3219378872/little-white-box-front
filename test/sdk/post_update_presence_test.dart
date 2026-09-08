import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

void main() {
  test('omitted update media fields remain omitted after decoding', () {
    final request = UpdatePostV2Req.fromJson({
      'postId': 1,
      'title': 'updated',
      'expectedRevision': 3,
    });
    expect(request.images, isNull);
    expect(request.mediaIds, isNull);
    expect(request.toJson().containsKey('images'), isFalse);
    expect(request.toJson().containsKey('mediaIds'), isFalse);
  });

  test('explicit empty media arrays survive update serialization', () {
    final request = UpdatePostV2Req.fromJson({
      'postId': 1,
      'expectedRevision': 3,
      'images': [],
      'mediaIds': [],
    });
    expect(request.images, isEmpty);
    expect(request.mediaIds, isEmpty);
    expect(request.toJson()['images'], <String>[]);
    expect(request.toJson()['mediaIds'], <Object>[]);
    expect(request.toJson().containsKey('images'), isTrue);
    expect(request.toJson().containsKey('mediaIds'), isTrue);
  });

  test('update constructor supports preserving media without empty arrays', () {
    final request = UpdatePostV2Req(
      postId: 1,
      title: 'updated',
      content: '',
      tags: [],
      status: null,
      expectedRevision: 3,
    );
    expect(request.toJson().containsKey('images'), isFalse);
    expect(request.toJson().containsKey('mediaIds'), isFalse);
  });
}
