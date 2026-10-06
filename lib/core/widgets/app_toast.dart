import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// 以全局 [FToaster] 弹出错误提示，供操作失败后的非阻断反馈。
void showAppError(BuildContext context, String message) {
  showFToast(
    context: context,
    variant: FToastVariant.destructive,
    icon: const Icon(FLucideIcons.circleAlert),
    title: Text(message),
  );
}

/// 以全局 [FToaster] 弹出成功提示。
void showAppSuccess(BuildContext context, String message) {
  showFToast(
    context: context,
    icon: const Icon(FLucideIcons.circleCheck),
    title: Text(message),
  );
}
