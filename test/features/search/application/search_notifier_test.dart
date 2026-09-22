import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/search/application/search_notifier.dart';
import 'package:xiaobaihe_app/features/search/data/search_models.dart';
import 'package:xiaobaihe_app/features/search/data/search_repository.dart';

void main() {
  test('ignores a stale search response', () async {
    final first = Completer<SearchResults>();
    final second = Completer<SearchResults>();
    final repository = _CompleterSearchSource([first, second]);
    final notifier = SearchNotifier(repository);

    final oldSearch = notifier.search('old');
    final newSearch = notifier.search('new');
    second.complete(
      const SearchResults(tags: [SearchTagResult(name: 'new', postCount: 1)]),
    );
    await newSearch;
    first.complete(
      const SearchResults(tags: [SearchTagResult(name: 'old', postCount: 1)]),
    );
    await oldSearch;

    expect(notifier.state.keyword, 'new');
    expect(notifier.state.results.tags.single.name, 'new');
  });

  test('changing scope reruns the current keyword', () async {
    final repository = _RecordingSearchSource();
    final notifier = SearchNotifier(repository);

    await notifier.search('query');
    notifier.selectScope(SearchScope.users);
    await Future<void>.delayed(Duration.zero);

    expect(repository.scopes, [SearchScope.all, SearchScope.users]);
    expect(notifier.state.scope, SearchScope.users);
    expect(notifier.state.phase, SearchPhase.success);
  });

  test('loads the next page and stops when the page is short', () async {
    final repository = _PagedSearchSource();
    final notifier = SearchNotifier(repository);

    await notifier.search('query');
    expect(notifier.state.hasMore, isTrue);
    expect(notifier.state.results.posts, hasLength(20));

    await notifier.loadMore();
    expect(notifier.state.page, 2);
    expect(notifier.state.results.posts, hasLength(21));
    expect(notifier.state.hasMore, isFalse);
    expect(repository.pages, [1, 2]);
  });
}

class _CompleterSearchSource implements SearchDataSource {
  final List<Completer<SearchResults>> responses;

  _CompleterSearchSource(this.responses);

  @override
  Future<SearchResults> search({
    required SearchScope scope,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) => responses.removeAt(0).future;
}

class _PagedSearchSource implements SearchDataSource {
  final pages = <int>[];

  @override
  Future<SearchResults> search({
    required SearchScope scope,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    pages.add(page);
    if (page == 1) {
      return SearchResults(
        posts: [
          for (var i = 0; i < pageSize; i++)
            SearchPostResult(
              id: i + 1,
              title: 'p$i',
              contentHighlight: '',
              authorId: 1,
              authorName: 'a',
              authorAvatar: '',
              likeCount: 0,
              commentCount: 0,
              createdAt: 0,
            ),
        ],
      );
    }
    return const SearchResults(
      posts: [
        SearchPostResult(
          id: 100,
          title: 'last',
          contentHighlight: '',
          authorId: 1,
          authorName: 'a',
          authorAvatar: '',
          likeCount: 0,
          commentCount: 0,
          createdAt: 0,
        ),
      ],
    );
  }
}

class _RecordingSearchSource implements SearchDataSource {
  final List<SearchScope> scopes = [];

  @override
  Future<SearchResults> search({
    required SearchScope scope,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    scopes.add(scope);
    return const SearchResults();
  }
}
