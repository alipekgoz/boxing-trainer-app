import 'pose_landmark.dart';

class PoseResult {
  const PoseResult({
    required this.detected,
    required this.landmarkCount,
    this.landmarks = const {},
  });

  const PoseResult.none()
    : detected = false,
      landmarkCount = 0,
      landmarks = const {};

  final bool detected;
  final int landmarkCount;
  final Map<BodyLandmarkType, BodyLandmark> landmarks;
}
