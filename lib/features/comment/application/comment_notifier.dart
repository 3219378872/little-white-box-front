import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/collections/unique_by.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/comment_repository.dart';
import 'comment_dependencies.dart';

/// 帖子详情页评论区状态：顶级评论分页、楼中楼按需展开、回复目标。
///
/// 后端契约：列表只含顶级评论，子评论经内嵌预览 + 楼中楼接口按需加载。
class CommentState {
  final List<CommentItem> comments;

  /// 首屏（含重试、切排序）加载中。
  final bool isLoading;

  /// 触底翻页加载中。
  final bool isLoadingMore;

  /// 最近一次列表加载失败的提示；为空表示没有未处理的失败。
  final String? error;

  /// 失败发生在首屏：重试应从第 1 页重建，而不是续拉下一页。
  final bool initialLoadFailed;
  final bool hasMore;
  final int sortBy;

  // 楼中楼展开状态：key 为顶级评论 id 字符串
  final Set<String> expandedReplies;
  final Map<String, List<CommentItem>> threadReplies;
  final Map<String, int> threadPage;
  final Set<String> loadingReplies;

  // 回复目标（输入框 @ 展示与创建参数）
  final String? replyToUser;
  final Object replyParentId;
  final Object replyUserId;

  const CommentState({
    this.comments = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.initialLoadFailed = false,
    this.hasMore = true,
    this.sortBy = 1,
    this.expandedReplies = const {},
    this.threadReplies = const {},
    this.threadPage = const {},
    this.loadingReplies = const {},
    this.replyToUser,
    this.replyParentId = 0,
    this.replyUserId = 0,
  });

  CommentState copyWith({
    List<CommentItem>? comments,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    bool? initialLoadFailed,
    bool? hasMore,
    int? sortBy,
    Set<String>? expandedReplies,
    Map<String, List<CommentItem>>? threadReplies,
    Map<String, int>? threadPage,
    Set<String>? loadingReplies,
    String? replyToUser,
    bool clearReplyToUser = false,
    Object? replyParentId,
    Object? replyUserId,
  }) {
    return CommentState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      initialLoadFailed: initialLoadFailed ?? this.initialLoadFailed,
      hasMore: hasMore ?? this.hasMore,
      sortBy: sortBy ?? this.sortBy,
      expandedReplies: expandedReplies ?? this.expandedReplies,
      threadReplies: threadReplies ?? this.threadReplies,
      threadPage: threadPage ?? this.threadPage,
      loadingReplies: loadingReplies ?? this.loadingReplies,
      replyToUser: clearReplyToUser ? null : (replyToUser ?? this.replyToUser),
      replyParentId: replyParentId ?? this.replyParentId,
      replyUserId: replyUserId ?? this.replyUserId,
    );
  }
}

class CommentNotifier extends StateNotifier<CommentState> {
  final CommentRepository _repository;
  final String postId;
  static const _pageSize = 20;
  static const _replyPageSize = 10;

  int _page = 0;
  int _generation = 0;
  final Map<String, int> _replyGenerations = {};
  String? _submitIdempotencyKey;
  String? _submitCommandFingerprint;

  CommentNotifier({
    required CommentRepository repository,
    required this.postId,
    bool loadImmediately = true,
  }) : _repository = repository,
       super(const CommentState()) {
    if (loadImmediately) unawaited(loadInitial());
  }

