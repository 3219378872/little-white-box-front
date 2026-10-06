import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/widgets/app_toast.dart';

/// 「获取验证码」按钮：调用 [onSend] 成功后进入 60 秒倒计时，期间与发送中都不可再点；
/// 发送失败时提示错误且不进入倒计时。
class VerifyCodeButton extends StatefulWidget {
  final Future<void> Function() onSend;

  const VerifyCodeButton({super.key, required this.onSend});

  @override
  State<VerifyCodeButton> createState() => _VerifyCodeButtonState();
}

// 维护倒计时秒数与发送中状态。
class _VerifyCodeButtonState extends State<VerifyCodeButton> {
  int _countdown = 0;
  Timer? _timer;
  bool _isSending = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 防重入：倒计时或发送中直接忽略点击。
  Future<void> _handleSend() async {
    if (_countdown > 0 || _isSending) return;
    setState(() => _isSending = true);
    try {
      await widget.onSend();
      if (!mounted) return;
      _startCountdown();
    } catch (e) {
      if (mounted) {
        showAppError(context, '发送失败: ${friendlyErrorMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // 每秒递减，归零时停止计时器。
  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdown = 0);
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _countdown == 0 && !_isSending;
    return SizedBox(
      width: 128,
      child: FButton(
        variant: .outline,
        onPress: enabled ? _handleSend : null,
        child: Text(
          _isSending
              ? '发送中...'
              : _countdown > 0
              ? '${_countdown}s'
              : '获取验证码',
        ),
      ),
    );
  }
}

/// 验证码输入框与「获取验证码」按钮的组合，供登录与注册表单复用。
class VerifyCodeField extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function() onSend;

  const VerifyCodeField({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: FTextField(
            control: FTextFieldControl.managed(controller: controller),
            keyboardType: TextInputType.number,
            label: const Text('验证码'),
            prefixBuilder: (context, style, variants) =>
                FTextField.prefixIconBuilder(
                  context,
                  style,
                  variants,
                  const Icon(FLucideIcons.messageSquareText),
                ),
          ),
        ),
        const SizedBox(width: 12),
        VerifyCodeButton(onSend: onSend),
      ],
    );
  }
}
