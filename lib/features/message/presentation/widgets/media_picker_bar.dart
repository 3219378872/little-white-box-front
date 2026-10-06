import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../media/data/media_repository.dart';

/// 输入框上方的媒体入口：每种 [MediaKind] 一个按钮，选择或上传进行中时尾部显示进度圈。
class MediaPickerBar extends StatelessWidget {
  /// 为 false 时全部按钮禁用（发送中、选择中或已有待发送媒体）。
  final bool enabled;

  /// 文件选择或上传进行中。
  final bool busy;

  /// 用户点了某种媒体按钮。
  final ValueChanged<MediaKind> onPick;

  const MediaPickerBar({
    super.key,
    required this.enabled,
    required this.busy,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final kind in MediaKind.values) ...[
            FButton.icon(
              variant: FButtonVariant.ghost,
              onPress: enabled ? () => onPick(kind) : null,
              child: Icon(
                switch (kind) {
                  MediaKind.image => FLucideIcons.image,
                  MediaKind.video => FLucideIcons.video,
                  MediaKind.audio => FLucideIcons.audioLines,
                },
                semanticLabel: switch (kind) {
                  MediaKind.image => '发送图片',
                  MediaKind.video => '发送视频',
                  MediaKind.audio => '发送语音文件',
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (busy) const FCircularProgress(size: .sm),
        ],
      ),
    );
  }
}
