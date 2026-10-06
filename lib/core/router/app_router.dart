import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/application/assistant_thread_notifier.dart';
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
import '../../features/message/application/message_notifiers.dart';
import '../../features/message/presentation/conversations_page.dart';
import '../../features/message/presentation/message_thread_page.dart';
import '../../features/post/presentation/post_detail_page.dart';
import '../../features/post/presentation/post_editor_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../../features/review/application/reviewer_access.dart';
import '../../features/review/presentation/review_home_page.dart';
import '../../features/review/presentation/review_task_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../theme/app_theme.dart';
import '../widgets/content_constraint.dart';
import 'app_route_observer.dart';
import 'public_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

enum _AppDestination { feed, search, create, messages, profile }

const _mobileDestinations = [
  _AppDestination.feed,
  _AppDestination.search,
  _AppDestination.create,
  _AppDestination.messages,
  _AppDestination.profile,
];

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/feed',
    observers: [ref.read(appRouteObserverProvider)],
    refreshListenable: ref.read(authListenableProvider),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      if (authState.isLoading) return null;

      final isLoggedIn = authState.isAuthenticated;
      final location = state.matchedLocation;
      final isAuthRoute = location.startsWith('/auth');

      if (!isLoggedIn && !isPublicRoute(location)) {
        return '/auth/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/feed';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const _AuthFrame(child: LoginPage()),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const _AuthFrame(child: RegisterPage()),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) =>
            MainShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/feed',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FeedPage()),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SearchPage()),
          ),
          GoRoute(
            path: '/messages',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MessagesShell()),
          ),
          GoRoute(
            path: '/messages/assistant/memory',
            builder: (context, state) => const MessagesShell(
              assistantSelected: true,
              thread: MemoryPage(),
            ),
          ),
          GoRoute(
            path: '/messages/assistant',
            builder: (context, state) => MessagesShell(
              assistantSelected: true,
              thread: AssistantPage(
                contextPostId: state.uri.queryParameters['contextPostId'] ?? 0,
              ),
            ),
          ),
          GoRoute(
            path: '/messages/:conversationId',
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
                  ? '/messages'
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
            path: '/assistant/memory',
            redirect: (context, state) => '/messages/assistant/memory',
          ),
          GoRoute(
            path: '/assistant',
            redirect: (context, state) => '/messages/assistant',
          ),
          GoRoute(
            path: '/post/new',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PostEditorPage()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: '/post/edit/:postId',
            builder: (context, state) =>
                PostEditorPage(postId: state.pathParameters['postId']),
          ),
          GoRoute(
            path: '/post/:postId',
            builder: (context, state) =>
                PostDetailPage(postId: state.pathParameters['postId']!),
          ),
          GoRoute(
            path: '/user/:userId',
            builder: (context, state) =>
                ProfilePage(userId: state.pathParameters['userId']!),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) => const EditProfilePage(),
          ),
          GoRoute(path: '/ads', builder: (context, state) => const AdsPage()),
          GoRoute(
            path: '/ads/new',
            builder: (context, state) => const AdEditorPage(),
          ),
          GoRoute(
            path: '/ads/advertiser',
            builder: (context, state) => const AdvertiserPage(),
          ),
          GoRoute(
            path: '/ads/:adId',
            redirect: (context, state) =>
                _positiveIdOrNull(state.pathParameters['adId'], '/ads'),
            builder: (context, state) =>
                AdDetailPage(adId: state.pathParameters['adId']!),
          ),
          GoRoute(
            path: '/ads/:adId/edit',
            redirect: (context, state) =>
                _positiveIdOrNull(state.pathParameters['adId'], '/ads'),
            builder: (context, state) =>
                AdEditorPage(adId: state.pathParameters['adId']),
          ),
          GoRoute(
            path: '/review',
            builder: (context, state) => const ReviewHomePage(),
          ),
          GoRoute(
            path: '/review/tasks/:taskId',
            redirect: (context, state) =>
                _positiveIdOrNull(state.pathParameters['taskId'], '/review'),
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

class MainShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const MainShell({super.key, required this.child, required this.location});

  void _onDestinationSelected(
    BuildContext context,
    WidgetRef ref,
    _AppDestination destination,
  ) {
    final auth = ref.read(authNotifierProvider);
    final isLoggedIn = auth.isAuthenticated;
    final protected =
        destination != _AppDestination.feed &&
        destination != _AppDestination.search;
    if (protected && !isLoggedIn) {
      context.push('/auth/login');
      return;
    }
    context.go(switch (destination) {
      _AppDestination.feed => '/feed',
      _AppDestination.search => '/search',
      _AppDestination.create => '/post/new',
      _AppDestination.messages => '/messages',
      _AppDestination.profile => '/profile',
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = _destinationFor(location);
    final messageUnread = ref.watch(
      unreadSummaryProvider.select((state) => state.summary.messageUnread),
    );
    final assistantUnread = ref.watch(
      assistantThreadProvider.select((state) => state.thread.unreadCount),
    );
    final navUnread = messageUnread + assistantUnread;
    final width = MediaQuery.sizeOf(context).width;
    final breakpoints = context.theme.breakpoints;
    final isDesktop = width >= breakpoints.lg;
    final horizontalPadding = width >= breakpoints.md ? 24.0 : 0.0;
    final showBottomNavigation = !isDesktop && _isPrimaryRoute(location);

    return FScaffold(
      childPad: false,
      sidebar: isDesktop
          ? _DesktopSidebar(
              selectedDestination: destination,
              messageUnread: navUnread,
              collapsed: width < breakpoints.xl,
              onDestinationSelected: (selected) =>
                  _onDestinationSelected(context, ref, selected),
            )
          : null,
      footer: showBottomNavigation
          ? _MobileBottomNavigation(
              destination: destination,
              messageUnread: navUnread,
              onChange: (selected) => _onDestinationSelected(
                context,
                ref,
                _mobileDestinations[selected],
              ),
            )
          : null,
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ContentConstraint(
              maxWidth: _contentMaxWidth(location, width),
              horizontalPadding: horizontalPadding,
              // Keep the nested Navigator's route barrier from pruning sidebar semantics.
              child: isDesktop
                  ? Semantics(container: true, child: child)
                  : child,
            ),
          ),
          const AssistantThreadPollBinding(),
          const ReviewerAccessRefreshBinding(),
        ],
      ),
    );
  }

  _AppDestination _destinationFor(String location) {
    if (location.startsWith('/search')) return _AppDestination.search;
    if (location.startsWith('/messages')) return _AppDestination.messages;
    if (location.startsWith('/profile') ||
        location.startsWith('/ads') ||
        location.startsWith('/review')) {
      return _AppDestination.profile;
    }
    if (location.startsWith('/post/new') || location.startsWith('/post/edit')) {
      return _AppDestination.create;
    }
    return _AppDestination.feed;
  }

  bool _isPrimaryRoute(String location) {
    return location == '/feed' ||
        location == '/search' ||
        location == '/messages' ||
        location == '/profile';
  }

  double _contentMaxWidth(String location, double width) {
    if (location.startsWith('/post/new') || location.startsWith('/post/edit')) {
      return 760;
    }
    if (location.startsWith('/post/')) return 720;
    if (location == '/messages' || location.startsWith('/messages/')) {
      return width >= 1024 ? 1100 : 720;
    }
    if (location == '/profile/edit') return 560;
    if (location == '/feed') {
      // Wide desktops add the side rail next to the fixed-width feed column.
      return width >= 1280
          ? AppTheme.feedColumnWidth + AppTheme.space6 + AppTheme.sideRailWidth
          : AppTheme.feedColumnWidth;
    }
    return 680;
  }
}

