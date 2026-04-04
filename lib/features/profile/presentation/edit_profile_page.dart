import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(_userRepoProvider).updateUserProfile(
            UpdateProfileReq(
              nickname: _nicknameCtrl.text.trim(),
              avatarUrl: _avatarUrl,
              bio: _bioCtrl.text.trim(),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存成功')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          FilledButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: CachedAvatar(url: _avatarUrl, radius: 48),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nicknameCtrl,
                  decoration: const InputDecoration(labelText: '昵称'),
                  maxLength: 20,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(
                    labelText: '个人简介',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  maxLength: 200,
                ),
              ],
            ),
    );
  }
}
