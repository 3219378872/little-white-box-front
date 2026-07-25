import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_notifier.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/feed/presentation/feed_page.dart';
import '../../features/post/presentation/post_detail_page.dart';
import '../../features/post/presentation/post_editor_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../widgets/content_constraint.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

const _publicRoutes = ['/feed', '/auth/login', '/auth/register'];

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
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/feed',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FeedPage()),
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
  const MainShell({super.key, required this.child});

  void _onDestinationSelected(BuildContext context, WidgetRef ref, int index) {
    final auth = ref.read(authNotifierProvider);
    final isLoggedIn = auth.isAuthenticated;

    if (index == 1) {
      if (!isLoggedIn) {
        context.push('/auth/login');
        return;
      }
      context.go('/post/new');
      return;
    }

    if (index == 2) {
      if (!isLoggedIn) {
        context.push('/auth/login');
        return;
      }
      context.go('/profile');
      return;
    }

    context.go('/feed');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _calculateIndex(location);
    final width = MediaQuery.sizeOf(context).width;
    final breakpoints = context.theme.breakpoints;
    final isDesktop = width >= breakpoints.lg;
    final horizontalPadding = width >= breakpoints.md ? 24.0 : 0.0;
    final showBottomNavigation = !isDesktop && _isPrimaryRoute(location);

    return FScaffold(
      childPad: false,
      sidebar: isDesktop
          ? _DesktopSidebar(
              selectedIndex: index,
              onDestinationSelected: (selected) =>
                  _onDestinationSelected(context, ref, selected),
            )
          : null,
      footer: showBottomNavigation
          ? _MobileBottomNavigation(
              index: index,
              onChange: (selected) =>
                  _onDestinationSelected(context, ref, selected),
            )
          : null,
      child: ContentConstraint(
        maxWidth: _contentMaxWidth(location),
        horizontalPadding: horizontalPadding,
        child: child,
      ),
    );
  }

  int _calculateIndex(String location) {
    if (location.startsWith('/profile')) return 2;
    if (location.startsWith('/post/new') || location.startsWith('/post/edit')) {
      return 1;
    }
    return 0;
  }

  bool _isPrimaryRoute(String location) {
    return location == '/feed' ||
        location == '/post/new' ||
        location == '/profile';
  }

  double _contentMaxWidth(String location) {
    if (location.startsWith('/post/new') || location.startsWith('/post/edit')) {
      return 760;
    }
    if (location.startsWith('/post/')) return 720;
    if (location == '/profile/edit') return 560;
    return 680;
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _DesktopSidebar({
    required this.selectedIndex,
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
          selected: selectedIndex == 0,
          onPress: () => onDestinationSelected(0),
        ),
        FSidebarItem(
          icon: const Icon(FLucideIcons.circlePlus),
          label: const Text('发布'),
          selected: selectedIndex == 1,
          onPress: () => onDestinationSelected(1),
        ),
        FSidebarItem(
          icon: const Icon(FLucideIcons.userRound),
          label: const Text('我的'),
          selected: selectedIndex == 2,
          onPress: () => onDestinationSelected(2),
        ),
      ],
    );
  }
}

class _MobileBottomNavigation extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChange;

  const _MobileBottomNavigation({required this.index, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return FBottomNavigationBar(
      index: index,
      onChange: onChange,
      children: const [
        FBottomNavigationBarItem(
          icon: Icon(FLucideIcons.house),
          label: Text('首页'),
        ),
        FBottomNavigationBarItem(
          icon: Icon(FLucideIcons.circlePlus),
          label: Text('发布'),
        ),
        FBottomNavigationBarItem(
          icon: Icon(FLucideIcons.userRound),
          label: Text('我的'),
        ),
      ],
    );
  }
}
