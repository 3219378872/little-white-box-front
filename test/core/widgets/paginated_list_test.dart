import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/widgets/error_view.dart';
import 'package:xiaobaihe_app/core/widgets/paginated_list.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('allows refreshing an empty list', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: PaginatedListView<String>(
          items: const [],
          hasMore: false,
          isLoading: false,
          isLoadingMore: false,
          itemBuilder: (_, item) => Text(item),
          onLoadMore: () {},
          onRefresh: () => refreshes++,
        ),
      ),
    );

    expect(find.text('暂无内容'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 220));
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });

  testWidgets('shows an error footer with retry when load-more fails',
      (tester) async {
    var loadMoreCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: PaginatedListView<String>(
          items: const ['a', 'b'],
          hasMore: true,
          isLoading: false,
          isLoadingMore: false,
          error: '网络开小差了',
          itemBuilder: (_, item) => Text(item),
          onLoadMore: () => loadMoreCalls++,
          onRefresh: () {},
        ),
      ),
    );

    expect(find.text('重试'), findsOneWidget);
    expect(find.text('网络开小差了'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(loadMoreCalls, 1);
  });

  testWidgets('does not auto trigger load-more while an error is visible',
      (tester) async {
    var loadMoreCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: PaginatedListView<String>(
          items: List.generate(30, (i) => 'item-$i'),
          hasMore: true,
          isLoading: false,
          isLoadingMore: false,
          error: '网络开小差了',
          itemBuilder: (_, item) => Text(item, textDirection: TextDirection.ltr),
          onLoadMore: () => loadMoreCalls++,
          onRefresh: () {},
        ),
      ),
    );
    final callsBefore = loadMoreCalls;

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(loadMoreCalls, callsBefore);
  });

  testWidgets('empty list with error shows ErrorView instead of empty hint',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: PaginatedListView<String>(
          items: const [],
          hasMore: true,
          isLoading: false,
          isLoadingMore: false,
          error: '加载失败',
          itemBuilder: (_, item) => Text(item),
          onLoadMore: () {},
          onRefresh: () {},
        ),
      ),
    );

    expect(find.text('暂无内容'), findsNothing);
    expect(find.byType(ErrorView), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
