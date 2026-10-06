import 'package:flutter_riverpod/legacy.dart';

import '../../auth/application/auth_notifier.dart';
import '../data/user_repository.dart';
import 'profile_dependencies.dart';

/// 关注按钮的本地状态：[following] 为空表示沿用服务端读取的关注值。
class FollowState {
  /// 最近一次本地关注操作的结果；请求失败时回滚为操作前的值。
  final bool? following;

  /// 关注/取关请求进行中，按钮应禁用以免重复提交。
  final bool isBusy;

  const FollowState({this.following, this.isBusy = false});

  /// 合并服务端读取的 [remote]：用户操作过则以本地结果为准。
  bool resolve(bool remote) => following ?? remote;
}

/// 个人页与帖子详情共用的关注命令：乐观切换、同一时刻只发一个请求、失败回滚。
class FollowController extends StateNotifier<FollowState> {
  final UserRepository _repository;

  /// 被关注用户的 ID（十进制字符串，保留 int64 精度）。
  final String userId;

  FollowController({required UserRepository repository, required this.userId})
    : _repository = repository,
      super(const FollowState());

  /// 按调用方当前展示的 [currentlyFollowing] 切换关注；失败时恢复并把错误抛给页面提示。
  Future<void> toggle(bool currentlyFollowing) async {
    // 请求进行中忽略重复点击，避免关注与取关请求交错。
    if (state.isBusy) return;
    final previous = state.following;
    // 乐观更新：先翻转按钮，再等待服务端确认。
    state = FollowState(following: !currentlyFollowing, isBusy: true);
    try {
      if (currentlyFollowing) {
        await _repository.unfollowUser(userId);
      } else {
        await _repository.followUser(userId);
      }
      // 成功：保留乐观结果作为本地覆盖值，只释放忙碌标记。
      if (mounted) state = FollowState(following: state.following);
    } catch (_) {
      // 回滚到操作前的覆盖值（可能为空，即重新采用服务端值）。
      if (mounted) state = FollowState(following: previous);
      rethrow;
    }
  }
}

/// 按被关注用户共享关注状态；随会话身份重建，页面离开后自动释放以便重新读取服务端值。
final followControllerProvider = StateNotifierProvider.autoDispose
    .family<FollowController, FollowState, String>((ref, userId) {
      ref.watch(authSessionIdentityProvider);
      return FollowController(
        repository: ref.read(userRepositoryProvider),
        userId: userId,
      );
    });