class _DesktopSidebar extends StatelessWidget {
  final _AppDestination selectedDestination;
  final int messageUnread;
  final bool collapsed;
  final ValueChanged<_AppDestination> onDestinationSelected;

  const _DesktopSidebar({
    required this.selectedDestination,
    required this.messageUnread,
    required this.collapsed,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    String? unreadSemanticsHint;
    if (messageUnread > 99) {
      unreadSemanticsHint = '99 条以上未读';
    } else if (messageUnread > 0) {
      unreadSemanticsHint = '$messageUnread 条未读';
    }

    Widget item(
      _AppDestination destination,
      IconData icon,
      String label, {
      int unread = 0,
      String? hint,
    }) {
      final selected = selectedDestination == destination;
      final Widget iconWidget = collapsed && unread > 0
          ? _UnreadNavigationIcon(icon: icon, count: unread, dot: true)
          : Icon(icon);
      final entry = MergeSemantics(
        child: FSidebarItem(
          icon: collapsed
              ? Semantics(label: label, hint: hint, child: iconWidget)
              : ExcludeSemantics(child: iconWidget),
          // The unread count sits at the trailing edge so it never overlaps
          // the icon or the label.
          label: collapsed
              ? null
              : Row(
                  children: [
                    Expanded(
                      child: Semantics(hint: hint, child: Text(label)),
                    ),
                    if (unread > 0)
                      ExcludeSemantics(child: _UnreadPill(count: unread)),
                  ],
                ),
          selected: selected,
          onPress: () => onDestinationSelected(destination),
        ),
      );
      return collapsed
          ? FTooltip(tipBuilder: (_, _) => Text(label), child: entry)
          : entry;
    }

    return FSidebar(
      style: FSidebarStyleDelta.delta(
        constraints: BoxConstraints.tightFor(
          width: collapsed
              ? AppTheme.sidebarCollapsedWidth
              : AppTheme.sidebarWidth,
        ),
      ),
      header: Padding(
        padding: EdgeInsets.fromLTRB(
          collapsed ? 0 : 24,
          AppTheme.space4,
          collapsed ? 0 : 24,
          AppTheme.space4,
        ),
        child: Row(
          mainAxisAlignment: collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(FLucideIcons.box, color: theme.colors.primary, size: 26),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Text(
                '小白盒',
                style: theme.typography.display.sm.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? AppTheme.space3 : AppTheme.space4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppTheme.space1,
            children: [
              item(_AppDestination.feed, FLucideIcons.house, '首页'),
              item(_AppDestination.search, FLucideIcons.search, '搜索'),
              item(
                _AppDestination.messages,
                FLucideIcons.messageSquare,
                '消息',
                unread: messageUnread,
                hint: unreadSemanticsHint,
              ),
              item(_AppDestination.create, FLucideIcons.squarePen, '发布'),
              item(_AppDestination.profile, FLucideIcons.userRound, '我的'),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnreadPill extends StatelessWidget {
  final int count;
  const _UnreadPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.destructive,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            widthFactor: 1,
            child: Text(
              count > 99 ? '99+' : '$count',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.destructiveForeground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileBottomNavigation extends StatelessWidget {
  final _AppDestination destination;
  final int messageUnread;
  final ValueChanged<int> onChange;

  const _MobileBottomNavigation({
    required this.destination,
    required this.messageUnread,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return FBottomNavigationBar(
      index: _mobileDestinations.indexOf(destination).clamp(0, 4),
      onChange: onChange,
      children: [
        const FBottomNavigationBarItem(
          icon: Icon(FLucideIcons.house),
          label: Text('首页'),
        ),
        const FBottomNavigationBarItem(
          icon: Icon(FLucideIcons.search),
          label: Text('搜索'),
        ),
        FBottomNavigationBarItem(
          semanticsLabel: '发布',
          icon: FTooltip(
            tipBuilder: (_, _) => const Text('发布'),
            child: Container(
              width: 44,
              height: 32,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: AppTheme.controlRadius,
              ),
              child: Icon(
                FLucideIcons.plus,
                color: colors.primaryForeground,
                size: 22,
                semanticLabel: '发布',
              ),
            ),
          ),
        ),
        FBottomNavigationBarItem(
          icon: _UnreadNavigationIcon(
            icon: FLucideIcons.messageSquare,
            count: messageUnread,
          ),
          label: const Text('消息'),
        ),
        const FBottomNavigationBarItem(
          icon: Icon(FLucideIcons.userRound),
          label: Text('我的'),
        ),
      ],
    );
  }
}

class _UnreadNavigationIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool dot;

  const _UnreadNavigationIcon({
    required this.icon,
    required this.count,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final iconWidget = Icon(icon);
    if (count <= 0) {
      return iconWidget;
    }

    if (dot) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -2,
            top: -2,
            child: SizedBox.square(
              dimension: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colors.destructive,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      );
    }
    final label = count > 99 ? '99+' : '$count';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          right: -8,
          top: -6,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.destructive,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(
                    label,
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.destructiveForeground,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Auth pages sit outside [MainShell]; paint the theme background across the
/// whole viewport so wide dark layouts do not show the default white canvas
/// beside the 440px column.
class _AuthFrame extends StatelessWidget {
  final Widget child;

  const _AuthFrame({required this.child});

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('auth-frame'),
    color: context.theme.colors.background,
    child: ContentConstraint(maxWidth: 440, child: child),
  );
}
