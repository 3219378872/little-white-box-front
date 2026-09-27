import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/media/data/media_repository.dart';
import 'package:xiaobaihe_app/features/message/application/media_send_controller.dart';

class FakeUploads extends MediaRepository {
  final keys = <String>[];
  int failures = 0;
  Completer<UploadedMedia>? pending;
  @override
  Future<UploadedMedia> upload(
    XFile file,
    MediaKind kind,
    String key, {
    required bool Function() isCurrent,
  }) async {
    keys.add(key);
    if (failures-- > 0) throw Exception('offline');
    return pending?.future ??
        const UploadedMedia(
          mediaId: '9007199254740993',
          url: 'https://media.test/file',
        );
  }
}

void main() {
  XFile file() => XFile.fromData(Uint8List.fromList([1]), name: 'voice.wav');
  test(
    'upload failure reuses key, message failure reuses uploaded result',
    () async {
      final repo = FakeUploads()..failures = 1;
      final controller = MediaSendController(repo);
      var sends = 0;
      final ids = <Object>[];
      await controller.start(
        file(),
        MediaKind.audio,
        isCurrent: () => true,
        send: (m, k) async {
          ids.add(m.mediaId);
          return ++sends > 1;
        },
      );
      expect(sends, 0);
      expect(controller.hasPending, true);
      await controller.retry();
      expect(repo.keys.length, 2);
      expect(repo.keys.toSet().length, 1);
      expect(controller.hasPending, true);
      await controller.retry();
      expect(repo.keys.length, 2);
      expect(sends, 2);
      expect(ids, ['9007199254740993', '9007199254740993']);
      expect(controller.hasPending, false);
      controller.dispose();
    },
  );
  test(
    'cancelled upload cannot replace a newer task after late completion',
    () async {
      final repo = FakeUploads()..pending = Completer<UploadedMedia>();
      final oldResult = repo.pending!;
      final controller = MediaSendController(repo);
      var sends = 0;
      final old = controller.start(
        file(),
        MediaKind.audio,
        isCurrent: () => true,
        send: (m, k) async {
          sends++;
          return true;
        },
      );
      controller.cancel();
      repo.pending = null;
      repo.failures = 1;
      await controller.start(
        file(),
        MediaKind.video,
        isCurrent: () => true,
        send: (m, k) async {
          sends++;
          expect(m.mediaId, '9007199254740993');
          return true;
        },
      );
      oldResult.complete(
        const UploadedMedia(mediaId: 99, url: 'https://media.test/old'),
      );
      await old;
      await controller.retry();
      expect(repo.keys.length, 3);
      expect(sends, 1);
      controller.dispose();
    },
  );
  for (final reason in ['session changed', 'page disposed', 'cancelled']) {
    test('$reason prevents late upload from sending', () async {
      final repo = FakeUploads()..pending = Completer<UploadedMedia>();
      final c = MediaSendController(repo);
      var current = true;
      var sends = 0;
      final task = c.start(
        file(),
        MediaKind.video,
        isCurrent: () => current,
        send: (m, k) async {
          sends++;
          return true;
        },
      );
      if (reason == 'page disposed') {
        c.dispose();
      } else if (reason == 'cancelled') {
        c.cancel();
      } else {
        current = false;
      }
      repo.pending!.complete(
        const UploadedMedia(mediaId: 1, url: 'https://media.test/file'),
      );
      await task;
      expect(sends, 0);
      if (reason != 'page disposed') c.dispose();
    });
  }
}
