import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/interaction_repository.dart';

/// 单帖点赞/收藏的乐观关系；计数按各消费端的服务器快照对账。
/// 服务端失败时回滚并抛出，由 UI 层提示。
class InteractionState {
  final bool? optimisticIsLiked;
  final bool? optimisticIsFavorited;

  const InteractionState({this.optimisticIsLiked, this.optimisticIsFavorited});

  // 同一帖子可同时有旧卡片与新详情，按各自的关系计算本用户贡献差。
  // 服务器聚合计数最终一致；关系已收敛时直接显示其返回的计数，
  // 不将无法确认的聚合滞后当作永久增量重复叠加。
  int likeCountFor({required int count, required bool isLiked}) =>
      count +
      _contribution(optimisticIsLiked ?? isLiked) -
      _contribution(isLiked);

  int favoriteCountFor({required int count, required bool isFavorited}) =>
      count +
      _contribution(optimisticIsFavorited ?? isFavorited) -
      _contribution(isFavorited);

  static int _contribution(bool active) => active ? 1 : 0;

  InteractionState copyWith({
    bool? optimisticIsLiked,
    bool clearOptimisticIsLiked = false,
    bool? optimisticIsFavorited,
    bool clearOptimisticIsFavorited = false,
  }) {
    return InteractionState(
      optimisticIsLiked: clearOptimisticIsLiked
          ? null
          : (optimisticIsLiked ?? this.optimisticIsLiked),
      optimisticIsFavorited: clearOptimisticIsFavorited
          ? null
          : (optimisticIsFavorited ?? this.optimisticIsFavorited),
    );
  }
}

class InteractionNotifier extends StateNotifier<InteractionState> {
  final InteractionRepository _repository;
  bool _likeInFlight = false;
  bool _favoriteInFlight = false;

  InteractionNotifier({required InteractionRepository repository})
    : _repository = repository,
      super(const InteractionState());

  Future<void> toggleLike(GetPostResp post) {
    return toggleLikeTarget(
      targetId: post.id,
      currentlyLiked: state.optimisticIsLiked ?? post.isLiked,
    );
  }

  Future<void> toggleLikeTarget({
    required Object targetId,
    required bool currentlyLiked,
  }) async {
    if (_likeInFlight) return;
    _likeInFlight = true;
    final previous = state.optimisticIsLiked;
    state = state.copyWith(optimisticIsLiked: !currentlyLiked);
    try {
      if (currentlyLiked) {
        await _repository.unlikeTarget(targetId, 1);
      } else {
        await _repository.likeTarget(targetId, 1);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        optimisticIsLiked: previous,
        clearOptimisticIsLiked: previous == null,
      );
      rethrow;
    } finally {
      _likeInFlight = false;
    }
  }

  Future<void> toggleFavorite(GetPostResp post) async {
    if (_favoriteInFlight) return;
    _favoriteInFlight = true;
    final previous = state.optimisticIsFavorited;
    final currentlyFav = state.optimisticIsFavorited ?? post.isFavorited;
    state = state.copyWith(optimisticIsFavorited: !currentlyFav);
    try {
      if (currentlyFav) {
        await _repository.unfavoritePost(post.id);
      } else {
        await _repository.favoritePost(post.id);
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        optimisticIsFavorited: previous,
        clearOptimisticIsFavorited: previous == null,
      );
      rethrow;
    } finally {
      _favoriteInFlight = false;
    }
  }
}

final interactionRepositoryProvider = Provider<InteractionRepository>((ref) {
  return InteractionRepository();
});

final interactionNotifierProvider = StateNotifierProvider.autoDispose
    .family<InteractionNotifier, InteractionState, String>((ref, postId) {
      ref.watch(authSessionIdentityProvider);
      return InteractionNotifier(
        repository: ref.read(interactionRepositoryProvider),
      );
    });
