import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
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
  bool _loadRequested = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final auth = ref.read(authNotifierProvider);
    // 冷启动深链进入本页时身份可能仍在恢复中；返回后由 build 的 watch 再触发。
    if (auth.isLoading || auth.userId == null) {
      if (mounted) setState(() => _loadRequested = false);
      return;
    }
    try {
      final user = await ref
          .read(_userRepoProvider)
          .getUserProfile(auth.userId!);
      if (!mounted) return;
      setState(() {
        _nicknameCtrl.text = user.nickname;
        _bioCtrl.text = user.bio;
        _avatarUrl = user.avatarUrl;
        _isInitialized = true;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      // 加载失败进入可重试的错误态，而不是永久停在进度圈。
      setState(() => _loadError = e);
    }
  }

  /// 身份就绪时安排一次资料加载；未就绪则等 build 的 watch 在恢复后重排再触发。
  void _scheduleLoad() {
    if (_isInitialized || _loadRequested || _loadError != null) return;
    final auth = ref.read(authNotifierProvider);
    if (auth.isLoading || auth.userId == null) return;
    _loadRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfile();
    });
  }

  void _retryLoad() {
    setState(() => _loadError = null);
    _loadProfile();
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
        context.canPop() ? context.pop() : context.go('/profile');
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
    // watch 身份状态：冷启动深链进入时等恢复完成后自动重排并触发加载。
    ref.watch(authNotifierProvider);
    _scheduleLoad();
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('编辑资料'),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/profile'),
          ),
        ],
        suffixes: [
          FButton(
            size: .sm,
            mainAxisSize: MainAxisSize.min,
            onPress: (_isLoading || !_isInitialized || _loadError != null)
                ? null
                : _save,
            child: _isLoading
                ? const FCircularProgress(size: .sm)
                : const Text('保存'),
          ),
        ],
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return ErrorView(
        message: '加载失败: ${friendlyErrorMessage(_loadError!)}',
        onRetry: _retryLoad,
      );
    }
    if (!_isInitialized) {
      return const Center(child: FCircularProgress());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CachedAvatar(
            url: _avatarUrl,
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
