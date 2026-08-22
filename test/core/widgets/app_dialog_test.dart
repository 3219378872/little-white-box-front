import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xiaobaihe_app/core/widgets/app_dialog.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('showAppAlert opens a dialog and closes it via the action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FButton(
                onPress: () => showAppAlert(
                  context: context,
                  title: '删除帖子',
                  message: '该操作不可撤销',
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('删除帖子'), findsOneWidget);
    expect(find.text('该操作不可撤销'), findsOneWidget);

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    expect(find.text('该操作不可撤销'), findsNothing);
  });

  testWidgets('showAppAlert honors a custom action label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FButton(
                onPress: () => showAppAlert(
                  context: context,
                  title: '提示',
                  message: '已同步',
                  actionLabel: '好的',
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('好的'), findsOneWidget);
  });
}
