import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/assistant/application/watch_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';

import '../helpers/fake_assistant_source.dart';

void main() {
  const task = WatchTask(
    id: 1,
    conditionType: 'author_new_post',
    targetType: 'author',
    targetId: 2,
    version: 3,
  );

  test('successful update fences an older watch load', () async {
    final staleLoad = Completer<List<WatchTask>>();
    final source = FakeAssistantSource()..watches = const [task];
    final notifier = WatchListNotifier(repository: source);
    await notifier.load();
    source.listWatchesHandler = () => staleLoad.future;

    final oldLoad = notifier.load();
    expect(notifier.state.loading, isTrue);
    await notifier.setEnabled(task, false);
    expect(notifier.state.loading, isFalse);
    expect(notifier.state.items.single.enabled, isFalse);
    expect(notifier.state.items.single.version, 4);

    staleLoad.complete(const [task]);
    await oldLoad;

    expect(notifier.state.items.single.enabled, isFalse);
    expect(notifier.state.items.single.version, 4);
  });

  test('successful delete fences an older watch load', () async {
    final staleLoad = Completer<List<WatchTask>>();
    final source = FakeAssistantSource()..watches = const [task];
    final notifier = WatchListNotifier(repository: source);
    await notifier.load();
    source.listWatchesHandler = () => staleLoad.future;

    final oldLoad = notifier.load();
    await notifier.deleteTask(task);
    expect(notifier.state.loading, isFalse);
    expect(notifier.state.items, isEmpty);

    staleLoad.complete(const [task]);
    await oldLoad;

    expect(notifier.state.items, isEmpty);
  });
}
