import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImagePickerGrid extends StatelessWidget {
  final List<String> networkImages;
  final List<XFile> localImages;
  final ValueChanged<XFile> onAdd;
  final ValueChanged<int> onRemoveNetwork;
  final ValueChanged<int> onRemoveLocal;
  final int maxCount;

  const ImagePickerGrid({
    super.key,
    this.networkImages = const [],
    this.localImages = const [],
    required this.onAdd,
    required this.onRemoveNetwork,
    required this.onRemoveLocal,
    this.maxCount = 9,
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
                  return const Center(child: CircularProgressIndicator());
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

  Widget _imageItem(BuildContext context,
      {required Widget child, required VoidCallback onRemove}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final xFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (xFile != null) {
          onAdd(xFile);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.add_photo_alternate_outlined,
            size: 32, color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
