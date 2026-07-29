import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/search/application/search_notifier.dart';
import 'package:xiaobaihe_app/features/search/data/search_models.dart';
import 'package:xiaobaihe_app/features/search/data/search_repository.dart';
import 'package:xiaobaihe_app/features/search/presentation/search_page.dart';

import '../../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('shows all-search results and opens a post', (tester) async {
    var openedPost = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_PageSearchSource()),
        ],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: SearchPage(onOpenPost: (id) => openedPost = id),
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText), 'flutter');
    await tester.tap(find.byKey(const Key('search-submit')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Result post'), findsOneWidget);
    await tester.tap(find.text('Result post'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(openedPost, 11);
  });
}

class _PageSearchSource implements SearchDataSource {
  @override
  Future<SearchResults> search({
    required SearchScope scope,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const SearchResults(
      posts: [
        SearchPostResult(
          id: 11,
          title: 'Result post',
          contentHighlight: 'matched',
          authorName: 'Author',
          likeCount: 2,
          commentCount: 1,
          createdAt: 0,
        ),
      ],
    );
  }
}
