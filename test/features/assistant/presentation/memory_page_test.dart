import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/widgets/error_view.dart';
import 'package:xiaobaihe_app/features/assistant/application/assistant_notifier.dart';
import 'package:xiaobaihe_app/features/assistant/data/assistant_models.dart';
import 'package:xiaobaihe_app/features/assistant/presentation/memory_page.dart';

import '../../../helpers/forui_test_builder.dart';
import '../helpers/fake_assistant_source.dart';

final _memoryIdentityProvider = StateProvider<String>((_) => 'account-a');

FakeAssistantSource _grantedSource() => FakeAssistantSource()
  ..granted = true
  ..consentVersion = 2
  ..currentVersion = 2;

Future<void> _pumpMemory(
  WidgetTester tester,
  FakeAssistantSource source,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assistantUserKeyProvider.overrideWithValue('test-user'),
        assistantRepositoryProvider.overrideWithValue(source),
      ],
      child: const MaterialApp(builder: foruiTestBuilder, home: MemoryPage()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<ProviderContainer> _pumpSwitchableMemory(
  WidgetTester tester,
  FakeAssistantSource accountA,
  FakeAssistantSource accountB,
) async {
  final container = ProviderContainer(
    overrides: [
      assistantUserKeyProvider.overrideWith(
        (ref) => ref.watch(_memoryIdentityProvider),
      ),
      assistantRepositoryProvider.overrideWith((ref) {
        final identity = ref.watch(_memoryIdentityProvider);
        return identity == 'account-a' ? accountA : accountB;
      }),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(builder: foruiTestBuilder, home: MemoryPage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows empty state when there are no memories', (tester) async {
    await _pumpMemory(tester, _grantedSource());

    expect(find.text('还没有可展示的记忆'), findsOneWidget);
    expect(find.byType(ErrorView), findsNothing);
  });

  testWidgets('shows a recoverable error instead of empty success', (
    tester,
  ) async {
    final source = _grantedSource()..lastError = const ApiException('无权访问');
    await _pumpMemory(tester, source);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('无权访问'), findsOneWidget);
    expect(find.text('还没有可展示的记忆'), findsNothing);
  });

  testWidgets('lists dual memory targets and capacity', (tester) async {
    final source = _grantedSource()
      ..memories = const [
        MemoryRecord(id: 1, target: 'memory', content: '喜欢美食', version: 1),
        MemoryRecord(id: 2, target: 'user', content: '用中文', version: 1),
      ]
      ..capacities = const [
        MemoryCapacity(target: 'memory', used: 4, limit: 2200),
        MemoryCapacity(target: 'user', used: 3, limit: 1375),
      ];
    await _pumpMemory(tester, source);

    expect(find.text('喜欢美食'), findsOneWidget);
    expect(find.text('用中文'), findsOneWidget);
    expect(find.text('MEMORY'), findsOneWidget);
    expect(find.text('USER'), findsOneWidget);
    expect(find.text('memory 4/2200'), findsOneWidget);
    expect(find.text('修改'), findsNWidgets(2));
    expect(find.text('不要记住这个'), findsNothing);
  });

  testWidgets('stale consent is read-only with an upgrade prompt', (
    tester,
  ) async {
    final source = FakeAssistantSource()
      ..granted = true
      ..consentVersion = 1
      ..currentVersion = 2
      ..memories = const [
        MemoryRecord(id: 1, target: 'memory', content: '喜欢美食', version: 1),
      ];
    await _pumpMemory(tester, source);

    expect(find.text('需要升级 Agent 授权才能修改记忆'), findsOneWidget);
    expect(find.text('喜欢美食'), findsOneWidget);
    expect(find.text('修改'), findsNothing);
  });

  testWidgets('account switch dismisses add dialog without submitting draft', (
    tester,
  ) async {
    final accountA = _grantedSource();
    final accountB = _grantedSource()
      ..memories = const [
        MemoryRecord(id: 2, target: 'memory', content: '账号 B 的记忆', version: 1),
      ];
    final container = await _pumpSwitchableMemory(tester, accountA, accountB);

    await tester.tap(find.bySemanticsLabel('新增记忆'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '账号 A 的未提交草稿');

    container.read(_memoryIdentityProvider.notifier).state = 'account-b';
    await tester.pumpAndSettle();

    expect(find.text('新增记忆'), findsNothing);
    expect(find.text('账号 A 的未提交草稿'), findsNothing);
    expect(find.text('账号 B 的记忆'), findsOneWidget);
    expect(accountA.addMemoryRequestIds, isEmpty);
    expect(accountB.addMemoryRequestIds, isEmpty);
  });

  testWidgets('account switch dismisses edit dialog without updating B', (
    tester,
  ) async {
    final accountA = _grantedSource()
      ..memories = const [
        MemoryRecord(id: 1, target: 'memory', content: '账号 A 的记忆', version: 1),
      ];
    final accountB = _grantedSource()
      ..memories = const [
        MemoryRecord(id: 2, target: 'user', content: '账号 B 的记忆', version: 3),
      ];
    final container = await _pumpSwitchableMemory(tester, accountA, accountB);

    await tester.tap(find.text('修改'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '不应写给账号 B');

    container.read(_memoryIdentityProvider.notifier).state = 'account-b';
    await tester.pumpAndSettle();

    expect(find.text('修改记忆'), findsNothing);
    expect(find.text('账号 A 的记忆'), findsNothing);
    expect(find.text('账号 B 的记忆'), findsOneWidget);
    expect(accountA.replaceMemoryRequestIds, isEmpty);
    expect(accountB.replaceMemoryRequestIds, isEmpty);
  });
}
