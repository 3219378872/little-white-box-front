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
      overrides: [assistantRepositoryProvider.overrideWithValue(source)],
      child: const MaterialApp(builder: foruiTestBuilder, home: MemoryPage()),
    ),
  );
  await tester.pump();
  await tester.pump();
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

  testWidgets('lists memories and distinguishes confirmed records', (
    tester,
  ) async {
    final source = _grantedSource()
      ..memories = const [
        MemoryRecord(
          id: 1,
          layer: 'profile',
          dimension: 'tag',
          value: '美食',
          score: 0.9,
          source: 'explicit',
          confirmed: true,
        ),
        MemoryRecord(
          id: 2,
          layer: 'interest',
          dimension: 'author',
          value: '萌萌哒小兔',
          score: 0.4,
          source: 'behavior',
        ),
      ];
    await _pumpMemory(tester, source);

    expect(find.text('美食'), findsOneWidget);
    expect(find.text('萌萌哒小兔'), findsOneWidget);
    expect(find.text('已确认'), findsOneWidget);
    expect(find.text('可能的偏好'), findsOneWidget);
    expect(find.text('修改'), findsNWidgets(2));
    expect(find.text('不要记住这个'), findsNWidgets(2));
  });

  testWidgets('stale consent is read-only with an upgrade prompt', (
    tester,
  ) async {
    final source = FakeAssistantSource()
      ..granted = true
      ..consentVersion = 1
      ..currentVersion = 2
      ..memories = const [
        MemoryRecord(
          id: 1,
          layer: 'profile',
          dimension: 'tag',
          value: '美食',
          confirmed: true,
        ),
      ];
    await _pumpMemory(tester, source);

    expect(find.text('需要升级 Agent 授权才能修改记忆'), findsOneWidget);
    expect(find.text('美食'), findsOneWidget);
    expect(find.text('修改'), findsNothing);
  });
}
