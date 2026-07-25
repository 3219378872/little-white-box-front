import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class CachedAvatar extends StatelessWidget {
  final String? url;

  /// 用于无图兜底的名称：取其首字符，并按名字确定性地分配背景色。
  final String? name;
  final double radius;

  const CachedAvatar({super.key, this.url, this.name, this.radius = 20});

  /// 柔和的低饱和色板，按名字 hash 确定性取色。
  static const _palette = [
    Color(0xFF5B8DB8), // 蓝
    Color(0xFF4FA3A5), // 青
    Color(0xFFD98E5F), // 橙
    Color(0xFF9B7EBD), // 紫
    Color(0xFF6FA876), // 绿
    Color(0xFFC97B8E), // 粉
    Color(0xFF7E9CC6), // 灰蓝
    Color(0xFFB8A25F), // 芥末
  ];

  @override
  Widget build(BuildContext context) {
    final fallback = _fallback();
    final style = FAvatarStyleDelta.delta(backgroundColor: _fallbackColor());
    if (url == null || url!.isEmpty) {
      return FAvatar.raw(size: radius * 2, style: style, child: fallback);
    }
    return FAvatar(
      image: CachedNetworkImageProvider(url!),
      size: radius * 2,
      style: style,
      fallback: fallback,
    );
  }

  Widget _fallback() {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return Icon(FLucideIcons.userRound, size: radius);
    }
    return Text(
      trimmed.characters.first,
      style: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: radius * 0.9,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Color _fallbackColor() {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return const Color(0xFFE5E7EB);
    // String.hashCode differs between Web and VM; the first code unit is stable.
    return _palette[trimmed.codeUnitAt(0) % _palette.length];
  }
}
