enum PunchCameraFacing { rear, front }

enum PunchHand { left, right }

class PunchDetectionConfig {
  const PunchDetectionConfig({
    this.cameraFacing = PunchCameraFacing.front,
    this.mirrorMode = true,
    this.jabHand = PunchHand.left,
    this.minLandmarkLikelihood = 0.45,
    this.minForwardDelta = 0.18,
    this.minElbowForwardDelta = 0.04,
    this.minWristVelocity = 1.1,
    this.minExtensionFromShoulder = 0.75,
    this.minWristAheadOfElbow = 0.12,
    this.minArmStraightness = 0.62,
    this.minArmStraightnessDelta = 0.02,
    this.maxVerticalDelta = 0.55,
    this.minMovementScore = 0.45,
    this.ambiguousScoreMargin = 0.12,
    this.maxFrameGap = const Duration(milliseconds: 600),
    this.cooldown = const Duration(milliseconds: 420),
  });

  final PunchCameraFacing cameraFacing;
  final bool mirrorMode;
  final PunchHand jabHand;
  final double minLandmarkLikelihood;
  final double minForwardDelta;
  final double minElbowForwardDelta;
  final double minWristVelocity;
  final double minExtensionFromShoulder;
  final double minWristAheadOfElbow;
  final double minArmStraightness;
  final double minArmStraightnessDelta;
  final double maxVerticalDelta;
  final double minMovementScore;
  final double ambiguousScoreMargin;
  final Duration maxFrameGap;
  final Duration cooldown;

  bool get shouldSwapHands =>
      mirrorMode != (cameraFacing == PunchCameraFacing.front);
}
