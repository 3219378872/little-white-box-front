import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_notifier.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/assistant/presentation/assistant_page.dart';
import '../../features/feed/presentation/feed_page.dart';
import '../../features/message/application/message_notifiers.dart';
import '../../features/message/presentation/conversations_page.dart';
import '../../features/message/presentation/message_thread_page.dart';
import '../../features/post/presentation/post_detail_page.dart';
import '../../features/post/presentation/post_editor_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../widgets/content_constraint.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

const _publicRoutes = ['/feed', '/search', '/auth/login', '/auth/register'];

enum _AppDestination { feed, search, create, messages, assistant, profile }

const _mobileDestinations = [
  _AppDestination.feed,
  _AppDestination.search,
  _AppDestination.create,
  _AppDestination.messages,
  _AppDestination.profile,
];

bool _isPublicRoute(String location) {
  if (_publicRoutes.contains(location)) {
    return true;
  }
  if (location.startsWith('/post/') && !location.contains('/edit/')) {
    return true;
  }
  if (location.startsWith('/user/')) {
    return true;
  }
  return false;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/feed',
    refreshListenable: ref.read(authListenableProvider),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      if (authState.isLoading) return null;

      final isLoggedIn = authState.isAuthenticated;
      final location = state.matchedLocation;
      final isAuthRoute = location.startsWith('/auth');

      if (!isLoggedIn && !_isPublicRoute(location)) {
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
        builder: (context, state) =>
            const ContentConstraint(maxWidth: 440, child: LoginPage()),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) =>
            const ContentConstraint(maxWidth: 440, child: RegisterPage()),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) =>
            MainShell(location: state.matchedLocation, child: child),
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
                const NoTransitionPage(child: ConversationsPage()),
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
            builder: (context, state) => MessageThreadPage(
              conversationId: int.parse(
                state.pathParameters['conversationId']!,
              ),
              targetUserId: int.parse(
                state.uri.queryParameters['targetUserId']!,
              ),
              targetUserName: state.uri.queryParameters['targetUserName'] ?? '',
            ),
          ),
          GoRoute(
            path: '/assistant',
            builder: (context, state) => const AssistantPage(),
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
            builder: (context, state) => PostEditorPage(
              postId: int.tryParse(state.pathParameters['postId'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/post/:postId',
            builder: (context, state) => PostDetailPage(
              postId: int.parse(state.pathParameters['postId']!),
            ),
          ),
          GoRoute(
            path: '/user/:userId',
            builder: (context, state) =>
                ProfilePage(userId: int.parse(state.pathParameters['userId']!)),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) => const EditProfilePage(),
          ),
        ],
      ),
    ],
  );
});

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
      _AppDestination.assistant => '/assistant',
      _AppDestination.profile => '/profile',
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = _destinationFor(location);
    final messageUnread = ref.watch(
      unreadSummaryProvider.select((state) => state.summary.messageUnread),
    );
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
              messageUnread: messageUnread,
              onDestinationSelected: (selected) =>
                  _onDestinationSelected(context, ref, selected),
            )
          : null,
      footer: showBottomNavigation
          ? _MobileBottomNavigation(
              destination: destination,
              messageUnread: messageUnread,
              onChange: (selected) => _onDestinationSelected(
                context,
                ref,
                _mobileDestinations[selected],
              ),
            )
          : null,
      child: ContentConstraint(
        maxWidth: _contentMaxWidth(location),
        horizontalPadding: horizontalPadding,
        child: child,
      ),
    );
  }

  _AppDestination _destinationFor(String location) {
    if (location.startsWith('/search')) return _AppDestination.search;
    if (location.startsWith('/messages')) return _AppDestination.messages;
    if (location.startsWith('/assistant')) return _AppDestination.assistant;
    if (location.startsWith('/profile')) return _AppDestination.profile;
    if (location.startsWith('/post/new') || location.startsWith('/post/edit')) {
      return _AppDestination.create;
    }
    return _AppDestination.feed;
  }

  bool _isPrimaryRoute(String location) {
    return location == '/feed' ||
        location == '/search' ||
        location == '/post/new' ||
        location == '/messages' ||
        location == '/profile';
  }

  double _contentMaxWidth(String location) {
    if (location.startsWith('/post/new') || location.startsWith('/post/edit')) {
      return 760;
    }
    if (location.startsWith('/post/')) return 720;
    if (location.startsWith('/messages/')) return 720;
    if (location == '/assistant') return 760;
    if (location == '/profile/edit') return 560;
    return 680;
  }
}

class _DesktopSidebar extends StatelessWidget {
  final _AppDestination selectedDestination;
  final int messageUnread;
  final ValueChanged<_AppDestination> onDestinationSelected;

  const _DesktopSidebar({
    required this.selectedDestination,
    required this.messageUnread,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FSidebar(
      style: const FSidebarStyleDelta.delta(
        constraints: BoxConstraints.tightFor(width: 240),
      ),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Icon(FLucideIcons.box, color: theme.colors.primary),
            const SizedBox(width: 10),
            Text(
              '小白盒',
              style: theme.typography.display.sm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      children: [
        FSidebarItem(
          icon: const Icon(FLucideIcons.house),
          label: const Text('首页'),
          selected: selectedDestination == _AppDestination.feed,
          onPress: () => onDestinationSelected(_AppDestination.feed),
        ),
        FSidebarItem(
          icon: const Icon(FLucideIcons.search),
          label: const Text('搜索'),
          selected: selectedDestination == _AppDestination.search,
          onPress: () => onDestinationSelected(_AppDestination.search),
        ),
        FSidebarItem(
          icon: _UnreadNavigationIcon(
            icon: FLucideIcons.messagesSquare,
            count: messageUnread,
          ),
          label: const Text('消息'),
          selected: selectedDestination == _AppDestination.messages,
          onPress: () => onDestinationSelected(_AppDestination.messages),
        ),
        FSidebarItem(
          icon: const Icon(FLucideIcons.sparkles),
          label: const Text('Assistant'),
          selected: selectedDestination == _AppDestination.assistant,
          onPress: () => onDestinationSelected(_AppDestination.assistant),
        ),
        FSidebarItem(
          icon: const Icon(FLucideIcons.circlePlus),
          label: const Text('发布'),
          selected: selectedDestination == _AppDestination.create,
          onPress: () => onDestinationSelected(_AppDestination.create),
        ),
        FSidebarItem(
          icon: const Icon(FLucideIcons.userRound),
          label: const Text('我的'),
          selected: selectedDestination == _AppDestination.profile,
          onPress: () => onDestinationSelected(_AppDestination.profile),
        ),
      ],
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
        const FBottomNavigationBarItem(
          icon: Icon(FLucideIcons.circlePlus),
          label: Text('发布'),
        ),
        FBottomNavigationBarItem(
          icon: _UnreadNavigationIcon(
            icon: FLucideIcons.messagesSquare,
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

  const _UnreadNavigationIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final label = count > 99 ? '99+' : '$count';
    return SizedBox.square(
      dimension: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: Icon(icon)),
          if (count > 0)
            Positioned(
              right: -9,
              top: -7,
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
      ),
    );
  }
}
