import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xiaobaihe_app/core/widgets/app_toast.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  Future<void> pumpTrigger(
    WidgetTester tester,
    void Function(BuildContext) onTap,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FButton(
                onPress: () => onTap(context),
                child: const Text('触发'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('showAppError surfaces a destructive toast', (tester) async {
    await pumpTrigger(tester, (context) => showAppError(context, '发布失败'));

    await tester.tap(find.text('触发'));
    await tester.pumpAndSettle();

    expect(find.text('发布失败'), findsOneWidget);

    // 等 toast 自动消失，避免测试结束时残留定时器。
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('发布失败'), findsNothing);
  });

  testWidgets('showAppSuccess surfaces a success toast', (tester) async {
    await pumpTrigger(tester, (context) => showAppSuccess(context, '已保存'));

    await tester.tap(find.text('触发'));
    await tester.pumpAndSettle();

    expect(find.text('已保存'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('已保存'), findsNothing);
  });
}
