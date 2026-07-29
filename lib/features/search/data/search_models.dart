enum SearchScope { all, users, tags }

class SearchPostResult {
  final int id;
  final String title;
  final String contentHighlight;
  final String authorName;
  final int likeCount;
  final int commentCount;
  final int createdAt;

  const SearchPostResult({
    required this.id,
    required this.title,
    required this.contentHighlight,
    required this.authorName,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
  });

  factory SearchPostResult.fromJson(Map<String, dynamic> json) {
    final id = _integer(json['id']);
    if (id <= 0) throw const FormatException('invalid search post id');
    return SearchPostResult(
      id: id,
      title: _string(json['title']),
      contentHighlight: _string(json['contentHighlight']),
      authorName: _string(json['authorName']),
      likeCount: _integer(json['likeCount']),
      commentCount: _integer(json['commentCount']),
      createdAt: _integer(json['createdAt']),
    );
  }
}

class SearchUserResult {
  final int id;
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

  String get displayName => nickname.isEmpty ? username : nickname;

  factory SearchUserResult.fromJson(Map<String, dynamic> json) {
    final id = _integer(json['id']);
    if (id <= 0) throw const FormatException('invalid search user id');
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

class SearchTagResult {
  final String name;
  final int postCount;

  const SearchTagResult({required this.name, required this.postCount});

  factory SearchTagResult.fromJson(Map<String, dynamic> json) {
    final name = _string(json['name']).trim();
    if (name.isEmpty) throw const FormatException('invalid search tag name');
    return SearchTagResult(name: name, postCount: _integer(json['postCount']));
  }
}

class SearchResults {
  final List<SearchPostResult> posts;
  final List<SearchUserResult> users;
  final List<SearchTagResult> tags;
  final int total;

  const SearchResults({
    this.posts = const [],
    this.users = const [],
    this.tags = const [],
    this.total = 0,
  });

  bool get isEmpty => posts.isEmpty && users.isEmpty && tags.isEmpty;
}

String _string(Object? value) => value?.toString() ?? '';

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
