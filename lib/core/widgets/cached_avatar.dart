import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
    if (url == null || url!.isEmpty) {
      return _fallback();
    }
    return CachedNetworkImage(
      imageUrl: url!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: radius,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (context, url, error) => _fallback(),
    );
  }

  Widget _fallback() {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: Icon(Icons.person, size: radius),
      );
    }
    // 按首字符码位取色：String.hashCode 在 Web 与 VM 上结果不同，码位更稳定
    final color = _palette[trimmed.codeUnitAt(0) % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        trimmed.characters.first,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
