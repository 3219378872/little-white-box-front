part of 'mock_router.dart';

/// In-memory Gateway mock aligned with `app/gateway/gateway.api`.
///
/// Success bodies are the typed payloads (no `{code,desc,data}` wrapper).
/// Errors use `{code, message}` and the same HTTP statuses as `errx`.

const mockDevPassword = '123456';

/// 与真实网关对齐：access token 30 分钟，refresh token 7 天。
const int _mockAccessTtlSeconds = 30 * 60;
const int _mockRefreshTtlSeconds = 7 * 24 * 60 * 60;

const _clientAllowedActions = {
  'exposure',
  'click',
  'dwell',
  'play',
  'view',
  'share',
  'hide',
  'dislike',
};

const _supportedActions = {
  ..._clientAllowedActions,
  'like',
  'unlike',
  'favorite',
  'unfavorite',
  'comment',
  'follow',
  'unfollow',
};

const _durationActions = {'dwell', 'play', 'view'};

int _nextPostId = 100;
int _nextCommentId = 200;
int _nextMessageId = 10000;
int _nextConversationId = 100;
int _nextUserId = 10;
int _nextMediaId = 1000;

late List<Map<String, dynamic>> _posts;
late Map<int, List<Map<String, dynamic>>> _comments;
late Map<int, Map<String, dynamic>> _users;
late Map<String, String> _passwords;
late Map<int, Set<int>> _likedByUser;
late Map<int, Set<int>> _favoritedByUser;
late Map<int, Set<int>> _followedByUser;
late Map<String, int> _postIdempotencyKeys;
late Map<String, int> _commentIdempotencyKeys;
late Map<String, int> _behaviorEventIds;
late Map<String, int> _messageIdempotencyKeys;
late List<Map<String, dynamic>> _conversations;
late Map<int, List<Map<String, dynamic>>> _messages;
late Map<int, bool> _personalizationEnabled;
late Map<int, Map<String, dynamic>> _agentConsent;
late Map<int, List<Map<String, dynamic>>> _assistantMemories;
late Map<int, List<Map<String, dynamic>>> _assistantWatches;
late Map<int, Map<String, dynamic>> _assistantThreads;
late Map<int, List<Map<String, dynamic>>> _assistantMessages;
late Map<int, List<Map<String, dynamic>>> _assistantRunEvents;
late Map<int, Map<String, dynamic>> _assistantRuns;
late Map<int, List<Map<String, dynamic>>> _assistantQueue;
late Map<int, List<Map<String, dynamic>>> _assistantMemoryChanges;
late int _messageSeedTime;
late Set<String> _usedRefreshTokens;
int _mockJwtNonce = 0;
int _nextWatchId = 1;
int _nextAssistantMessageId = 1;
int _nextAssistantRunId = 1;

int _nextMemoryId = 1;
int _nextChangeId = 1;

bool _seeded = false;

