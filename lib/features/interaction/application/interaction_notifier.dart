import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sdk/data/gateway.dart';
import '../data/interaction_repository.dart';

/// 单帖点赞/收藏的乐观更新状态：覆盖值 + 计数偏移量。
/// 服务端失败时回滚并抛出，由 UI 层提示。
class InteractionState {
  final bool? optimisticIsLiked;
  final bool? optimisticIsFavorited;
  final int likeCountDelta;
  final int favoriteCountDelta;

  const InteractionState({
    this.optimisticIsLiked,
    this.optimisticIsFavorited,
    this.likeCountDelta = 0,
    this.favoriteCountDelta = 0,
  });

  InteractionState copyWith({
    bool? optimisticIsLiked,
    bool clearOptimisticIsLiked = false,
    bool? optimisticIsFavorited,
    bool clearOptimisticIsFavorited = false,
    int? likeCountDelta,
    int? favoriteCountDelta,
  }) {
    return InteractionState(
      optimisticIsLiked:
          clearOptimisticIsLiked ? null : (optimisticIsLiked ?? this.optimisticIsLiked),
      optimisticIsFavorited: clearOptimisticIsFavorited
          ? null
          : (optimisticIsFavorited ?? this.optimisticIsFavorited),
      likeCountDelta: likeCountDelta ?? this.likeCountDelta,
      favoriteCountDelta: favoriteCountDelta ?? this.favoriteCountDelta,
    );
  }
}

class InteractionNotifier extends StateNotifier<InteractionState> {
  final InteractionRepository _repository;

  InteractionNotifier({required InteractionRepository repository})
      : _repository = repository,
        super(const InteractionState());

  Future<void> toggleLike(GetPostResp post) async {
    final currentlyLiked = state.optimisticIsLiked ?? post.isLiked;
    state = state.copyWith(
      optimisticIsLiked: !currentlyLiked,
      likeCountDelta: state.likeCountDelta + (currentlyLiked ? -1 : 1),
    );
    try {
      if (currentlyLiked) {
        await _repository.unlikeTarget(post.id, 1);
      } else {
        await _repository.likeTarget(post.id, 1);
      }
    } catch (_) {
      state = state.copyWith(
        optimisticIsLiked: currentlyLiked,
        likeCountDelta: state.likeCountDelta + (currentlyLiked ? 1 : -1),
      );
      rethrow;
    }
  }

  Future<void> toggleFavorite(GetPostResp post) async {
    final currentlyFav = state.optimisticIsFavorited ?? post.isFavorited;
    state = state.copyWith(
      optimisticIsFavorited: !currentlyFav,
      favoriteCountDelta: state.favoriteCountDelta + (currentlyFav ? -1 : 1),
    );
    try {
      if (currentlyFav) {
        await _repository.unfavoritePost(post.id);
      } else {
        await _repository.favoritePost(post.id);
      }
    } catch (_) {
      state = state.copyWith(
        optimisticIsFavorited: currentlyFav,
        favoriteCountDelta: state.favoriteCountDelta + (currentlyFav ? 1 : -1),
      );
      rethrow;
    }
  }
}

final interactionRepositoryProvider = Provider<InteractionRepository>((ref) {
  return InteractionRepository();
});

final interactionNotifierProvider =
    StateNotifierProvider.family<InteractionNotifier, InteractionState, String>((
      ref,
      postId,
    ) {
      return InteractionNotifier(
        repository: ref.read(interactionRepositoryProvider),
      );
    });