  /// 首屏/重试/切排序：从第 1 页重建列表。
  Future<void> loadInitial() async {
    final generation = ++_generation;
    // 新一代请求使进行中的翻页失效，一并释放它的加载标记。
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
      initialLoadFailed: false,
      loadingReplies: const {},
    );
    try {
      final resp = await _repository.fetchComments(
        postId: postId,
        page: 1,
        pageSize: _pageSize,
        sortBy: state.sortBy,
      );
      if (!mounted || generation != _generation) return;
      _page = 1;
      state = state.copyWith(
        comments: resp.list,
        hasMore: resp.list.length >= _pageSize,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      // 失败不得伪装成空评论区（FX-001）；给出可重试的错误态。
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        error: friendlyErrorMessage(error),
        initialLoadFailed: true,
      );
    }
  }

  /// 触底加载下一页。
  Future<void> loadMore() async {
    // 有未处理的失败时不随滚动自动重发，等用户点重试。
    if (!state.hasMore ||
        state.isLoading ||
        state.isLoadingMore ||
        state.error != null) {
      return;
    }
    final page = _page + 1;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final resp = await _repository.fetchComments(
        postId: postId,
        page: page,
        pageSize: _pageSize,
        sortBy: state.sortBy,
      );
      if (!mounted || generation != _generation) return;
      _page = page;
      state = state.copyWith(
        comments: [...state.comments, ...resp.list],
        hasMore: resp.list.length >= _pageSize,
        isLoadingMore: false,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> retry() async {
    if (state.comments.isNotEmpty && !state.initialLoadFailed) {
      if (state.error != null) {
        state = state.copyWith(clearError: true);
      }
      await loadMore();
      return;
    }
    await loadInitial();
  }

  Future<void> selectSort(int value) async {
    if (value == state.sortBy) return;
    state = state.copyWith(
      sortBy: value,
      comments: [],
      hasMore: true,
      clearError: true,
    );
    await loadInitial();
  }

  /// 展开/收起楼中楼。首次展开用内嵌预览即时渲染，同时拉取第一页全量数据。
  /// 拉取失败时回滚展开态并抛出，由 UI 提示。
  Future<void> toggleReplies(CommentItem comment) async {
    final id = jsonInt64Id(comment.id);
    final expanded = {...state.expandedReplies};
    if (!expanded.add(id)) {
      expanded.remove(id);
      _replyGenerations[id] = (_replyGenerations[id] ?? 0) + 1;
      state = state.copyWith(
        expandedReplies: expanded,
        loadingReplies: {...state.loadingReplies}..remove(id),
      );
      return;
    }
    final threadReplies = Map<String, List<CommentItem>>.of(state.threadReplies)
      ..remove(id);
    final threadPage = Map<String, int>.of(state.threadPage)..remove(id);
    state = state.copyWith(
      expandedReplies: expanded,
      threadReplies: threadReplies,
      threadPage: threadPage,
      loadingReplies: {...state.loadingReplies, id},
    );
    await _fetchReplyThread(comment, page: 1, append: false);
  }

  Future<void> loadMoreReplies(CommentItem comment) async {
    final id = jsonInt64Id(comment.id);
    if (!state.expandedReplies.contains(id) ||
        state.loadingReplies.contains(id)) {
      return;
    }
    state = state.copyWith(loadingReplies: {...state.loadingReplies, id});
    final loadedPage = state.threadPage[id] ?? 0;
    await _fetchReplyThread(
      comment,
      page: loadedPage + 1,
      append: loadedPage > 0,
    );
  }

  Future<void> _fetchReplyThread(
    CommentItem comment, {
    required int page,
    required bool append,
  }) async {
    final id = jsonInt64Id(comment.id);
    final generation = _generation;
    final replyGeneration = (_replyGenerations[id] ?? 0) + 1;
    _replyGenerations[id] = replyGeneration;
    bool isCurrent() =>
        mounted &&
        generation == _generation &&
        replyGeneration == _replyGenerations[id] &&
        state.expandedReplies.contains(id);
    try {
      final resp = await _repository.fetchReplies(
        commentId: comment.id,
        page: page,
        pageSize: _replyPageSize,
      );
      if (!isCurrent()) return;
      final existing = append
          ? (state.threadReplies[id] ?? const <CommentItem>[])
          : const <CommentItem>[];
      final merged = [...existing, ...resp.list];
      // 去重（幂等保护：同页重复返回时以先到者为准）
      final deduped = uniqueBy(merged, (r) => jsonInt64Id(r.id));
      final threadReplies = Map<String, List<CommentItem>>.of(
        state.threadReplies,
      )..[id] = deduped;
      final threadPage = Map<String, int>.of(state.threadPage)..[id] = page;
      final loadingReplies = Set<String>.of(state.loadingReplies)..remove(id);
      state = state.copyWith(
        threadReplies: threadReplies,
        threadPage: threadPage,
        loadingReplies: loadingReplies,
      );
    } catch (_) {
      // 与既有行为一致：失败仅结束 loading 并提示，保持展开态展示内嵌预览。
      if (!isCurrent()) return;
      final loadingReplies = Set<String>.of(state.loadingReplies)..remove(id);
      state = state.copyWith(loadingReplies: loadingReplies);
      rethrow;
    }
  }

  void setReplyTarget({
    required String? userName,
    required Object parentId,
    required Object userId,
  }) {
    state = state.copyWith(
      replyToUser: userName,
      replyParentId: parentId,
      replyUserId: userId,
    );
  }

  /// 创建评论；成功后清空回复目标并从第 1 页刷新。
  /// 失败时抛出由 UI 提示，本地回复目标保持不变。
  Future<void> submit(String content) async {
    final normalized = content.trim();
    final commandFingerprint = [
      postId,
      jsonInt64Id(state.replyParentId),
      jsonInt64Id(state.replyUserId),
      normalized,
    ].join('\u0000');
    if (_submitCommandFingerprint != commandFingerprint ||
        _submitIdempotencyKey == null) {
      _submitIdempotencyKey = newIdempotencyKey();
      _submitCommandFingerprint = commandFingerprint;
    }
    await _repository.createNewComment(
      CreateCommentReq(
        postId: postId,
        parentId: state.replyParentId,
        replyUserId: state.replyUserId,
        content: normalized,
        idempotencyKey: _submitIdempotencyKey!,
      ),
    );
    _submitIdempotencyKey = null;
    _submitCommandFingerprint = null;
    if (!mounted) return;
    // 清空缓存时同时收起楼中楼，下一次展开重新读取第一页。
    state = state.copyWith(
      clearReplyToUser: true,
      replyParentId: 0,
      replyUserId: 0,
      expandedReplies: const {},
      threadReplies: const {},
      threadPage: const {},
      loadingReplies: const {},
    );
    await loadInitial();
  }
}

final commentNotifierProvider = StateNotifierProvider.autoDispose
    .family<CommentNotifier, CommentState, String>((ref, postId) {
      ref.watch(authSessionIdentityProvider);
      return CommentNotifier(
        repository: ref.read(commentRepositoryProvider),
        postId: postId,
      );
    });
