import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/feed/presentation/feed_page.dart';

void main() {
  testWidgets('FeedPage shows 推荐 and 关注 tabs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FeedPage())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('关注'), findsOneWidget);
  });

  testWidgets('关注 tab shows placeholder', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FeedPage())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('关注'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('关注流功能开发中'), findsOneWidget);
  });
}
