import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/router/app_route_observer.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/forui_pull_to_refresh.dart';
import '../../../../core/widgets/load_more_footer.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../application/user_posts_notifier.dart';

/// 个人主页里的帖子或收藏列表：游标分页、下拉刷新与触底加载更多。
///
/// [active] 标记当前可见的标签；只有可见列表会在切入或从子页返回时刷新。
class UserPostList extends ConsumerStatefulWidget {
  final Object userId;
  final UserPostsListType type;

  /// 是否为当前选中的标签页。
  final bool active;

  const UserPostList({
    super.key,
    required this.userId,
    required this.type,
    this.active = true,
  });

  @override
  ConsumerState<UserPostList> createState() => _UserPostListState();
}

// 订阅路由事件：从子页返回时刷新，让列表反映在子页中发生的改动。
class _UserPostListState extends ConsumerState<UserPostList> with RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;

  UserPostsKey get _key =>
      UserPostsKey(userId: widget.userId, type: widget.type);

  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(appRouteObserverProvider);
    // 首次显示即为当前标签时，在首帧后尝试刷新（首屏仍在加载则跳过）。
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reloadIfActive();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant UserPostList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切到本标签时刷新。
    if (widget.active && !oldWidget.active) {
      _reloadIfActive();
    }
  }

  // 从压在上面的子页返回：刷新当前标签。
  @override
  void didPopNext() {
    _reloadIfActive();
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  // 仅当前标签且没有进行中的加载时刷新，避免与首屏/续翻请求叠加。
  void _reloadIfActive() {
    if (!widget.active) return;
    final state = ref.read(userPostsProvider(_key));
    if (state.isLoading || state.isLoadingMore || state.isRefreshing) return;
    ref.read(userPostsProvider(_key).notifier).refresh();
  }

  // 只响应本列表自身的纵向滚动，距底部 300 像素内续翻。
  bool _handleScrollNotification(ScrollNotification notification) {
    // 加载更多失败后停在原地等待用户点重试，不随滚动反复重发同一游标。
    if (ref.read(userPostsProvider(_key)).error != null) return false;
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter <= 300) {
      ref.read(userPostsProvider(_key).notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userPostsProvider(_key));
    final notifier = ref.read(userPostsProvider(_key).notifier);
    final scrollView = NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: CustomScrollView(
        key: PageStorageKey('profile-${widget.userId}-${widget.type.name}'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 与页面头部的 SliverOverlapAbsorber 配对，避免内容被吸顶标签栏遮住。
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          // 空列表的加载、失败与空态都占满剩余高度。
          if ((state.isLoading || state.isLoadingMore) && state.items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingView(),
            )
          else if (state.error != null && state.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: friendlyErrorMessage(state.error!),
                onRetry: () => notifier.loadInitial(),
              ),
            )
          else if (state.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    widget.type == UserPostsListType.posts
                        ? '还没有发布任何帖子'
                        : '还没有收藏任何帖子',
                    style: context.theme.typography.body.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            )
          else
            // 有内容：帖子卡片列表，尾部按需追加状态行。
            SliverList.builder(
              itemCount:
                  state.items.length +
                  ((state.isLoadingMore ||
                          state.error != null ||
                          !state.hasMore)
                      ? 1
                      : 0),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  // 尾部：续翻中、续翻失败重试或已到底。
                  final error = state.error;
                  return LoadMoreFooter(
                    isLoading: state.isLoadingMore,
                    error: error == null ? null : friendlyErrorMessage(error),
                    onRetry: notifier.loadMore,
                    showEnd: true,
                  );
                }
                return PostCard(post: state.items[index]);
              },
            ),
        ],
      ),
    );

    // 空列表加载中或失败时不包下拉刷新，交由加载态与重试按钮处理。
    if ((state.isLoading || state.isLoadingMore || state.error != null) &&
        state.items.isEmpty) {
      return scrollView;
    }

    return ForuiPullToRefresh(onRefresh: notifier.refresh, child: scrollView);
  }
}
