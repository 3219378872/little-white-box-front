import '../api/json_int64.dart';

/// 应用内全部路由路径的唯一来源：路由表用 `*Pattern` 声明带参数的路径，页面跳转用常量与 builder。
///
/// URL 文本属于对外契约（深链、书签、e2e 与公开路由判定都依赖它），修改前先改
/// `test/core/router/app_routes_test.dart` 中的固定值并评估兼容性。
abstract final class AppRoutes {
  // 一级导航页。
  static const feed = '/feed';
  static const search = '/search';
  static const messages = '/messages';
  static const profile = '/profile';

  // 认证页，位于应用壳之外。
  static const login = '/auth/login';
  static const register = '/auth/register';

  // 无参数的二级页。
  static const postNew = '/post/new';
  static const profileEdit = '/profile/edit';
  static const assistant = '/messages/assistant';
  static const assistantMemory = '/messages/assistant/memory';
  static const ads = '/ads';
  static const adNew = '/ads/new';
  static const advertiser = '/ads/advertiser';
  static const review = '/review';

  // 早期独立 Agent 入口，只在路由表里重定向到消息页下的新路径。
  static const legacyAssistant = '/assistant';
  static const legacyAssistantMemory = '/assistant/memory';

  // 路由表中的参数化路径；参数名与页面读取的 pathParameters 键一致。
  static const messageThreadPattern = '/messages/:conversationId';
  static const postEditPattern = '/post/edit/:postId';
  static const postDetailPattern = '/post/:postId';
  static const userProfilePattern = '/user/:userId';
  static const adDetailPattern = '/ads/:adId';
  static const adEditPattern = '/ads/:adId/edit';
  static const reviewTaskPattern = '/review/tasks/:taskId';

  /// 帖子详情；ID 按 [jsonInt64Id] 规范为十进制串，避免大整数在 Web 上被改写。
  static String postDetail(Object postId) => '/post/${jsonInt64Id(postId)}';

  /// 编辑已有帖子。
  static String postEdit(Object postId) => '/post/edit/${jsonInt64Id(postId)}';

  /// 用户主页。
  static String userProfile(Object userId) => '/user/${jsonInt64Id(userId)}';

  /// 广告详情。
  static String adDetail(Object adId) => '/ads/${jsonInt64Id(adId)}';

  /// 编辑已有广告。
  static String adEdit(Object adId) => '/ads/${jsonInt64Id(adId)}/edit';

  /// 审核任务详情。
  static String reviewTask(Object taskId) =>
      '/review/tasks/${jsonInt64Id(taskId)}';

  /// 私信线程；对方 ID 与昵称走查询参数，供线程页在会话列表外直接打开时显示标题。
  ///
  /// ID 按原值插值（与会话列表既有跳转一致），合法性由路由表的 redirect 校验。
  static String messageThread(
    Object conversationId, {
    required Object targetUserId,
    required String targetUserName,
  }) => Uri(
    path: '/messages/$conversationId',
    queryParameters: {
      'targetUserId': '$targetUserId',
      'targetUserName': targetUserName,
    },
  ).toString();
}
