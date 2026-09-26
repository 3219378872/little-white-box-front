import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/app_theme.dart';

/// Feed image preview with fixed geometry per image count, so loading and
/// failure states never shift the list:
/// - 1 image: full width, 16:9, at most [maxSingleHeight] tall.
/// - 2 images: two equal 4:3 tiles filling the row.
/// - 3+ images: three equal square tiles; the third shows `+N` for the rest.
class PostMediaPreview extends StatelessWidget {
  final List<String> images;
  const PostMediaPreview({super.key, required this.images});

  static const gap = 4.0;
  static const maxSingleHeight = 360.0;
  static const maxTiles = 3;

  /// Height for [count] images laid out in [width]; exposed for tests.
  static double heightFor(int count, double width) {
    if (count <= 0) return 0;
    if (count == 1) {
      final height = width * 9 / 16;
      return height > maxSingleHeight ? maxSingleHeight : height;
    }
    if (count == 2) return (width - gap) / 2 * 3 / 4;
    return (width - gap * 2) / 3;
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    final count = images.length;
    final colors = context.theme.colors;
    Widget image(int index) => ClipRRect(
      borderRadius: AppTheme.imageRadius,
      child: CachedNetworkImage(
        imageUrl: images[index],
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, _) => ColoredBox(color: colors.secondary),
        errorWidget: (_, _, _) => ColoredBox(
          color: colors.secondary,
          child: Icon(FLucideIcons.image, color: colors.mutedForeground),
        ),
      ),
    );

    return Semantics(
      label: '$count 张图片',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = heightFor(count, width);
          if (count == 1) {
            return SizedBox(width: width, height: height, child: image(0));
          }
          final tiles = count == 2 ? 2 : maxTiles;
          final extra = count - maxTiles;
          return SizedBox(
            width: width,
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [
                for (var i = 0; i < tiles; i++)
                  Expanded(
                    child: i == tiles - 1 && extra > 0
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              image(i),
                              ClipRRect(
                                borderRadius: AppTheme.imageRadius,
                                child: ColoredBox(
                                  color: const Color(0x80000000),
                                  child: Center(
                                    child: Text(
                                      '+$extra',
                                      style: context.theme.typography.body.xl
                                          .copyWith(
                                            color: const Color(0xFFFFFFFF),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : image(i),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
