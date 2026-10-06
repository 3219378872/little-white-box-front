import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/edit_profile_controller.dart';
import '../../../core/router/app_routes.dart';

/// 编辑本人资料页：载入当前昵称与简介，保存后返回个人主页。
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

// 只持有输入框；载入、重试与保存由 EditProfileController 负责。
class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 资料每次载入成功时回填输入框，之后由用户编辑；页面释放时监听自动关闭。
    ref.listenManual(
      editProfileControllerProvider.select((state) => state.profile),
      (previous, next) {
        if (next == null || identical(previous, next)) return;
        _nicknameCtrl.text = next.nickname;
        _bioCtrl.text = next.bio;
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  EditProfileController get _controller =>
      ref.read(editProfileControllerProvider.notifier);

  // 保存成功提示并返回，失败留在本页提示原因。
  Future<void> _save() async {
    try {
      await _controller.save(nickname: _nicknameCtrl.text, bio: _bioCtrl.text);
      if (mounted) {
        showAppSuccess(context, '保存成功');
        context.canPop() ? context.pop() : context.go(AppRoutes.profile);
      }
    } catch (e) {
      if (mounted) {
        showAppError(context, '保存失败: ${friendlyErrorMessage(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editProfileControllerProvider);
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('编辑资料'),
        prefixes: [
          FHeaderAction.back(
            onPress: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.profile),
          ),
        ],
        // 保存按钮：保存中、未载入或载入失败时禁用。
        suffixes: [
          FButton(
            size: .sm,
            mainAxisSize: MainAxisSize.min,
            onPress: state.canSave ? _save : null,
            child: state.isSaving
                ? const FCircularProgress(size: .sm)
                : const Text('保存'),
          ),
        ],
      ),
      child: _buildBody(state),
    );
  }

  // 表单区：载入失败给重试，载入中给进度，否则展示头像预览与输入框。
  Widget _buildBody(EditProfileState state) {
    final loadError = state.loadError;
    if (loadError != null) {
      return ErrorView(
        message: '加载失败: ${friendlyErrorMessage(loadError)}',
        onRetry: _controller.load,
      );
    }
    final profile = state.profile;
    if (profile == null) {
      return const LoadingView();
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CachedAvatar(
            url: profile.avatarUrl,
            name: _nicknameCtrl.text,
            radius: 32,
          ),
        ),
        const SizedBox(height: 24),
        FTextField(
          control: FTextFieldControl.managed(controller: _nicknameCtrl),
          label: const Text('昵称'),
          maxLength: 20,
        ),
        const SizedBox(height: 16),
        FTextField.multiline(
          control: FTextFieldControl.managed(controller: _bioCtrl),
          label: const Text('个人简介'),
          minLines: 4,
          maxLines: 4,
          maxLength: 200,
        ),
      ],
    );
  }
}
