import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/application/assistant_thread_notifier.dart';
import '../../features/auth/application/auth_notifier.dart';
import '../../features/message/application/message_providers.dart';
import '../../features/review/presentation/reviewer_access_refresh_binding.dart';
import '../theme/app_theme.dart';
import '../widgets/content_constraint.dart';
import '../router/app_routes.dart';

// 主导航的五个入口；桌面侧栏与移动底栏共用，顺序即移动底栏顺序。
enum _AppDestination { feed, search, create, messages, profile }

const _mobileDestinations = [
  _AppDestination.feed,
  _AppDestination.search,
  _AppDestination.create,
  _AppDestination.messages,
  _AppDestination.profile,
];

/// 登录后页面共用的应用壳：桌面端左侧栏、移动端一级页底栏，按路由约束内容宽度，
/// 并挂载 Agent 线程轮询与审核权限刷新这两个随壳存活的后台绑定。
class MainShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const MainShell({super.key, required this.child, required this.location});

  // 未登录点受保护入口时压入登录页（返回后仍停在原处），否则切换到对应一级路由。
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
      context.push(AppRoutes.login);
      return;
    }
    context.go(switch (destination) {
      _AppDestination.feed => AppRoutes.feed,
      _AppDestination.search => AppRoutes.search,
      _AppDestination.create => AppRoutes.postNew,
      _AppDestination.messages => AppRoutes.messages,
      _AppDestination.profile => AppRoutes.profile,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = _destinationFor(location);
    // 导航角标合计私信与 Agent 线程的未读数。
    final messageUnread = ref.watch(
      unreadSummaryProvider.select((state) => state.summary.messageUnread),
    );
    final assistantUnread = ref.watch(
      assistantThreadProvider.select((state) => state.thread.unreadCount),
    );
    final navUnread = messageUnread + assistantUnread;
    // 断点：lg 及以上用侧栏（xl 以下折叠），md 及以上给内容加水平留白。
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
          // 无界面的后台绑定，随壳挂载、随壳销毁。
          const AssistantThreadPollBinding(),
          const ReviewerAccessRefreshBinding(),
        ],
      ),
    );
  }

  // 子路由归属的高亮入口：广告与审核挂在“我的”下，发帖/编辑挂在“发布”下。
  _AppDestination _destinationFor(String location) {
    if (location.startsWith(AppRoutes.search)) return _AppDestination.search;
    if (location.startsWith(AppRoutes.messages)) {
      return _AppDestination.messages;
    }
    if (location.startsWith(AppRoutes.profile) ||
        location.startsWith(AppRoutes.ads) ||
        location.startsWith(AppRoutes.review)) {
      return _AppDestination.profile;
    }
    if (location.startsWith(AppRoutes.postNew) ||
        location.startsWith('/post/edit')) {
      return _AppDestination.create;
    }
    return _AppDestination.feed;
  }

  // 只有一级页显示移动底栏，详情等子页面全屏。
  bool _isPrimaryRoute(String location) {
    return location == AppRoutes.feed ||
        location == AppRoutes.search ||
        location == AppRoutes.messages ||
        location == AppRoutes.profile;
  }

  // 按路由给内容列定宽：编辑器、详情、消息双栏、资料编辑与首页各有固定宽度。
  double _contentMaxWidth(String location, double width) {
    if (location.startsWith(AppRoutes.postNew) ||
        location.startsWith('/post/edit')) {
      return 760;
    }
    if (location.startsWith('/post/')) return 720;
    if (location == AppRoutes.messages || location.startsWith('/messages/')) {
      return width >= 1024 ? 1100 : 720;
    }
    if (location == AppRoutes.profileEdit) return 560;
    if (location == AppRoutes.feed) {
      // Wide desktops add the side rail next to the fixed-width feed column.
      return width >= 1280
          ? AppTheme.feedColumnWidth + AppTheme.space6 + AppTheme.sideRailWidth
          : AppTheme.feedColumnWidth;
    }
    return 680;
  }
}

// 桌面侧栏：宽屏展开为图标+文字，窄于 xl 断点折叠为图标并用 tooltip 提示名称。
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

    // 单个导航项：折叠时只显示图标（未读用红点）并以 tooltip 提示名称，
    // 展开时文字后跟未读胶囊；语义合并为一个节点供读屏使用。
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
      // 头部品牌标识，折叠时只保留图标。
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

// 展开侧栏中“消息”项尾部的未读数胶囊，超过 99 显示 99+。
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

// 移动端一级页底栏，“发布”入口用主色按钮突出。
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

// 导航图标上的未读角标；[dot] 为 true 时只画红点（折叠侧栏用），否则显示数字。
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

    // 折叠侧栏空间有限，只画红点。
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
