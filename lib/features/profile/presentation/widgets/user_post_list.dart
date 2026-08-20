import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import '../../../../core/router/app_route_observer.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/forui_pull_to_refresh.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../application/user_posts_notifier.dart';

class UserPostList extends ConsumerStatefulWidget {
  final num userId;
  final UserPostsListType type;
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

class _UserPostListState extends ConsumerState<UserPostList> with RouteAware {
  late final RouteObserver<ModalRoute<void>> _routeObserver;

  UserPostsKey get _key =>
      UserPostsKey(userId: widget.userId, type: widget.type);

  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(appRouteObserverProvider);
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
    if (widget.active && !oldWidget.active) {
      _reloadIfActive();
    }
  }

  @override
  void didPopNext() {
    _reloadIfActive();
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _reloadIfActive() {
    if (!widget.active) return;
    final state = ref.read(userPostsProvider(_key));
    if (state.isLoading || state.isRefreshing) return;
    ref.read(userPostsProvider(_key).notifier).refresh();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter <= 300) {
      ref.read(userPostsProvider(_key).notifier).loadNextPage();
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
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          if (state.isLoading && state.items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: FCircularProgress()),
            )
          else if (state.error != null && state.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: state.error.toString(),
                onRetry: () => notifier.loadFirstPage(),
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
            SliverList.builder(
              itemCount:
                  state.items.length +
                  ((state.isLoading || !state.hasMore) ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  if (state.isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: FCircularProgress()),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        '— 没有更多了 —',
                        style: TextStyle(
                          color: context.theme.colors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }
                return PostCard(post: state.items[index]);
              },
            ),
        ],
      ),
    );

    if ((state.isLoading || state.error != null) && state.items.isEmpty) {
      return scrollView;
    }

    return ForuiPullToRefresh(onRefresh: notifier.refresh, child: scrollView);
  }
}
