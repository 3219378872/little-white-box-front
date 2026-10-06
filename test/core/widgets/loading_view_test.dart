import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xiaobaihe_app/core/widgets/loading_view.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('centers a progress indicator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(builder: foruiTestBuilder, home: const LoadingView()),
    );

    // LoadingView 直接构建 Center，进度圈位于其中。
    final center = find
        .descendant(of: find.byType(LoadingView), matching: find.byType(Center))
        .first;
    final progress = find.descendant(
      of: center,
      matching: find.byType(FCircularProgress),
    );
    expect(progress, findsOneWidget);
  });
}
