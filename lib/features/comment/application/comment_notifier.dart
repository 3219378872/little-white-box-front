import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/idempotency.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/data/gateway.dart';
import '../data/comment_repository.dart';

/// 帖子详情页评论区状态：顶级评论分页、楼中楼按需展开、回复目标。
///
/// 后端契约：列表只含顶级评论，子评论经内嵌预览 + 楼中楼接口按需加载。
class CommentState {
  final List<CommentItem> comments;
  final bool isLoading;
  final bool hasError;
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
    this.hasError = false,
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
    bool? hasError,
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
      hasError: hasError ?? this.hasError,
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
    _page = 1;
    state = state.copyWith(isLoading: true, hasError: false);
    try {
      final resp = await _repository.fetchComments(
        postId: postId,
        page: _page,
        pageSize: _pageSize,
        sortBy: state.sortBy,
      );
      if (!mounted) return;
      state = state.copyWith(
        comments: resp.list,
        hasMore: resp.list.length >= _pageSize,
        isLoading: false,
        hasError: false,
      );
    } catch (_) {
      // 失败不得伪装成空评论区（FX-001）；给出可重试的错误态。
      if (!mounted) return;
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }

  /// 触底加载下一页。
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.hasError) return;
    final page = _page + 1;
    state = state.copyWith(isLoading: true);
    try {
      final resp = await _repository.fetchComments(
        postId: postId,
        page: page,
        pageSize: _pageSize,
        sortBy: state.sortBy,
      );
      if (!mounted) return;
      _page = page;
      state = state.copyWith(
        comments: [...state.comments, ...resp.list],
        hasMore: resp.list.length >= _pageSize,
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }

  Future<void> retry() async {
    if (state.comments.isNotEmpty) {
      if (state.hasError) {
        state = state.copyWith(hasError: false);
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
      hasError: false,
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
      state = state.copyWith(expandedReplies: expanded);
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
    if (state.loadingReplies.contains(id)) return;
    state = state.copyWith(loadingReplies: {...state.loadingReplies, id});
    await _fetchReplyThread(
      comment,
      page: (state.threadPage[id] ?? 1) + 1,
      append: true,
    );
  }

  Future<void> _fetchReplyThread(
    CommentItem comment, {
    required int page,
    required bool append,
  }) async {
    final id = jsonInt64Id(comment.id);
    try {
      final resp = await _repository.fetchReplies(
        commentId: comment.id,
        page: page,
        pageSize: _replyPageSize,
      );
      if (!mounted) return;
      final existing = append
          ? (state.threadReplies[id] ?? const <CommentItem>[])
          : const <CommentItem>[];
      final merged = [...existing, ...resp.list];
      // 去重（幂等保护：同页重复返回时以先到者为准）
      final seen = <String>{};
      final deduped = merged.where((r) => seen.add(jsonInt64Id(r.id))).toList();
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
      if (!mounted) return;
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
    // 回复成功后重置该父评论的楼中楼缓存，刷新后重新拉取
    final hadExpanded = state.expandedReplies.isNotEmpty;
    state = state.copyWith(
      clearReplyToUser: true,
      replyParentId: 0,
      replyUserId: 0,
      threadReplies: hadExpanded ? const {} : null,
      threadPage: hadExpanded ? const {} : null,
    );
    await loadInitial();
  }
}

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository();
});

final commentNotifierProvider = StateNotifierProvider.autoDispose
    .family<CommentNotifier, CommentState, String>((ref, postId) {
      return CommentNotifier(
        repository: ref.read(commentRepositoryProvider),
        postId: postId,
      );
    });
