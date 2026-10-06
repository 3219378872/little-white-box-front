import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_toast.dart';
import '../application/auth_notifier.dart';
import 'widgets/verify_code_button.dart';
import '../../../core/router/app_routes.dart';

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
  int _registerAttempt = 0;

  @override
  void dispose() {
    _registerAttempt++;
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

    final attempt = ++_registerAttempt;
    setState(() => _isLoading = true);
    try {
      // 注册成功即登录；离开页面后的迟到响应由 AuthNotifier 按 isCurrent 丢弃。
      final started = await ref
          .read(authNotifierProvider.notifier)
          .register(
            username: _usernameCtrl.text,
            password: _passwordCtrl.text,
            phone: _phoneCtrl.text,
            verifyCode: _codeCtrl.text,
            isCurrent: () => _ownsRegisterMutation(attempt),
          );
      // Pushed register keeps the public URL; redirect will not pop this page.
      if (!started || !mounted || !_ownsRegisterMutation(attempt)) return;
      context.go(AppRoutes.feed);
    } catch (e) {
      if (mounted && attempt == _registerAttempt) _showError(e.toString());
    } finally {
      if (mounted && attempt == _registerAttempt) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _ownsRegisterMutation(int attempt) {
    return mounted &&
        attempt == _registerAttempt &&
        (ModalRoute.of(context)?.isCurrent ?? false);
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
            onPress: _isLoading
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.login),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            children: [
              const SizedBox(height: 12),
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
                onSend: () => ref
                    .read(authNotifierProvider.notifier)
                    .sendVerifyCode(
                      _phoneCtrl.text,
                      VerifyCodePurpose.register,
                    ),
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
                onPress: _isLoading ? null : () => context.go(AppRoutes.login),
                child: const Text('已有账号？去登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
