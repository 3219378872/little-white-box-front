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
}
