import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImagePickerGrid extends StatelessWidget {
  final List<String> networkImages;
  final List<XFile> localImages;
  final ValueChanged<XFile> onAdd;
  final ValueChanged<int> onRemoveNetwork;
  final ValueChanged<int> onRemoveLocal;
  final int maxCount;
  final ImagePicker? imagePicker;

  const ImagePickerGrid({
    super.key,
    this.networkImages = const [],
    this.localImages = const [],
    required this.onAdd,
    required this.onRemoveNetwork,
    required this.onRemoveLocal,
    this.maxCount = 9,
    this.imagePicker,
  });

  int get _totalCount => networkImages.length + localImages.length;

  @override
  Widget build(BuildContext context) {
    final showAddButton = _totalCount < maxCount;
    final itemCount = _totalCount + (showAddButton ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < networkImages.length) {
          return _imageItem(
            context,
            child: CachedNetworkImage(
              imageUrl: networkImages[index],
              fit: BoxFit.cover,
            ),
            onRemove: () => onRemoveNetwork(index),
          );
        }
        final localIndex = index - networkImages.length;
        if (localIndex < localImages.length) {
          return _imageItem(
            context,
            child: FutureBuilder<Uint8List>(
              future: localImages[localIndex].readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: FCircularProgress());
                }
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                );
              },
            ),
            onRemove: () => onRemoveLocal(localIndex),
          );
        }
        // 添加按钮
        return _addButton(context);
      },
    );
  }

  Widget _imageItem(
    BuildContext context, {
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return ClipRRect(
      borderRadius: context.theme.style.borderRadius.md,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            top: 4,
            right: 4,
            child: FTappable(
              onPress: onRemove,
              semanticsLabel: '移除图片',
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0x8A000000),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: const Icon(
                  FLucideIcons.x,
                  size: 16,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return FTappable(
      semanticsLabel: '添加图片',
      onPress: () async {
        final xFile = await (imagePicker ?? ImagePicker()).pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (!context.mounted || xFile == null) return;
        onAdd(xFile);
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.colors.muted,
          borderRadius: context.theme.style.borderRadius.md,
        ),
        child: Icon(
          FLucideIcons.imagePlus,
          size: 32,
          color: context.theme.colors.mutedForeground,
        ),
      ),
    );
  }
}
