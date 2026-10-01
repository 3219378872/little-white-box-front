import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

Future<void> showAppAlert({
  required BuildContext context,
  required String title,
  required String message,
  String actionLabel = '知道了',
}) {
  return showFDialog<void>(
    context: context,
    builder: (context, style, animation) => FDialog(
      style: style,
      animation: animation,
      semanticsLabel: title,
      builder: (context, style) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DefaultTextStyle.merge(
              style: style.titleTextStyle,
              child: Text(title),
            ),
            const SizedBox(height: 12),
            DefaultTextStyle.merge(
              style: style.bodyTextStyle,
              child: Text(message),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FButton(
                size: .sm,
                mainAxisSize: MainAxisSize.min,
                onPress: () => Navigator.of(context).pop(),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 二次确认；返回 true 表示确认。
Future<bool> showAppConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '取消',
}) async {
  var confirmed = false;
  await showFDialog<void>(
    context: context,
    builder: (context, style, animation) => FDialog(
      style: style,
      animation: animation,
      semanticsLabel: title,
      builder: (context, style) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DefaultTextStyle.merge(
              style: style.titleTextStyle,
              child: Text(title),
            ),
            const SizedBox(height: 12),
            DefaultTextStyle.merge(
              style: style.bodyTextStyle,
              child: Text(message),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FButton(
                  key: const Key('app-confirm-cancel'),
                  size: .sm,
                  variant: .outline,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => Navigator.of(context).pop(),
                  child: Text(cancelLabel),
                ),
                const SizedBox(width: 8),
                FButton(
                  key: const Key('app-confirm-ok'),
                  size: .sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () {
                    confirmed = true;
                    Navigator.of(context).pop();
                  },
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed;
}
