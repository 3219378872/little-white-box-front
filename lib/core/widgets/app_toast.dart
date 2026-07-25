import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

void showAppError(BuildContext context, String message) {
  showFToast(
    context: context,
    variant: FToastVariant.destructive,
    icon: const Icon(FLucideIcons.circleAlert),
    title: Text(message),
  );
}

void showAppSuccess(BuildContext context, String message) {
  showFToast(
    context: context,
    icon: const Icon(FLucideIcons.circleCheck),
    title: Text(message),
  );
}
