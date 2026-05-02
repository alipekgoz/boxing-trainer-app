enum BodyLandmarkType { leftShoulder, rightShoulder, leftWrist, rightWrist }

class BodyLandmark {
  const BodyLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  final double x;
  final double y;
  final double z;
  final double likelihood;
}
