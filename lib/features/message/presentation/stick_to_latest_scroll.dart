import 'package:flutter/widgets.dart';

/// 私信线程列表的贴底滚动：停在底部附近时新消息自动露出，用户上翻阅读历史时不被拉回。
///
/// 只服务消息线程页；Agent 页的贴底逻辑按流式增量与用户滚动通知判断，语义不同，暂不合并。
class StickToLatestScroll {
  StickToLatestScroll() {
    controller.addListener(_rememberPin);
  }

  /// 交给线程 ListView 的滚动控制器，随 [dispose] 一起释放。
  final controller = ScrollController();

  // 距底部不超过该距离即视为贴底。
  static const _pinDistance = 48.0;

  // 用户当前是否停在底部附近。
  bool _pinToLatest = true;
  // 上次报告的消息数，用于识别新消息到达。
  int _seenCount = 0;
  // 释放后忽略已排队的帧回调。
  bool _disposed = false;

  /// 切换会话或账号时回到“首次打开”状态，下一批消息到达后直接跳到底部。
  void reset() {
    _seenCount = 0;
    _pinToLatest = true;
  }

  /// 每次构建时报告当前消息数：首次出现消息或仍贴底时跳到最新一条。
  void follow(int messageCount) {
    if (messageCount == _seenCount) return;
    final opened = _seenCount == 0 && messageCount > 0;
    _seenCount = messageCount;
    if (opened || _pinToLatest) revealLatest();
  }

  /// 下一帧布局完成后直接跳到底部，已在底部时不动。
  void revealLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !controller.hasClients) return;
      final target = controller.position.maxScrollExtent;
      if ((controller.offset - target).abs() < 1) return;
      controller.jumpTo(target);
    });
  }

  /// 文本发送成功后在下一帧平滑滚到底部。
  void animateToLatestAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void dispose() {
    _disposed = true;
    controller.removeListener(_rememberPin);
    controller.dispose();
  }

  // 每次滚动记录是否仍贴底，决定下一批消息到达时要不要跟随。
  void _rememberPin() {
    if (!controller.hasClients) return;
    final position = controller.position;
    _pinToLatest = position.maxScrollExtent - position.pixels <= _pinDistance;
  }
}
