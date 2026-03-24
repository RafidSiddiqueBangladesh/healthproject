import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FullCameraPreview extends StatelessWidget {
  const FullCameraPreview({
    super.key,
    required this.controller,
  });

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
