import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xiaobaihe_app/core/widgets/forui_pull_to_refresh.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  Widget subject(Future<void> Function() onRefresh) {
    return MaterialApp(
      builder: foruiTestBuilder,
      home: ForuiPullToRefresh(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [SizedBox(height: 100, child: Text('内容'))],
        ),
      ),
    );
  }

  testWidgets('does not refresh below the trigger distance', (tester) async {
    var calls = 0;
    await tester.pumpWidget(subject(() async => calls++));

    await tester.drag(find.byType(ListView), const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('refreshes once and blocks re-entry until completion', (
    tester,
  ) async {
    var calls = 0;
    final completion = Completer<void>();
    await tester.pumpWidget(
      subject(() {
        calls++;
        return completion.future;
      }),
    );

    await tester.drag(find.byType(ListView), const Offset(0, 220));
    await tester.pump();

    expect(calls, 1);
    expect(find.byType(FCircularProgress), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 220));
    await tester.pump();
    expect(calls, 1);

    completion.complete();
    await tester.pumpAndSettle();
    expect(find.byType(FCircularProgress), findsNothing);
  });
}
