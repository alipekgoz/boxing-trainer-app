import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'camera_image_converter.dart';
import 'pose_result.dart';

class PoseDetectionService {
  PoseDetectionService({this.frameInterval = const Duration(milliseconds: 120)})
    : _poseDetector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
      );

  final Duration frameInterval;
  final PoseDetector _poseDetector;

  bool _isProcessing = false;
  DateTime? _lastProcessedAt;

  Future<PoseResult?> detectFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    if (_shouldSkipFrame()) {
      return null;
    }

    final inputImage = CameraImageConverter.toInputImage(
      image: image,
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (inputImage == null) {
      return null;
    }

    _isProcessing = true;
    _lastProcessedAt = DateTime.now();

    try {
      final poses = await _poseDetector.processImage(inputImage);
      final landmarkCount = poses.fold<int>(
        0,
        (count, pose) => count + pose.landmarks.length,
      );

      return PoseResult(
        detected: poses.isNotEmpty,
        landmarkCount: landmarkCount,
      );
    } catch (_) {
      return const PoseResult.none();
    } finally {
      _isProcessing = false;
    }
  }

  bool _shouldSkipFrame() {
    if (_isProcessing) {
      return true;
    }

    final lastProcessedAt = _lastProcessedAt;
    if (lastProcessedAt == null) {
      return false;
    }

    return DateTime.now().difference(lastProcessedAt) < frameInterval;
  }

  Future<void> dispose() => _poseDetector.close();
}
