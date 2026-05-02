class PoseResult {
  const PoseResult({required this.detected, required this.landmarkCount});

  const PoseResult.none() : detected = false, landmarkCount = 0;

  final bool detected;
  final int landmarkCount;
}
