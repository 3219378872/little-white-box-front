import '../../../core/api/json_int64.dart';

/// 搜索范围，对应搜索页的「综合 / 用户 / 标签」三个标签页。
enum SearchScope { all, users, tags }

/// 综合搜索命中的帖子；`contentHighlight` 是服务端带 `<em>` 标记的正文片段。
class SearchPostResult {
  final Object id;
  final String title;
  final String contentHighlight;
  final Object authorId;
  final String authorName;
  final String authorAvatar;
  final int likeCount;
  final int commentCount;
  final int createdAt;

  const SearchPostResult({
    required this.id,
    required this.title,
    required this.contentHighlight,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
  });

  /// 作者名缺失时的展示兜底。
  String get displayAuthor => authorName.isEmpty ? '未知作者' : authorName;

  /// 解析单条帖子结果；ID 不是正整数时抛 [FormatException]，由仓储统一转成格式错误。
  factory SearchPostResult.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (!jsonInt64IsPositive(id)) {
      throw const FormatException('invalid search post id');
    }
    return SearchPostResult(
      id: id,
      title: _string(json['title']),
      contentHighlight: _string(json['contentHighlight']),
      authorId: json['authorId'] ?? 0,
      authorName: _string(json['authorName']),
      authorAvatar: _string(json['authorAvatar']),
      likeCount: _integer(json['likeCount']),
      commentCount: _integer(json['commentCount']),
      createdAt: _integer(json['createdAt']),
    );
  }
}

/// 搜索命中的用户。
class SearchUserResult {
  final Object id;
  final String username;
  final String nickname;
  final String avatarUrl;
  final String bio;
  final int followerCount;

  const SearchUserResult({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatarUrl,
    required this.bio,
    required this.followerCount,
  });

  /// 优先展示昵称，未设置时退回用户名。
  String get displayName => nickname.isEmpty ? username : nickname;

  /// 解析单条用户结果；ID 不是正整数时抛 [FormatException]。
  factory SearchUserResult.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (!jsonInt64IsPositive(id)) {
      throw const FormatException('invalid search user id');
    }
    return SearchUserResult(
      id: id,
      username: _string(json['username']),
      nickname: _string(json['nickname']),
      avatarUrl: _string(json['avatarUrl']),
      bio: _string(json['bio']),
      followerCount: _integer(json['followerCount']),
    );
  }
}

/// 搜索命中的标签及其帖子数；点击后以标签名再搜。
class SearchTagResult {
  final String name;
  final int postCount;

  const SearchTagResult({required this.name, required this.postCount});

  /// 解析单条标签结果；去空白后为空的标签名视为格式错误。
  factory SearchTagResult.fromJson(Map<String, dynamic> json) {
    final name = _string(json['name']).trim();
    if (name.isEmpty) throw const FormatException('invalid search tag name');
    return SearchTagResult(name: name, postCount: _integer(json['postCount']));
  }
}

/// 一次搜索（或合并后多页）的结果集合。
///
/// [total] 只有用户范围由服务端返回；[degraded] 与 [unavailableTypes] 表示综合搜索
/// 有部分类型未能返回，页面据此展示降级横幅。
class SearchResults {
  final List<SearchPostResult> posts;
  final List<SearchUserResult> users;
  final List<SearchTagResult> tags;
  final int total;
  final bool degraded;
  final List<String> unavailableTypes;

  const SearchResults({
    this.posts = const [],
    this.users = const [],
    this.tags = const [],
    this.total = 0,
    this.degraded = false,
    this.unavailableTypes = const [],
  });

  bool get isEmpty => posts.isEmpty && users.isEmpty && tags.isEmpty;
}

// 宽松读取字符串字段，缺失时为空串。
String _string(Object? value) => value?.toString() ?? '';

// 宽松读取计数字段：兼容数字与数字字符串，无法解析时记为 0。
int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
