import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/application/memory_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';

import '../helpers/fake_assistant_source.dart';

void main() {
  test(
    'provider keeps a failed command while temporarily unobserved',
    () async {
      final source = FakeAssistantSource()
        ..addMemoryError = Exception('offline');
      final container = ProviderContainer(
        overrides: [
          assistantRepositoryProvider.overrideWithValue(source),
          assistantUserKeyProvider.overrideWithValue('user:7:1'),
        ],
      );
      addTearDown(container.dispose);

      final firstSubscription = container.listen<MemoryListState>(
        memoryListProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await expectLater(
        container
            .read(memoryListProvider.notifier)
            .addRecord(target: 'memory', content: '喜欢美食'),
        throwsException,
      );
      firstSubscription.close();
      await Future<void>.delayed(Duration.zero);

      final secondSubscription = container.listen<MemoryListState>(
        memoryListProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(secondSubscription.close);
      await container
          .read(memoryListProvider.notifier)
          .addRecord(target: 'memory', content: '喜欢美食');

      expect(source.addMemoryRequestIds, hasLength(2));
      expect(source.addMemoryRequestIds[1], source.addMemoryRequestIds[0]);
    },
  );

  test('provider drops a failed command after an account switch', () async {
    final source = FakeAssistantSource()..addMemoryError = Exception('offline');
    final identityProvider = StateProvider<String>((_) => 'user:7:1');
    final container = ProviderContainer(
      overrides: [
        assistantRepositoryProvider.overrideWithValue(source),
        assistantUserKeyProvider.overrideWith(
          (ref) => ref.watch(identityProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen<MemoryListState>(
      memoryListProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await expectLater(
      container
          .read(memoryListProvider.notifier)
          .addRecord(target: 'memory', content: '喜欢美食'),
      throwsException,
    );
    final firstNotifier = container.read(memoryListProvider.notifier);
    container.read(identityProvider.notifier).state = 'user:8:2';
    await Future<void>.delayed(Duration.zero);
    final secondNotifier = container.read(memoryListProvider.notifier);
    await secondNotifier.addRecord(target: 'memory', content: '喜欢美食');

    expect(secondNotifier, isNot(same(firstNotifier)));
    expect(source.addMemoryRequestIds, hasLength(2));
    expect(source.addMemoryRequestIds[1], isNot(source.addMemoryRequestIds[0]));
  });

  test(
    'add retry reuses requestId and preserves changeId after reload',
    () async {
      var key = 0;
      final source = FakeAssistantSource()
        ..addMemoryError = Exception('offline');
      final notifier = MemoryListNotifier(
        repository: source,
        createRequestId: () => 'request-${++key}',
      );

      await expectLater(
        notifier.addRecord(target: 'memory', content: '  喜欢美食  '),
        throwsException,
      );
      await notifier.addRecord(target: 'memory', content: '喜欢美食');

      expect(source.addMemoryRequestIds, ['request-1', 'request-1']);
      expect(notifier.state.items.single.content, '喜欢美食');
      expect(notifier.state.lastChangeId, 1);

      await notifier.addRecord(target: 'user', content: '使用中文');
      expect(source.addMemoryRequestIds.last, 'request-2');
    },
  );

  test(
    'replace retry fingerprints id version and normalized content',
    () async {
      var key = 0;
      const record = MemoryRecord(
        id: '9007199254740993',
        target: 'memory',
        content: '旧内容',
        version: 4,
      );
      final source = FakeAssistantSource()
        ..memories = const [record]
        ..replaceMemoryError = Exception('offline');
      final notifier = MemoryListNotifier(
        repository: source,
        createRequestId: () => 'request-${++key}',
      );

      await expectLater(
        notifier.updateRecord(record: record, content: '  新内容  '),
        throwsException,
      );
      await notifier.updateRecord(record: record, content: '新内容');

      expect(source.replaceMemoryRequestIds, ['request-1', 'request-1']);
      expect(notifier.state.items.single.content, '新内容');
      expect(notifier.state.items.single.version, 5);
      expect(notifier.state.lastChangeId, 1);
    },
  );

  test(
    'remove retry reuses requestId and a different version gets a new one',
    () async {
      var key = 0;
      const record = MemoryRecord(
        id: 7,
        target: 'memory',
        content: '删除我',
        version: 2,
      );
      final source = FakeAssistantSource()
        ..memories = const [record]
        ..removeMemoryError = Exception('offline');
      final notifier = MemoryListNotifier(
        repository: source,
        createRequestId: () => 'request-${++key}',
      );

      await expectLater(notifier.deleteRecord(record), throwsException);
      await notifier.deleteRecord(record);
      expect(source.removeMemoryRequestIds, ['request-1', 'request-1']);
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.lastChangeId, 1);

      source.memories = const [record];
      await notifier.deleteRecord(
        const MemoryRecord(id: 7, target: 'memory', content: '删除我', version: 3),
      );
      expect(source.removeMemoryRequestIds.last, 'request-2');
    },
  );

  test(
    'undo clears changeId only after success and reload keeps it cleared',
    () async {
      var key = 0;
      final source = FakeAssistantSource()..undoError = Exception('offline');
      final notifier = MemoryListNotifier(
        repository: source,
        createRequestId: () => 'request-${++key}',
      );
      await notifier.addRecord(target: 'memory', content: '喜欢美食');
      expect(notifier.state.lastChangeId, 1);

      await expectLater(notifier.undoLastChange(), throwsException);
      expect(notifier.state.lastChangeId, 1);

      source.undoError = null;
      await notifier.undoLastChange();
      expect(source.lastUndoChangeId, 1);
      expect(notifier.state.lastChangeId, isNull);
    },
  );

  test('write reload wins over an older in-flight memory load', () async {
    const staleRecord = MemoryRecord(
      id: 1,
      target: 'memory',
      content: '旧快照',
      version: 1,
    );
    const freshRecord = MemoryRecord(
      id: 2,
      target: 'memory',
      content: '新记忆',
      version: 1,
    );
    final staleLoad = Completer<(List<MemoryRecord>, List<MemoryCapacity>)>();
    final freshLoad = Completer<(List<MemoryRecord>, List<MemoryCapacity>)>();
    var loadCalls = 0;
    final source = FakeAssistantSource()
      ..listMemoryHandler = () {
        loadCalls++;
        return loadCalls == 1 ? staleLoad.future : freshLoad.future;
      }
      ..addMemoryHandler =
          ({required target, required content, required requestId}) async =>
              const MemoryWriteResult(entry: freshRecord, changeId: 2);
    final notifier = MemoryListNotifier(repository: source);

    final oldLoad = notifier.load();
    final write = notifier.addRecord(target: 'memory', content: '新记忆');
    await Future<void>.delayed(Duration.zero);
    expect(loadCalls, 2);

    freshLoad.complete((const [freshRecord], const <MemoryCapacity>[]));
    await write;
    staleLoad.complete((const [staleRecord], const <MemoryCapacity>[]));
    await oldLoad;

    expect(notifier.state.items.single.content, '新记忆');
    expect(notifier.state.lastChangeId, 2);
    expect(notifier.state.loading, isFalse);
  });

  test('overlapping commands retain their own retry requestIds', () async {
    var key = 0;
    var secondCommandAttempts = 0;
    final firstCommand = Completer<MemoryWriteResult>();
    final secondCommand = Completer<MemoryWriteResult>();
    final source = FakeAssistantSource()
      ..addMemoryHandler =
          ({required target, required content, required requestId}) {
            if (content == '第一条') return firstCommand.future;
            secondCommandAttempts++;
            if (secondCommandAttempts == 1) return secondCommand.future;
            return Future.value(const MemoryWriteResult(changeId: 3));
          };
    final notifier = MemoryListNotifier(
      repository: source,
      createRequestId: () => 'request-${++key}',
    );

    final firstWrite = notifier.addRecord(target: 'memory', content: '第一条');
    final secondWrite = notifier.addRecord(target: 'memory', content: '第二条');
    final secondFailure = expectLater(secondWrite, throwsException);
    expect(source.addMemoryRequestIds, ['request-1', 'request-2']);

    firstCommand.complete(const MemoryWriteResult(changeId: 1));
    await firstWrite;
    secondCommand.completeError(Exception('offline'));
    await secondFailure;
    await notifier.addRecord(target: 'memory', content: '第二条');

    expect(source.addMemoryRequestIds, ['request-1', 'request-2', 'request-2']);
  });

  test(
    'late success cannot clear a newer retry id for the same command',
    () async {
      var key = 0;
      var attempts = 0;
      final first = Completer<MemoryWriteResult>();
      final second = Completer<MemoryWriteResult>();
      final third = Completer<MemoryWriteResult>();
      final source = FakeAssistantSource()
        ..addMemoryHandler =
            ({required target, required content, required requestId}) {
              attempts++;
              return switch (attempts) {
                1 => first.future,
                2 => second.future,
                3 => third.future,
                _ => Future.value(const MemoryWriteResult(changeId: 4)),
              };
            };
      final notifier = MemoryListNotifier(
        repository: source,
        createRequestId: () => 'request-${++key}',
      );

      final firstWrite = notifier.addRecord(target: 'memory', content: '相同命令');
      final secondWrite = notifier.addRecord(target: 'memory', content: '相同命令');
      expect(source.addMemoryRequestIds, ['request-1', 'request-1']);

      first.complete(const MemoryWriteResult(changeId: 1));
      await firstWrite;
      final thirdWrite = notifier.addRecord(target: 'memory', content: '相同命令');
      final thirdFailure = expectLater(thirdWrite, throwsException);
      expect(source.addMemoryRequestIds.last, 'request-2');

      second.complete(const MemoryWriteResult(changeId: 2));
      await secondWrite;
      third.completeError(Exception('offline'));
      await thirdFailure;
      await notifier.addRecord(target: 'memory', content: '相同命令');

      expect(source.addMemoryRequestIds, [
        'request-1',
        'request-1',
        'request-2',
        'request-2',
      ]);
    },
  );
}