void resetMockState() {
  _nextPostId = 100;
  _nextCommentId = 200;
  _nextMessageId = 10000;
  _nextConversationId = 100;
  _nextUserId = 10;
  _nextMediaId = 1000;
  _posts = seedPosts.map(_copyMap).toList();
  _comments = {
    for (final entry in seedComments.entries)
      entry.key: entry.value.map(_copyMap).toList(),
  };
  _users = {
    for (final entry in seedUsers.entries) entry.key: _copyMap(entry.value),
  };
  _passwords = {
    for (final user in _users.values)
      user['username'] as String: mockDevPassword,
  };
  _likedByUser = {
    1: {
      for (final post in _posts)
        if (post['isLiked'] == true) (post['id'] as num).toInt(),
    },
  };
  _favoritedByUser = {};
  _followedByUser = {
    1: {2, 3},
  };
  _postIdempotencyKeys = {};
  _commentIdempotencyKeys = {};
  _behaviorEventIds = {};
  _messageIdempotencyKeys = {};
  _messageSeedTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  _conversations = [
    {
      'id': 11,
      'targetUserId': 2,
      'targetUserName': '萌萌哒小兔',
      'targetUserAvatar': '',
      'lastMessage': '周末一起去探店吗？',
      'lastMessageTime': _messageSeedTime - 300,
      'unreadCount': 2,
    },
    {
      'id': 12,
      'targetUserId': 3,
      'targetUserName': '科技宅小明',
      'targetUserAvatar': '',
      'lastMessage': '评测文章已经更新啦',
      'lastMessageTime': _messageSeedTime - 3600,
      'unreadCount': 0,
    },
  ];
  _messages = {
    11: [
      {
        'id': 101,
        'conversationId': 11,
        'senderId': 2,
        'receiverId': 1,
        'content': '发现一家新的面馆，味道很不错。',
        'msgType': 1,
        'status': 1,
        'createdAt': _messageSeedTime - 900,
      },
      {
        'id': 102,
        'conversationId': 11,
        'senderId': 2,
        'receiverId': 1,
        'content': '周末一起去探店吗？',
        'msgType': 1,
        'status': 1,
        'createdAt': _messageSeedTime - 300,
      },
    ],
    12: [
      {
        'id': 201,
        'conversationId': 12,
        'senderId': 1,
        'receiverId': 3,
        'content': '想看看最近的手机推荐。',
        'msgType': 1,
        'status': 1,
        'createdAt': _messageSeedTime - 7200,
      },
      {
        'id': 202,
        'conversationId': 12,
        'senderId': 3,
        'receiverId': 1,
        'content': '评测文章已经更新啦',
        'msgType': 1,
        'status': 1,
        'createdAt': _messageSeedTime - 3600,
      },
    ],
  };
  _personalizationEnabled = {for (final id in _users.keys) id: true};
  _agentConsent = {
    for (final id in _users.keys)
      id: {
        'granted': true,
        'grantedAt': DateTime.now().millisecondsSinceEpoch,
        'revokedAt': 0,
        'consentVersion': 2,
        'currentVersion': 2,
      },
  };
  _nextWatchId = 2;
  _nextAssistantMessageId = 1;
  _nextAssistantRunId = 1;

  _nextMemoryId = 3;
  _nextChangeId = 1;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  _assistantMemories = {
    1: [
      {
        'id': 1,
        'target': 'memory',
        'content': '喜欢美食探店',
        'version': 1,
        'createdAtMs': nowMs,
        'updatedAtMs': nowMs,
      },
      {
        'id': 2,
        'target': 'user',
        'content': '常用中文交流',
        'version': 1,
        'createdAtMs': nowMs,
        'updatedAtMs': nowMs,
      },
    ],
  };
  _assistantWatches = {
    1: [
      {
        'id': 1,
        'conditionType': 'author_new_post',
        'targetType': 'author',
        'targetId': 2,
        'targetText': '',
        'enabled': true,
        'version': 1,
        'createdAt': nowMs,
      },
    ],
  };
  _assistantThreads = {
    for (final id in _users.keys)
      id: {
        'sessionId': 1,
        'unreadCount': id == 1 ? 1 : 0,
        'lastMessageId': 0,
        'lastMessagePreview': id == 1 ? '有新的作者动态' : '',
        'lastMessageAtMs': nowMs,
        'activeRunId': 0,
        'activeRunStatus': '',
        'activeRunPhase': '',
      },
  };
  _assistantMessages = {1: <Map<String, dynamic>>[]};
  _assistantRunEvents = {};
  _assistantRuns = {};
  _assistantQueue = {};
  _assistantMemoryChanges = {};
  _usedRefreshTokens = {};
  _mockJwtNonce = 0;
  _seeded = true;
}

void _ensureState() {
  if (!_seeded) resetMockState();
}

const _watchConditions = {
  'author_new_post': 'author',
  'tag_new_post': 'tag',
  'keyword_new_post': 'keyword',
  'post_revised': 'post',
};
