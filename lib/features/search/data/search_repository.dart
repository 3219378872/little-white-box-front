import '../../../core/api/api_exceptions.dart';
import '../../../core/api/v2_api_client.dart';
import 'search_models.dart';

abstract interface class SearchDataSource {
  Future<SearchResults> search({
    required SearchScope scope,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  });
}

class SearchRepository implements SearchDataSource {
  final V2ApiClient _client;

  const SearchRepository({V2ApiClient client = const V2ApiClient()})
    : _client = client;

  @override
  Future<SearchResults> search({
    required SearchScope scope,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      throw const ApiException('请输入搜索内容');
    }
    if (page <= 0 || pageSize <= 0 || pageSize > 100) {
      throw const ApiException('搜索分页参数无效');
    }

    final response = await switch (scope) {
      SearchScope.all => _client.get(
        '/api/v2/search',
        query: {'keyword': normalized, 'page': page, 'pageSize': pageSize},
      ),
      SearchScope.users => _client.get(
        '/api/v2/search/users',
        query: {'keyword': normalized, 'page': page, 'pageSize': pageSize},
      ),
      SearchScope.tags => _client.get(
        '/api/v2/search/tags',
        query: {'keyword': normalized, 'limit': pageSize},
      ),
    };

    try {
      return switch (scope) {
        SearchScope.all => SearchResults(
          posts: _list(response['posts'], SearchPostResult.fromJson),
          users: _list(response['users'], SearchUserResult.fromJson),
          tags: _list(response['tags'], SearchTagResult.fromJson),
          degraded: response['degraded'] == true,
          unavailableTypes: _strings(response['unavailableTypes']),
        ),
        SearchScope.users => SearchResults(
          users: _list(response['users'], SearchUserResult.fromJson),
          total: _integer(response['total']),
        ),
        SearchScope.tags => SearchResults(
          tags: _list(response['tags'], SearchTagResult.fromJson),
        ),
      };
    } on FormatException {
      throw const ApiException('搜索响应格式无效');
    }
  }

  static List<T> _list<T>(
    Object? value,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (value is! List) throw const FormatException('missing result list');
    return value
        .map((item) {
          if (item is! Map) throw const FormatException('invalid result item');
          return decode(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
  }

  static int _integer(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _strings(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('invalid unavailable types');
    }
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
