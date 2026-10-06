import '../../../core/api/api_exceptions.dart';
import '../../../core/api/response_fields.dart';
import '../../../core/api/v2_api_client.dart';
import 'search_models.dart';

/// 搜索数据源接口，供 `SearchNotifier` 依赖、测试替换。
abstract interface class SearchDataSource {
  /// 按范围搜索一页结果；标签范围只取前 [pageSize] 条，不支持翻页。
  Future<SearchResults> search({
    required SearchScope scope,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  });
}

/// 走 Gateway v2 搜索接口的实现：综合 `/api/v2/search`、用户 `/api/v2/search/users`、
/// 标签 `/api/v2/search/tags`。
///
/// 参数非法与响应格式错误都转成 [ApiException]，页面直接展示其文案。
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
    // 本地参数校验：空关键词与越界分页（pageSize 上限 100）不发请求。
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      throw const ApiException('请输入搜索内容');
    }
    if (page <= 0 || pageSize <= 0 || pageSize > 100) {
      throw const ApiException('搜索分页参数无效');
    }

    // 按范围选择接口；标签接口不分页，只接受 limit。
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

    // 按范围解析响应：综合页三类结果都必须存在，用户页额外读取 total；
    // 任一条目解析失败都视为整页响应无效。
    return decodeResponse(
      '搜索响应格式无效',
      () => switch (scope) {
        SearchScope.all => SearchResults(
          posts: _list(
            requiredResponseList(response, 'posts'),
            SearchPostResult.fromJson,
          ),
          users: _list(
            requiredResponseList(response, 'users'),
            SearchUserResult.fromJson,
          ),
          tags: _list(
            requiredResponseList(response, 'tags'),
            SearchTagResult.fromJson,
          ),
          degraded: response['degraded'] == true,
          unavailableTypes: _strings(response['unavailableTypes']),
        ),
        SearchScope.users => SearchResults(
          users: _list(
            requiredResponseList(response, 'users'),
            SearchUserResult.fromJson,
          ),
          total: requiredResponseCount(response, 'total'),
        ),
        SearchScope.tags => SearchResults(
          tags: _list(
            requiredResponseList(response, 'tags'),
            SearchTagResult.fromJson,
          ),
        ),
      },
    );
  }

  // 逐项解码结果数组；非对象元素视为格式错误。
  static List<T> _list<T>(
    List<dynamic> value,
    T Function(Map<String, dynamic>) decode,
  ) {
    return value
        .map((item) {
          if (item is! Map) throw const FormatException('invalid result item');
          return decode(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
  }

  // 读取可选的不可用类型列表；字段缺失视为空，类型不对视为格式错误。
  static List<String> _strings(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('invalid unavailable types');
    }
    return value.map((item) => item.toString()).toList(growable: false);
  }
}
