import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/auth_notifier.dart';
import '../data/auth_repository.dart';
import 'widgets/verify_code_button.dart';

final _authRepoProvider = Provider((ref) => AuthRepository());

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_usernameCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _codeCtrl.text.isEmpty) {
      _showError('请填写所有字段');
      return;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _showError('两次密码输入不一致');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final resp = await ref
          .read(_authRepoProvider)
          .registerUser(
            username: _usernameCtrl.text,
            password: _passwordCtrl.text,
            phone: _phoneCtrl.text,
            verifyCode: _codeCtrl.text,
          );
      await ref
          .read(authNotifierProvider.notifier)
          .onLoginSuccess(resp.userId, resp.token,
              refreshToken: resp.refreshToken);
      // Pushed register keeps the public URL; redirect will not pop this page.
      if (mounted) context.go('/feed');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    showAppError(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('注册'),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/auth/login'),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            children: [
              const SizedBox(height: 24),
              FTextField(
                control: FTextFieldControl.managed(controller: _usernameCtrl),
                label: const Text('用户名'),
                prefixBuilder: (context, style, variants) =>
                    FTextField.prefixIconBuilder(
                      context,
                      style,
                      variants,
                      const Icon(FLucideIcons.userRound),
                    ),
              ),
              const SizedBox(height: 16),
              FTextField.password(
                control: FTextFieldControl.managed(controller: _passwordCtrl),
                label: const Text('密码'),
                prefixBuilder: (context, style, _, variants) =>
                    FTextField.prefixIconBuilder(
                      context,
                      style,
                      variants,
                      const Icon(FLucideIcons.lock),
                    ),
              ),
              const SizedBox(height: 16),
              FTextField.password(
                control: FTextFieldControl.managed(
                  controller: _confirmPasswordCtrl,
                ),
                label: const Text('确认密码'),
                prefixBuilder: (context, style, _, variants) =>
                    FTextField.prefixIconBuilder(
                      context,
                      style,
                      variants,
                      const Icon(FLucideIcons.lock),
                    ),
              ),
              const SizedBox(height: 16),
              FTextField(
                control: FTextFieldControl.managed(controller: _phoneCtrl),
                keyboardType: TextInputType.phone,
                label: const Text('手机号'),
                prefixBuilder: (context, style, variants) =>
                    FTextField.prefixIconBuilder(
                      context,
                      style,
                      variants,
                      const Icon(FLucideIcons.phone),
                    ),
              ),
              const SizedBox(height: 16),
              VerifyCodeField(
                controller: _codeCtrl,
                onSend: () =>
                    ref.read(_authRepoProvider).sendCode(_phoneCtrl.text, 1),
              ),
              const SizedBox(height: 24),
              FButton(
                onPress: _isLoading ? null : _register,
                child: _isLoading
                    ? const FCircularProgress(size: .sm)
                    : const Text('注册'),
              ),
              const SizedBox(height: 16),
              FButton(
                variant: .ghost,
                onPress: () => context.go('/auth/login'),
                child: const Text('已有账号？去登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
