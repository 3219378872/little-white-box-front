import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/auth_notifier.dart';
import 'widgets/verify_code_button.dart';
import '../../../core/router/app_routes.dart';

/// 登录页：密码登录与手机验证码登录两个标签页，成功后进入首页。
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

// 持有两套表单输入与提交中状态；[_loginAttempt] 标识最近一次提交，
// 页面销毁或再次提交后，旧请求的结果不再生效。
class _LoginPageState extends ConsumerState<LoginPage> {
  // 密码登录
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // 验证码登录
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _isLoading = false;
  int _loginAttempt = 0;

  @override
  void dispose() {
    // 作废进行中的登录尝试，迟到的成功响应不会再开启会话。
    _loginAttempt++;
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // 校验必填后以用户名密码登录。
  Future<void> _loginWithPassword() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      _showError('请填写用户名和密码');
      return;
    }
    await _doLogin(
      (auth, isCurrent) => auth.loginWithPassword(
        _usernameCtrl.text,
        _passwordCtrl.text,
        isCurrent: isCurrent,
      ),
    );
  }

  // 校验必填后以手机验证码登录。
  Future<void> _loginWithCode() async {
    if (_phoneCtrl.text.isEmpty || _codeCtrl.text.isEmpty) {
      _showError('请填写手机号和验证码');
      return;
    }
    await _doLogin(
      (auth, isCurrent) => auth.loginWithVerifyCode(
        _phoneCtrl.text,
        _codeCtrl.text,
        isCurrent: isCurrent,
      ),
    );
  }

  // 登录命令由 AuthNotifier 执行；页面只提供“本次尝试仍属于当前页面”的判定与导航。
  Future<void> _doLogin(
    Future<bool> Function(AuthNotifier auth, bool Function() isCurrent) login,
  ) async {
    final attempt = ++_loginAttempt;
    setState(() => _isLoading = true);
    try {
      final started = await login(
        ref.read(authNotifierProvider.notifier),
        () => _ownsLoginMutation(attempt),
      );
      // Pushed login keeps the public URL; redirect will not pop this page.
      if (!started || !mounted || !_ownsLoginMutation(attempt)) return;
      context.go(AppRoutes.feed);
    } catch (e) {
      if (mounted && attempt == _loginAttempt) {
        _showError(friendlyErrorMessage(e));
      }
    } finally {
      if (mounted && attempt == _loginAttempt) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 本次尝试仍是最近一次、页面仍挂载且位于路由栈顶时，才允许写入会话与导航。
  bool _ownsLoginMutation(int attempt) {
    return mounted &&
        attempt == _loginAttempt &&
        (ModalRoute.of(context)?.isCurrent ?? false);
  }

  void _showError(String msg) {
    showAppError(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FScaffold(
      childPad: false,
      // 返回：从受保护入口压入时回到原页，直接打开时回首页。
      header: FHeader.nested(
        title: const SizedBox.shrink(),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.feed),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // 品牌标识。
              const SizedBox(height: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  FLucideIcons.box,
                  size: 38,
                  color: theme.colors.primaryForeground,
                ),
              ),
              const SizedBox(height: 12),
              Text('小白盒', style: theme.typography.display.xl2),
              const SizedBox(height: 24),
              // 两种登录方式的标签页。
              Expanded(
                child: FTabs(
                  expands: true,
                  children: [
                    FTabEntry(
                      label: const Text('密码登录'),
                      child: _passwordForm(),
                    ),
                    FTabEntry(label: const Text('验证码登录'), child: _codeForm()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 密码登录表单与去注册入口。
  Widget _passwordForm() {
    return ListView(
      padding: const EdgeInsets.only(top: 24),
      children: [
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
        const SizedBox(height: 24),
        FButton(
          onPress: _isLoading ? null : _loginWithPassword,
          child: _isLoading
              ? const FCircularProgress(size: .sm)
              : const Text('登录'),
        ),
        const SizedBox(height: 16),
        FButton(
          variant: .ghost,
          onPress: _isLoading ? null : () => context.go(AppRoutes.register),
          child: const Text('没有账号？去注册'),
        ),
      ],
    );
  }

  // 验证码登录表单：手机号、带倒计时的验证码输入与去注册入口。
  Widget _codeForm() {
    return ListView(
      padding: const EdgeInsets.only(top: 24),
      children: [
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
              .sendVerifyCode(_phoneCtrl.text, VerifyCodePurpose.login),
        ),
        const SizedBox(height: 24),
        FButton(
          onPress: _isLoading ? null : _loginWithCode,
          child: _isLoading
              ? const FCircularProgress(size: .sm)
              : const Text('登录'),
        ),
        const SizedBox(height: 16),
        FButton(
          variant: .ghost,
          onPress: _isLoading ? null : () => context.go(AppRoutes.register),
          child: const Text('没有账号？去注册'),
        ),
      ],
    );
  }
}
