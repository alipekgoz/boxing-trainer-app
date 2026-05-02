import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CameraImageConverter {
  CameraImageConverter._();

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  static InputImage? toInputImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final rotation = _rotationFor(
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (rotation == null) {
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.length != 1) {
      return null;
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  static InputImageRotation? _rotationFor({
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final sensorOrientation = camera.sensorOrientation;

    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (Platform.isAndroid) {
      final orientation = _orientations[deviceOrientation];
      if (orientation == null) {
        return null;
      }

      final rotationCompensation =
          camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + orientation) % 360
          : (sensorOrientation - orientation + 360) % 360;

      return InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    return null;
  }
}
