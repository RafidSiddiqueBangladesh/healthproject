import 'dart:ui';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

InputImage? buildInputImage(CameraController? controller, CameraImage image) {
  if (controller == null) {
    return null;
  }

  final bool isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final bytes = isAndroid ? _androidNv21Bytes(image) : image.planes.first.bytes;

  final metadata = InputImageMetadata(
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: InputImageRotationValue.fromRawValue(controller.description.sensorOrientation) ??
        InputImageRotation.rotation0deg,
    format: isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
    bytesPerRow: isAndroid ? image.width : image.planes.first.bytesPerRow,
  );

  return InputImage.fromBytes(bytes: bytes, metadata: metadata);
}

Uint8List _androidNv21Bytes(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final expectedLength = width * height * 3 ~/ 2;

  // Some devices already provide a single NV21-like plane.
  if (image.planes.length == 1) {
    final raw = image.planes.first.bytes;
    if (raw.length == expectedLength) {
      return raw;
    }
  }

  if (image.planes.length < 3) {
    return image.planes.first.bytes;
  }

  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final out = Uint8List(expectedLength);
  var outIndex = 0;

  // Copy Y plane with row-stride handling.
  for (var row = 0; row < height; row++) {
    final rowStart = row * yPlane.bytesPerRow;
    out.setRange(outIndex, outIndex + width, yPlane.bytes, rowStart);
    outIndex += width;
  }

  // Interleave V and U to build NV21 chroma plane.
  final uvHeight = height ~/ 2;
  final uvWidth = width ~/ 2;
  final vPixelStride = vPlane.bytesPerPixel ?? 1;
  final uPixelStride = uPlane.bytesPerPixel ?? 1;

  for (var row = 0; row < uvHeight; row++) {
    final vRow = row * vPlane.bytesPerRow;
    final uRow = row * uPlane.bytesPerRow;
    for (var col = 0; col < uvWidth; col++) {
      out[outIndex++] = vPlane.bytes[vRow + col * vPixelStride];
      out[outIndex++] = uPlane.bytes[uRow + col * uPixelStride];
    }
  }

  return out;
}
