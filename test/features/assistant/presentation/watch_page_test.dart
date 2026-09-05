import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/widgets/error_view.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/presentation/watch_page.dart';

import '../../../helpers/forui_test_builder.dart';
import '../helpers/fake_assistant_source.dart';

final _watchIdentityProvider = StateProvider<String>((_) => 'account-a');

FakeAssistantSource _grantedSource() => FakeAssistantSource()
  ..granted = true
  ..consentVersion = 2
  ..currentVersion = 2;

Future<void> _pumpWatch(WidgetTester tester, FakeAssistantSource source) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assistantUserKeyProvider.overrideWithValue('test-user'),
        assistantRepositoryProvider.overrideWithValue(source),
      ],
      child: const MaterialApp(builder: foruiTestBuilder, home: WatchPage()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<ProviderContainer> _pumpSwitchableWatch(
  WidgetTester tester,
  FakeAssistantSource accountA,
  FakeAssistantSource accountB,
) async {
  final container = ProviderContainer(
    overrides: [
      assistantUserKeyProvider.overrideWith(
        (ref) => ref.watch(_watchIdentityProvider),
      ),
      assistantRepositoryProvider.overrideWith((ref) {
        final identity = ref.watch(_watchIdentityProvider);
        return identity == 'account-a' ? accountA : accountB;
      }),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(builder: foruiTestBuilder, home: WatchPage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows empty tasks without a hits inbox', (tester) async {
    await _pumpWatch(tester, _grantedSource());

    expect(find.text('还没有追踪任务'), findsOneWidget);
    expect(find.text('命中收件箱'), findsNothing);
    expect(find.text('还没有追踪命中'), findsNothing);
    expect(find.byType(ErrorView), findsNothing);
  });

  testWidgets('shows a recoverable error instead of empty success', (
    tester,
  ) async {
    final source = _grantedSource()..lastError = const ApiException('无权访问');
    await _pumpWatch(tester, source);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('无权访问'), findsOneWidget);
    expect(find.text('还没有追踪任务'), findsNothing);
  });

  testWidgets('lists tasks with write actions and no hits', (tester) async {
    final source = _grantedSource()
      ..watches = const [
        WatchTask(
          id: 1,
          conditionType: 'author_new_post',
          targetType: 'author',
          targetId: '2',
        ),
      ];
    await _pumpWatch(tester, source);

    expect(find.text('盯作者新帖'), findsOneWidget);
    expect(find.textContaining('author:2'), findsOneWidget);
    expect(find.text('停用'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('标为已读'), findsNothing);
  });

  testWidgets('keeps a list action error visible with an explicit retry', (
    tester,
  ) async {
    final source = _grantedSource()
      ..watches = const [
        WatchTask(
          id: 1,
          conditionType: 'author_new_post',
          targetType: 'author',
          targetId: '2',
        ),
      ];
    await _pumpWatch(tester, source);
    source.updateWatchError = const ApiException('更新暂时失败');

    await tester.tap(find.text('停用'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('watch-list-error')), findsOneWidget);
    expect(find.text('更新暂时失败'), findsWidgets);
    expect(find.text('盯作者新帖'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('watch-list-error')),
        matching: find.text('重试'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('watch-list-error')), findsNothing);
    expect(find.text('盯作者新帖'), findsOneWidget);
  });

  testWidgets('account switch dismisses create dialog without creating for B', (
    tester,
  ) async {
    final accountA = _grantedSource();
    final accountB = _grantedSource()
      ..watches = const [
        WatchTask(
          id: 2,
          conditionType: 'post_revised',
          targetType: 'post',
          targetId: 22,
        ),
      ];
    final container = await _pumpSwitchableWatch(tester, accountA, accountB);

    await tester.tap(find.bySemanticsLabel('创建追踪'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '11');

    container.read(_watchIdentityProvider.notifier).state = 'account-b';
    await tester.pumpAndSettle();

    expect(find.text('创建追踪'), findsNothing);
    expect(find.textContaining('post:22'), findsOneWidget);
    expect(accountA.lastCreateCondition, isNull);
    expect(accountB.lastCreateCondition, isNull);
  });
}
