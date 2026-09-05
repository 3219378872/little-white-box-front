import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xiaobaihe_app/features/post/presentation/widgets/image_picker_grid.dart';

import '../../../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('ignores a selected image after the grid is disposed', (
    tester,
  ) async {
    final picker = _DelayedImagePicker();
    var additions = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: ImagePickerGrid(
            imagePicker: picker,
            onAdd: (_) => additions++,
            onRemoveNetwork: (_) {},
            onRemoveLocal: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('添加图片'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox.shrink());
    picker.result.complete(
      XFile.fromData(Uint8List.fromList([1]), name: 'late.png'),
    );
    await tester.pump();

    expect(additions, 0);
    expect(tester.takeException(), isNull);
  });
}

class _DelayedImagePicker extends ImagePicker {
  final result = Completer<XFile?>();

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    return result.future;
  }
}
