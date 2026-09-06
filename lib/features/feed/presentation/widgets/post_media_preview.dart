import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import '../../../../core/theme/app_theme.dart';

class PostMediaPreview extends StatelessWidget {
  final List<String> images;
  const PostMediaPreview({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    final count = images.length;
    Widget image(int index) => ClipRRect(
      borderRadius: AppTheme.imageRadius,
      child: CachedNetworkImage(
        imageUrl: images[index],
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, _) =>
            ColoredBox(color: context.theme.colors.secondary),
        errorWidget: (_, _, _) => ColoredBox(
          color: context.theme.colors.secondary,
          child: Icon(
            FLucideIcons.image,
            color: context.theme.colors.mutedForeground,
          ),
        ),
      ),
    );
    final preview = count == 1
        ? Align(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: FractionallySizedBox(
              widthFactor: 0.72,
              child: AspectRatio(aspectRatio: 1.45, child: image(0)),
            ),
          )
        : AspectRatio(
            aspectRatio: count > 3 ? 2.5 : 3.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (count > 3) ...[
                  Expanded(flex: 2, child: image(0)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: image(1)),
                        const SizedBox(height: 4),
                        Expanded(child: image(2)),
                      ],
                    ),
                  ),
                ] else ...[
                  for (var i = 0; i < 3; i++) ...[
                    if (i != 0) const SizedBox(width: 4),
                    Expanded(
                      child: i < count ? image(i) : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ],
            ),
          );
    return Semantics(
      label: '$count 张图片',
      child: Stack(
        children: [
          preview,
          if (count > 3)
            Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0x99000000)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    '共$count张',
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
