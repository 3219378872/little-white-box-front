import 'package:flutter_riverpod/legacy.dart';

import '../../auth/application/auth_notifier.dart';
import '../data/personalization_repository.dart';
import 'profile_dependencies.dart';

/// 个性化推荐开关状态：[enabled] 为空表示尚未读到或读取失败，此时不展示开关。
class PersonalizationState {
  /// 当前偏好；为空时页面不渲染开关。
  final bool? enabled;

  /// 写请求进行中，开关应禁用。
  final bool isBusy;

  const PersonalizationState({this.enabled, this.isBusy = false});
}

/// 本人主页的个性化推荐开关：首屏读取偏好，切换时乐观更新、失败回滚。
class PersonalizationController extends StateNotifier<PersonalizationState> {
  final PersonalizationRepository _repository;

  PersonalizationController(this._repository, {bool loadImmediately = true})
    : super(const PersonalizationState()) {
    if (loadImmediately) load();
  }

  /// 读取当前偏好；失败时隐藏开关，而不是展示一个可能错误的默认值。
  Future<void> load() async {
    try {
      final preference = await _repository.getPreference();
      if (mounted) state = PersonalizationState(enabled: preference.enabled);
    } catch (_) {
      if (mounted) state = const PersonalizationState();
    }
  }

  /// 写入新偏好；失败时恢复原值并把错误抛给页面提示。
  Future<void> setEnabled(bool enabled) async {
    // 写请求进行中忽略重复切换。
    if (state.isBusy) return;
    final previous = state.enabled;
    // 乐观更新，避免开关在请求期间回弹。
    state = PersonalizationState(enabled: enabled, isBusy: true);
    try {
      await _repository.setPreference(enabled: enabled);
      if (mounted) state = PersonalizationState(enabled: state.enabled);
    } catch (_) {
      if (mounted) state = PersonalizationState(enabled: previous);
      rethrow;
    }
  }
}

/// 仅在本人主页 watch；随会话身份重建，换号后重新读取偏好。
final personalizationControllerProvider =
    StateNotifierProvider.autoDispose<
      PersonalizationController,
      PersonalizationState
    >((ref) {
      ref.watch(authSessionIdentityProvider);
      return PersonalizationController(
        ref.read(personalizationRepositoryProvider),
      );
    });
