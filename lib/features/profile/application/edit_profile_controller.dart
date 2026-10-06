import 'package:flutter_riverpod/legacy.dart';

import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/user_repository.dart';
import 'profile_dependencies.dart';

/// 编辑页回填用的本人资料快照。
class EditableProfile {
  final String nickname;
  final String bio;

  /// 头像本页不可修改，只用于预览并在保存时原样回传。
  final String avatarUrl;

  const EditableProfile({
    required this.nickname,
    required this.bio,
    required this.avatarUrl,
  });
}

/// 编辑资料页状态：[profile] 为空表示尚未载入，[loadError] 非空时页面展示可重试的错误态。
class EditProfileState {
  final EditableProfile? profile;
  final Object? loadError;

  /// 保存请求进行中，保存按钮应禁用。
  final bool isSaving;

  const EditProfileState({this.profile, this.loadError, this.isSaving = false});

  /// 只有载入成功且没有保存在途时才允许保存。
  bool get canSave => profile != null && loadError == null && !isSaving;
}

/// 编辑本人资料的载入与保存命令（FQ-001）：页面只管输入框、提示与导航。
class EditProfileController extends StateNotifier<EditProfileState> {
  final UserRepository _repository;

  /// 当前登录用户；身份恢复中或未登录时为 null，此时不发起载入。
  final Object? userId;

  EditProfileController({required UserRepository repository, this.userId})
    : _repository = repository,
      super(const EditProfileState()) {
    load();
  }

  /// 读取本人资料；失败进入可重试的错误态，而不是永久停在载入中。
  Future<void> load() async {
    final id = userId;
    if (id == null) return;
    // 重试时先清掉错误，页面回到载入中。
    if (state.loadError != null) state = const EditProfileState();
    try {
      final user = await _repository.getUserProfile(id);
      if (!mounted) return;
      state = EditProfileState(
        profile: EditableProfile(
          nickname: user.nickname,
          bio: user.bio,
          avatarUrl: user.avatarUrl,
        ),
      );
    } catch (error) {
      if (mounted) state = EditProfileState(loadError: error);
    }
  }

  /// 保存昵称与简介（去首尾空白），头像原样回传；失败时把错误抛给页面提示。
  Future<void> save({required String nickname, required String bio}) async {
    final profile = state.profile;
    if (profile == null || !state.canSave) return;
    state = EditProfileState(profile: profile, isSaving: true);
    try {
      await _repository.updateUserProfile(
        UpdateProfileReq(
          nickname: nickname.trim(),
          avatarUrl: profile.avatarUrl,
          bio: bio.trim(),
        ),
      );
    } finally {
      if (mounted) state = EditProfileState(profile: profile);
    }
  }
}

/// 编辑页每次进入新建一份；随登录身份重建，冷启动深链进入时等身份恢复后再载入。
final editProfileControllerProvider =
    StateNotifierProvider.autoDispose<EditProfileController, EditProfileState>((
      ref,
    ) {
      final identity = ref.watch(authenticatedSessionIdentityProvider);
      return EditProfileController(
        repository: ref.read(userRepositoryProvider),
        userId: identity == null ? null : ref.read(authNotifierProvider).userId,
      );
    });
