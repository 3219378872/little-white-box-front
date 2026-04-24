import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/api/api_exceptions.dart';

class VerifyCodeButton extends StatefulWidget {
  final Future<void> Function() onSend;

  const VerifyCodeButton({super.key, required this.onSend});

  @override
  State<VerifyCodeButton> createState() => _VerifyCodeButtonState();
}

class _VerifyCodeButtonState extends State<VerifyCodeButton> {
  int _countdown = 0;
  Timer? _timer;
  bool _isSending = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_countdown > 0 || _isSending) return;
    setState(() => _isSending = true);
    try {
      await widget.onSend();
      _startCountdown();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: ${friendlyErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

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
    return TextButton(
      onPressed: enabled ? _handleSend : null,
      child: Text(
        _isSending
            ? '发送中...'
            : _countdown > 0
                ? '${_countdown}s'
                : '获取验证码',
      ),
    );
  }
}
