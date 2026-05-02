enum PunchCameraFacing { rear, front }

enum PunchHand { left, right }

class PunchDetectionConfig {
  const PunchDetectionConfig({
    this.cameraFacing = PunchCameraFacing.rear,
    this.mirrorMode = false,
    this.jabHand = PunchHand.left,
    this.minLandmarkLikelihood = 0.45,
    this.minForwardDelta = 0.18,
    this.minExtensionFromShoulder = 0.95,
    this.maxVerticalDelta = 0.55,
    this.cooldown = const Duration(milliseconds: 350),
  });

  final PunchCameraFacing cameraFacing;
  final bool mirrorMode;
  final PunchHand jabHand;
  final double minLandmarkLikelihood;
  final double minForwardDelta;
  final double minExtensionFromShoulder;
  final double maxVerticalDelta;
  final Duration cooldown;

  bool get shouldSwapHands =>
      mirrorMode || cameraFacing == PunchCameraFacing.front;
}
