import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_notifier.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/assistant/presentation/assistant_page.dart';
import '../../features/assistant/presentation/memory_page.dart';
import '../../features/ads/presentation/ad_detail_page.dart';
import '../../features/ads/presentation/ad_editor_page.dart';
import '../../features/ads/presentation/ads_page.dart';
import '../../features/ads/presentation/advertiser_page.dart';
import '../../features/feed/presentation/feed_page.dart';
import '../../features/message/presentation/conversations_page.dart';
import '../../features/message/presentation/message_thread_page.dart';
import '../../features/post/presentation/post_detail_page.dart';
import '../../features/post/presentation/post_editor_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../../features/review/presentation/review_home_page.dart';
import '../../features/review/presentation/review_task_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../shell/auth_frame.dart';
import '../shell/main_shell.dart';
import 'app_route_observer.dart';
import 'public_routes.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// 应用路由表：未登录访问非公开路由跳登录、已登录访问登录页回首页；
/// 登录/注册页在壳外，其余页面都挂在 [MainShell] 下。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.feed,
    observers: [ref.read(appRouteObserverProvider)],
    refreshListenable: ref.read(authListenableProvider),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      if (authState.isLoading) return null;

      final isLoggedIn = authState.isAuthenticated;
      final location = state.matchedLocation;
      final isAuthRoute = location.startsWith('/auth');

      if (!isLoggedIn && !isPublicRoute(location)) {
        return AppRoutes.login;
      }
      if (isLoggedIn && isAuthRoute) {
        return AppRoutes.feed;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const AuthFrame(child: LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const AuthFrame(child: RegisterPage()),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) =>
            MainShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.feed,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FeedPage()),
          ),
          GoRoute(
            path: AppRoutes.search,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SearchPage()),
          ),
          GoRoute(
            path: AppRoutes.messages,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MessagesShell()),
          ),
          GoRoute(
            path: AppRoutes.assistantMemory,
            builder: (context, state) => const MessagesShell(
              assistantSelected: true,
              thread: MemoryPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.assistant,
            builder: (context, state) => MessagesShell(
              assistantSelected: true,
              thread: AssistantPage(
                contextPostId: state.uri.queryParameters['contextPostId'] ?? 0,
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.messageThreadPattern,
            redirect: (context, state) {
              final conversationId = int.tryParse(
                state.pathParameters['conversationId'] ?? '',
              );
              final targetUserId = int.tryParse(
                state.uri.queryParameters['targetUserId'] ?? '',
              );
              return conversationId == null ||
                      conversationId <= 0 ||
                      targetUserId == null ||
                      targetUserId <= 0
                  ? AppRoutes.messages
                  : null;
            },
            builder: (context, state) => MessagesShell(
              thread: MessageThreadPage(
                conversationId: state.pathParameters['conversationId']!,
                targetUserId: state.uri.queryParameters['targetUserId']!,
                targetUserName:
                    state.uri.queryParameters['targetUserName'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.legacyAssistantMemory,
            redirect: (context, state) => AppRoutes.assistantMemory,
          ),
          GoRoute(
            path: AppRoutes.legacyAssistant,
            redirect: (context, state) => AppRoutes.assistant,
          ),
          GoRoute(
            path: AppRoutes.postNew,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PostEditorPage()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: AppRoutes.postEditPattern,
            builder: (context, state) =>
                PostEditorPage(postId: state.pathParameters['postId']),
          ),
          GoRoute(
            path: AppRoutes.postDetailPattern,
            builder: (context, state) =>
                PostDetailPage(postId: state.pathParameters['postId']!),
          ),
          GoRoute(
            path: AppRoutes.userProfilePattern,
            builder: (context, state) =>
                ProfilePage(userId: state.pathParameters['userId']!),
          ),
          GoRoute(
            path: AppRoutes.profileEdit,
            builder: (context, state) => const EditProfilePage(),
          ),
          GoRoute(
            path: AppRoutes.ads,
            builder: (context, state) => const AdsPage(),
          ),
          GoRoute(
            path: AppRoutes.adNew,
            builder: (context, state) => const AdEditorPage(),
          ),
          GoRoute(
            path: AppRoutes.advertiser,
            builder: (context, state) => const AdvertiserPage(),
          ),
          GoRoute(
            path: AppRoutes.adDetailPattern,
            redirect: (context, state) =>
                _positiveIdOrNull(state.pathParameters['adId'], AppRoutes.ads),
            builder: (context, state) =>
                AdDetailPage(adId: state.pathParameters['adId']!),
          ),
          GoRoute(
            path: AppRoutes.adEditPattern,
            redirect: (context, state) =>
                _positiveIdOrNull(state.pathParameters['adId'], AppRoutes.ads),
            builder: (context, state) =>
                AdEditorPage(adId: state.pathParameters['adId']),
          ),
          GoRoute(
            path: AppRoutes.review,
            builder: (context, state) => const ReviewHomePage(),
          ),
          GoRoute(
            path: AppRoutes.reviewTaskPattern,
            redirect: (context, state) => _positiveIdOrNull(
              state.pathParameters['taskId'],
              AppRoutes.review,
            ),
            builder: (context, state) =>
                ReviewTaskPage(taskId: state.pathParameters['taskId']!),
          ),
        ],
      ),
    ],
  );
});

/// 路径 ID 必须是正整数，否则回到 [fallback]。
String? _positiveIdOrNull(String? raw, String fallback) {
  final id = BigInt.tryParse(raw ?? '');
  return id == null || id <= BigInt.zero ? fallback : null;
}
