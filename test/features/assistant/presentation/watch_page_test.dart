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

FakeAssistantSource _grantedSource() => FakeAssistantSource()
  ..granted = true
  ..consentVersion = 2
  ..currentVersion = 2;

Future<void> _pumpWatch(WidgetTester tester, FakeAssistantSource source) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [assistantRepositoryProvider.overrideWithValue(source)],
      child: const MaterialApp(builder: foruiTestBuilder, home: WatchPage()),
    ),
  );
  await tester.pump();
  await tester.pump();
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
}
