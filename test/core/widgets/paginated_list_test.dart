import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
