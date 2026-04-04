import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/auth_notifier.dart';
import '../data/auth_repository.dart';
import 'widgets/verify_code_button.dart';

final _authRepoProvider = Provider((ref) => AuthRepository());

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 密码登录
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // 验证码登录
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithPassword() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      _showError('请填写用户名和密码');
      return;
    }
    await _doLogin(() => ref
        .read(_authRepoProvider)
        .loginWithPassword(_usernameCtrl.text, _passwordCtrl.text));
  }

  Future<void> _loginWithCode() async {
    if (_phoneCtrl.text.isEmpty || _codeCtrl.text.isEmpty) {
      _showError('请填写手机号和验证码');
      return;
    }
    await _doLogin(() => ref
        .read(_authRepoProvider)
        .loginWithVerifyCode(_phoneCtrl.text, _codeCtrl.text));
  }

  Future<void> _doLogin(Future<dynamic> Function() loginFn) async {
    setState(() => _isLoading = true);
    try {
      final resp = await loginFn();
      await ref
          .read(authNotifierProvider.notifier)
          .onLoginSuccess(resp.userId, resp.token);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Icon(
                Icons.all_inclusive,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text('小白盒', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 32),
              TabBar(
                controller: _tabController,
                tabs: const [Tab(text: '密码登录'), Tab(text: '验证码登录')],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_passwordForm(), _codeForm()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(
              labelText: '用户名',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _loginWithPassword,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登录'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/auth/register'),
            child: const Text('没有账号？去注册'),
          ),
        ],
      ),
    );
  }

  Widget _codeForm() {
    return ListView(
      children: [
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: '手机号',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '验证码',
                  prefixIcon: Icon(Icons.sms_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            VerifyCodeButton(
              onSend: () =>
                  ref.read(_authRepoProvider).sendCode(_phoneCtrl.text, 2),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _loginWithCode,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('登录'),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go('/auth/register'),
          child: const Text('没有账号？去注册'),
        ),
      ],
    );
  }
}
