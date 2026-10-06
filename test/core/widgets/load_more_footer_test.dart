import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/widgets/load_more_footer.dart';
import 'package:xiaobaihe_app/core/widgets/loading_view.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  Future<void> pump(WidgetTester tester, LoadMoreFooter footer) {
    return tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: ListView(children: [footer]),
      ),
    );
  }

  testWidgets('loading wins over error, button and end states', (tester) async {
    await pump(
      tester,
      LoadMoreFooter(
        isLoading: true,
        error: '网络不可用',
        onLoadMore: () {},
        showEnd: true,
      ),
    );

    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text('网络不可用'), findsNothing);
    expect(find.text('加载更多'), findsNothing);
    expect(find.text('— 没有更多了 —'), findsNothing);
  });

  testWidgets('error shows the message and retries in place', (tester) async {
    var retried = 0;
    var loaded = 0;
    await pump(
      tester,
      LoadMoreFooter(
        isLoading: false,
        error: '网络不可用',
        onRetry: () => retried++,
        onLoadMore: () => loaded++,
        showEnd: true,
      ),
    );

    expect(find.text('网络不可用'), findsOneWidget);
    expect(find.text('— 没有更多了 —'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect((retried, loaded), (1, 0));
  });

  testWidgets('error retry falls back to onLoadMore', (tester) async {
    var loaded = 0;
    await pump(
      tester,
      LoadMoreFooter(
        isLoading: false,
        error: '加载失败',
        onLoadMore: () => loaded++,
      ),
    );

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(loaded, 1);
  });

  testWidgets('manual lists show a load more button when idle', (tester) async {
    var loaded = 0;
    await pump(
      tester,
      LoadMoreFooter(isLoading: false, onLoadMore: () => loaded++),
    );

    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();
    expect(loaded, 1);
  });

  testWidgets('shows the end marker only when requested', (tester) async {
    await pump(tester, const LoadMoreFooter(isLoading: false, showEnd: true));
    expect(find.text('— 没有更多了 —'), findsOneWidget);

    await pump(tester, const LoadMoreFooter(isLoading: false));
    expect(find.text('— 没有更多了 —'), findsNothing);
    expect(find.byType(LoadingView), findsNothing);
  });
}
