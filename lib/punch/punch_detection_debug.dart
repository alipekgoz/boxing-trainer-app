import 'punch_detection_config.dart';
import 'punch_type.dart';

enum PunchDetectionDebugReason {
  waitingForPreviousFrame,
  noPose,
  missingLandmarks,
  invalidScale,
  cooldown,
  frameGap,
  belowThreshold,
  ambiguous,
  leftSelected,
  rightSelected;

  String get label => switch (this) {
    PunchDetectionDebugReason.waitingForPreviousFrame => 'waitingPreviousFrame',
    PunchDetectionDebugReason.noPose => 'noPose',
    PunchDetectionDebugReason.missingLandmarks => 'missingLandmarks',
    PunchDetectionDebugReason.invalidScale => 'invalidScale',
    PunchDetectionDebugReason.cooldown => 'cooldown',
    PunchDetectionDebugReason.frameGap => 'frameGap',
    PunchDetectionDebugReason.belowThreshold => 'belowThreshold',
    PunchDetectionDebugReason.ambiguous => 'ambiguous',
    PunchDetectionDebugReason.leftSelected => 'leftSelected',
    PunchDetectionDebugReason.rightSelected => 'rightSelected',
  };
}

class PunchDetectionDebug {
  const PunchDetectionDebug({
    required this.reason,
    required this.detectedPunch,
    required this.config,
    this.left,
    this.right,
    this.selectedHand,
    this.elapsed,
    this.shoulderWidth,
    this.scoreGap,
  });

  factory PunchDetectionDebug.initial(PunchDetectionConfig config) {
    return PunchDetectionDebug(
      reason: PunchDetectionDebugReason.waitingForPreviousFrame,
      detectedPunch: PunchType.none,
      config: config,
    );
  }

  final PunchDetectionDebugReason reason;
  final PunchType detectedPunch;
  final PunchDetectionConfig config;
  final PunchHandDebug? left;
  final PunchHandDebug? right;
  final PunchHand? selectedHand;
  final Duration? elapsed;
  final double? shoulderWidth;
  final double? scoreGap;
}

class PunchHandDebug {
  const PunchHandDebug({
    required this.hand,
    required this.score,
    required this.rawMovementScore,
    required this.wristReach,
    required this.elbowReach,
    required this.wristAheadOfElbow,
    required this.straightness,
    required this.extensionDelta,
    required this.elbowDelta,
    required this.wristVelocity,
    required this.straightnessDelta,
    required this.verticalDelta,
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.failedThresholds,
  });

  final PunchHand hand;
  final double score;
  final double rawMovementScore;
  final double wristReach;
  final double elbowReach;
  final double wristAheadOfElbow;
  final double straightness;
  final double extensionDelta;
  final double elbowDelta;
  final double wristVelocity;
  final double straightnessDelta;
  final double verticalDelta;
  final PunchPointDebug shoulder;
  final PunchPointDebug elbow;
  final PunchPointDebug wrist;
  final List<String> failedThresholds;

  bool get passedThresholds => failedThresholds.isEmpty;
}

class PunchPointDebug {
  const PunchPointDebug({
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
