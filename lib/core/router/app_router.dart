import 'package:flutter/material.dart';
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
  if (_publicRoutes.contains(location)) return true;
  if (location.startsWith('/post/') && !location.contains('/edit/')) return true;
  if (location.startsWith('/user/')) return true;
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
            const ContentConstraint(child: LoginPage()),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) =>
            const ContentConstraint(child: RegisterPage()),
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
        ],
      ),
      GoRoute(
        path: '/post/edit/:postId',
        builder: (context, state) => PostEditorPage(
          postId: int.tryParse(state.pathParameters['postId'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/post/:postId',
        builder: (context, state) => ContentConstraint(
          child: PostDetailPage(
            postId: int.parse(state.pathParameters['postId']!),
          ),
        ),
      ),
      GoRoute(
        path: '/user/:userId',
        builder: (context, state) => ContentConstraint(
          child: ProfilePage(
            userId: int.parse(state.pathParameters['userId']!),
          ),
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) =>
            const ContentConstraint(child: EditProfilePage()),
      ),
    ],
  );
});

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    final auth = ref.read(authNotifierProvider);
    final isLoggedIn = auth.isAuthenticated;

    if (index == 1) {
      // 发布 Tab
      if (!isLoggedIn) {
        context.push('/auth/login');
        return;
      }
      context.go('/post/new');
      setState(() => _selectedIndex = index);
      return;
    }

    if (index == 2) {
      // 我的 Tab
      if (!isLoggedIn) {
        context.push('/auth/login');
        return;
      }
      context.go('/profile');
      setState(() => _selectedIndex = index);
      return;
    }

    // 首页
    context.go('/feed');
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _calculateIndex(location);

    return FScaffold(
      childPad: false,
      footer: FBottomNavigationBar(
        index: index,
        onChange: _onDestinationSelected,
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
      ),
      child: ContentConstraint(child: widget.child),
    );
  }

  int _calculateIndex(String location) {
    if (location.startsWith('/profile')) return 2;
    if (location.startsWith('/post/new')) return 1;
    if (location.startsWith('/feed')) return 0;
    return _selectedIndex;
  }
}
