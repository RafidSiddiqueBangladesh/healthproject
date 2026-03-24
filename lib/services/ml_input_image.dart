import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

InputImage? buildInputImage(CameraController? controller, CameraImage image) {
  if (controller == null) {
    return null;
  }

  final bytesBuilder = WriteBuffer();
  for (final plane in image.planes) {
    bytesBuilder.putUint8List(plane.bytes);
  }
  final bytes = bytesBuilder.done().buffer.asUint8List();

  final metadata = InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: InputImageRotationValue.fromRawValue(controller.description.sensorOrientation) ??
        InputImageRotation.rotation0deg,
    format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
    bytesPerRow: image.planes.first.bytesPerRow,
  );

  return InputImage.fromBytes(bytes: bytes, metadata: metadata);
}
