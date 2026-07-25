import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/user_repository.dart';

final _userRepoProvider = Provider((ref) => UserRepository());

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String _avatarUrl = '';
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final auth = ref.read(authNotifierProvider);
    if (auth.userId == null) return;
    try {
      final user = await ref
          .read(_userRepoProvider)
          .getUserProfile(auth.userId!.toInt());
      setState(() {
        _nicknameCtrl.text = user.nickname;
        _bioCtrl.text = user.bio;
        _avatarUrl = user.avatarUrl;
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        showAppError(context, '加载失败: $e');
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(_userRepoProvider)
          .updateUserProfile(
            UpdateProfileReq(
              nickname: _nicknameCtrl.text.trim(),
              avatarUrl: _avatarUrl,
              bio: _bioCtrl.text.trim(),
            ),
          );
      if (mounted) {
        showAppSuccess(context, '保存成功');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppError(context, '保存失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('编辑资料'),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        suffixes: [
          FButton(
            size: .sm,
            mainAxisSize: MainAxisSize.min,
            onPress: _isLoading ? null : _save,
            child: _isLoading
                ? const FCircularProgress(size: .sm)
                : const Text('保存'),
          ),
        ],
      ),
      child: !_isInitialized
          ? const Center(child: FCircularProgress())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: CachedAvatar(
                    url: _avatarUrl,
                    name: _nicknameCtrl.text,
                    radius: 48,
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
            ),
    );
  }
}
