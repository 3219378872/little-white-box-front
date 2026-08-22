import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/widgets/error_view.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('ErrorView shows the message and retries on tap', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Center(
          child: ErrorView(message: '加载失败', onRetry: () => retried++),
        ),
      ),
    );

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(retried, 1);
  });

  testWidgets('ErrorView omits the retry button without a callback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const Center(child: ErrorView(message: '网络异常')),
      ),
    );

    expect(find.text('网络异常'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('EmptyView renders the custom message and icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const Center(
          child: EmptyView(message: '没有更多帖子', icon: Icons.inbox),
        ),
      ),
    );

    expect(find.text('没有更多帖子'), findsOneWidget);
    expect(find.byIcon(Icons.inbox), findsOneWidget);
  });

  testWidgets('EmptyView falls back to the default copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const Center(child: EmptyView()),
      ),
    );

    expect(find.text('暂无内容'), findsOneWidget);
  });
}
