import 'dart:math' as math;

import '../pose/pose_landmark.dart';
import '../pose/pose_result.dart';
import 'punch_detection_config.dart';
import 'punch_detection_debug.dart';
import 'punch_type.dart';

class PunchDetectionService {
  PunchDetectionService({this.config = const PunchDetectionConfig()});

  final PunchDetectionConfig config;

  _PunchFrame? _previousFrame;
  DateTime? _lastPunchAt;
  late PunchDetectionDebug _lastDebug = PunchDetectionDebug.initial(config);

  PunchDetectionDebug get lastDebug => _lastDebug;

  PunchType detect(PoseResult pose, {DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    final invalidReason = _invalidPoseReason(pose);
    if (invalidReason != null) {
      _previousFrame = null;
      _lastDebug = PunchDetectionDebug(
        reason: invalidReason,
        detectedPunch: PunchType.none,
        config: config,
      );
      return PunchType.none;
    }

    final frame = _PunchFrame.fromPose(pose, config, now);
    if (frame == null) {
      _previousFrame = null;
      _lastDebug = PunchDetectionDebug(
        reason: PunchDetectionDebugReason.invalidScale,
        detectedPunch: PunchType.none,
        config: config,
      );
      return PunchType.none;
    }

    final previous = _previousFrame;
    _previousFrame = frame;
    if (previous == null) {
      _lastDebug = _debugForFrame(
        frame,
        reason: PunchDetectionDebugReason.waitingForPreviousFrame,
      );
      return PunchType.none;
    }

    final elapsed = frame.timestamp.difference(previous.timestamp);
    if (_isCoolingDown(now)) {
      _lastDebug = _debugForFrame(
        frame,
        previous: previous,
        elapsed: elapsed,
        reason: PunchDetectionDebugReason.cooldown,
      );
      return PunchType.none;
    }

    if (elapsed > config.maxFrameGap) {
      _lastDebug = _debugForFrame(
        frame,
        previous: previous,
        elapsed: elapsed,
        reason: PunchDetectionDebugReason.frameGap,
      );
      return PunchType.none;
    }

    final left = _scoreHand(
      PunchHand.left,
      previous.left,
      frame.left,
      frame.shoulderWidth,
      elapsed,
    );
    final right = _scoreHand(
      PunchHand.right,
      previous.right,
      frame.right,
      frame.shoulderWidth,
      elapsed,
    );
    final leftScore = left.score;
    final rightScore = right.score;
    final scoreGap = (leftScore - rightScore).abs();

    if (leftScore <= 0 && rightScore <= 0) {
      _lastDebug = _debugForScores(
        frame,
        left: left,
        right: right,
        elapsed: elapsed,
        scoreGap: scoreGap,
        reason: PunchDetectionDebugReason.belowThreshold,
      );
      return PunchType.none;
    }

    if (leftScore > 0 &&
        rightScore > 0 &&
        scoreGap < config.ambiguousScoreMargin) {
      _lastDebug = _debugForScores(
        frame,
        left: left,
        right: right,
        elapsed: elapsed,
        scoreGap: scoreGap,
        reason: PunchDetectionDebugReason.ambiguous,
      );
      return PunchType.none;
    }

    final hand = leftScore >= rightScore ? PunchHand.left : PunchHand.right;
    final punch = _typeForHand(hand);
    _lastPunchAt = now;
    _lastDebug = _debugForScores(
      frame,
      left: left,
      right: right,
      elapsed: elapsed,
      scoreGap: scoreGap,
      reason: hand == PunchHand.left
          ? PunchDetectionDebugReason.leftSelected
          : PunchDetectionDebugReason.rightSelected,
      selectedHand: hand,
      detectedPunch: punch,
    );
    return punch;
  }

  void reset() {
    _previousFrame = null;
    _lastPunchAt = null;
    _lastDebug = PunchDetectionDebug.initial(config);
  }

  bool _isCoolingDown(DateTime now) {
    final lastPunchAt = _lastPunchAt;
    return lastPunchAt != null && now.difference(lastPunchAt) < config.cooldown;
  }

  PunchHandDebug _scoreHand(
    PunchHand hand,
    _ArmFrame previous,
    _ArmFrame current,
    double scale,
    Duration elapsed,
  ) {
    final elapsedSeconds =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (elapsedSeconds <= 0) {
      return _handDebug(
        hand: hand,
        current: current,
        score: 0,
        rawMovementScore: 0,
        extensionDelta: 0,
        elbowDelta: 0,
        wristVelocity: 0,
        straightnessDelta: 0,
        verticalDelta: 0,
        failedThresholds: const ['elapsed'],
      );
    }

    final extensionDelta = current.wristReach - previous.wristReach;
    final elbowDelta = current.elbowReach - previous.elbowReach;
    final wristVelocity = extensionDelta / elapsedSeconds;
    final straightnessDelta = current.straightness - previous.straightness;
    final verticalDelta = (current.wrist.y - previous.wrist.y).abs() / scale;
    final movementScore =
        (extensionDelta * 1.7) +
        (elbowDelta * 0.8) +
        (wristVelocity * 0.16) +
        (straightnessDelta * 0.7) +
        (current.wristAheadOfElbow * 0.35);
    final failedThresholds = <String>[
      if (extensionDelta < config.minForwardDelta) 'minForwardDelta',
      if (elbowDelta < config.minElbowForwardDelta) 'minElbowForwardDelta',
      if (wristVelocity < config.minWristVelocity) 'minWristVelocity',
      if (current.wristReach < config.minExtensionFromShoulder)
        'minExtensionFromShoulder',
      if (current.wristAheadOfElbow < config.minWristAheadOfElbow)
        'minWristAheadOfElbow',
      if (current.straightness < config.minArmStraightness)
        'minArmStraightness',
      if (straightnessDelta < config.minArmStraightnessDelta)
        'minArmStraightnessDelta',
      if (verticalDelta > config.maxVerticalDelta) 'maxVerticalDelta',
      if (movementScore < config.minMovementScore) 'minMovementScore',
    ];

    return _handDebug(
      hand: hand,
      current: current,
      score: failedThresholds.isEmpty ? movementScore : 0,
      rawMovementScore: movementScore,
      extensionDelta: extensionDelta,
      elbowDelta: elbowDelta,
      wristVelocity: wristVelocity,
      straightnessDelta: straightnessDelta,
      verticalDelta: verticalDelta,
      failedThresholds: List.unmodifiable(failedThresholds),
    );
  }

  PunchType _typeForHand(PunchHand hand) {
    final jabHand = config.shouldSwapHands
        ? _opposite(config.jabHand)
        : config.jabHand;
    return hand == jabHand ? PunchType.jab : PunchType.cross;
  }

  PunchHand _opposite(PunchHand hand) =>
      hand == PunchHand.left ? PunchHand.right : PunchHand.left;

  PunchDetectionDebugReason? _invalidPoseReason(PoseResult pose) {
    if (!pose.detected) {
      return PunchDetectionDebugReason.noPose;
    }

    final leftShoulder = pose.landmarks[BodyLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[BodyLandmarkType.rightShoulder];
    final leftElbow = pose.landmarks[BodyLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[BodyLandmarkType.rightElbow];
    final leftWrist = pose.landmarks[BodyLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[BodyLandmarkType.rightWrist];
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        !_PunchFrame.isReliable(leftShoulder, config) ||
        !_PunchFrame.isReliable(rightShoulder, config) ||
        !_PunchFrame.isReliable(leftElbow, config) ||
        !_PunchFrame.isReliable(rightElbow, config) ||
        !_PunchFrame.isReliable(leftWrist, config) ||
        !_PunchFrame.isReliable(rightWrist, config)) {
      return PunchDetectionDebugReason.missingLandmarks;
    }

    return null;
  }

  PunchDetectionDebug _debugForFrame(
    _PunchFrame frame, {
    required PunchDetectionDebugReason reason,
    _PunchFrame? previous,
    Duration? elapsed,
  }) {
    final left = previous == null || elapsed == null
        ? null
        : _scoreHand(
            PunchHand.left,
            previous.left,
            frame.left,
            frame.shoulderWidth,
            elapsed,
          );
    final right = previous == null || elapsed == null
        ? null
        : _scoreHand(
            PunchHand.right,
            previous.right,
            frame.right,
            frame.shoulderWidth,
            elapsed,
          );

    return _debugForScores(
      frame,
      left: left,
      right: right,
      elapsed: elapsed,
      scoreGap: left == null || right == null
          ? null
          : (left.score - right.score).abs(),
      reason: reason,
    );
  }

  PunchDetectionDebug _debugForScores(
    _PunchFrame frame, {
    required PunchHandDebug? left,
    required PunchHandDebug? right,
    required Duration? elapsed,
    required double? scoreGap,
    required PunchDetectionDebugReason reason,
    PunchHand? selectedHand,
    PunchType detectedPunch = PunchType.none,
  }) {
    return PunchDetectionDebug(
      reason: reason,
      detectedPunch: detectedPunch,
      config: config,
      left: left,
      right: right,
      selectedHand: selectedHand,
      elapsed: elapsed,
      shoulderWidth: frame.shoulderWidth,
      scoreGap: scoreGap,
    );
  }

  PunchHandDebug _handDebug({
    required PunchHand hand,
    required _ArmFrame current,
    required double score,
    required double rawMovementScore,
    required double extensionDelta,
    required double elbowDelta,
    required double wristVelocity,
    required double straightnessDelta,
    required double verticalDelta,
    required List<String> failedThresholds,
  }) {
    return PunchHandDebug(
      hand: hand,
      score: score,
      rawMovementScore: rawMovementScore,
      wristReach: current.wristReach,
      elbowReach: current.elbowReach,
      wristAheadOfElbow: current.wristAheadOfElbow,
      straightness: current.straightness,
      extensionDelta: extensionDelta,
      elbowDelta: elbowDelta,
      wristVelocity: wristVelocity,
      straightnessDelta: straightnessDelta,
      verticalDelta: verticalDelta,
      shoulder: _pointDebug(current.shoulder),
      elbow: _pointDebug(current.elbow),
      wrist: _pointDebug(current.wrist),
      failedThresholds: failedThresholds,
    );
  }

  PunchPointDebug _pointDebug(BodyLandmark landmark) {
    return PunchPointDebug(
      x: landmark.x,
      y: landmark.y,
      z: landmark.z,
      likelihood: landmark.likelihood,
    );
  }
}

class _PunchFrame {
  const _PunchFrame({
    required this.left,
    required this.right,
    required this.shoulderWidth,
    required this.timestamp,
  });

  final _ArmFrame left;
  final _ArmFrame right;
  final double shoulderWidth;
  final DateTime timestamp;

  static _PunchFrame? fromPose(
    PoseResult pose,
    PunchDetectionConfig config,
    DateTime timestamp,
  ) {
    if (!pose.detected) {
      return null;
    }

    final leftShoulder = pose.landmarks[BodyLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[BodyLandmarkType.rightShoulder];
    final leftElbow = pose.landmarks[BodyLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[BodyLandmarkType.rightElbow];
    final leftWrist = pose.landmarks[BodyLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[BodyLandmarkType.rightWrist];
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        !isReliable(leftShoulder, config) ||
        !isReliable(rightShoulder, config) ||
        !isReliable(leftElbow, config) ||
        !isReliable(rightElbow, config) ||
        !isReliable(leftWrist, config) ||
        !isReliable(rightWrist, config)) {
      return null;
    }

    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    if (shoulderWidth <= 0) {
      return null;
    }

    return _PunchFrame(
      left: _ArmFrame.fromLandmarks(
        shoulder: leftShoulder,
        elbow: leftElbow,
        wrist: leftWrist,
        shoulderWidth: shoulderWidth,
        sideDirection: leftShoulder.x <= rightShoulder.x ? -1 : 1,
      ),
      right: _ArmFrame.fromLandmarks(
        shoulder: rightShoulder,
        elbow: rightElbow,
        wrist: rightWrist,
        shoulderWidth: shoulderWidth,
        sideDirection: rightShoulder.x >= leftShoulder.x ? 1 : -1,
      ),
      shoulderWidth: shoulderWidth,
      timestamp: timestamp,
    );
  }

  static bool isReliable(BodyLandmark landmark, PunchDetectionConfig config) {
    return landmark.likelihood >= config.minLandmarkLikelihood;
  }
}

class _ArmFrame {
  const _ArmFrame({
    required this.wrist,
    required this.elbow,
    required this.shoulder,
    required this.wristReach,
    required this.elbowReach,
    required this.wristAheadOfElbow,
    required this.straightness,
  });

  final BodyLandmark wrist;
  final BodyLandmark elbow;
  final BodyLandmark shoulder;
  final double wristReach;
  final double elbowReach;
  final double wristAheadOfElbow;
  final double straightness;

  factory _ArmFrame.fromLandmarks({
    required BodyLandmark shoulder,
    required BodyLandmark elbow,
    required BodyLandmark wrist,
    required double shoulderWidth,
    required int sideDirection,
  }) {
    final wristReach = _forwardReach(
      point: wrist,
      origin: shoulder,
      shoulderWidth: shoulderWidth,
      sideDirection: sideDirection,
    );
    final elbowReach = _forwardReach(
      point: elbow,
      origin: shoulder,
      shoulderWidth: shoulderWidth,
      sideDirection: sideDirection,
    );

    return _ArmFrame(
      wrist: wrist,
      elbow: elbow,
      shoulder: shoulder,
      wristReach: wristReach,
      elbowReach: elbowReach,
      wristAheadOfElbow: wristReach - elbowReach,
      straightness: _armStraightness(shoulder, elbow, wrist),
    );
  }
}

double _forwardReach({
  required BodyLandmark point,
  required BodyLandmark origin,
  required double shoulderWidth,
  required int sideDirection,
}) {
  final lateralReach = ((point.x - origin.x) * sideDirection) / shoulderWidth;
  final depthReach = (origin.z - point.z) / shoulderWidth;
  return lateralReach + (depthReach * 0.45);
}

double _armStraightness(
  BodyLandmark shoulder,
  BodyLandmark elbow,
  BodyLandmark wrist,
) {
  final upperArmX = shoulder.x - elbow.x;
  final upperArmY = shoulder.y - elbow.y;
  final forearmX = wrist.x - elbow.x;
  final forearmY = wrist.y - elbow.y;
  final upperLength = math.sqrt(
    (upperArmX * upperArmX) + (upperArmY * upperArmY),
  );
  final forearmLength = math.sqrt(
    (forearmX * forearmX) + (forearmY * forearmY),
  );
  if (upperLength <= 0 || forearmLength <= 0) {
    return 0;
  }

  final dot = (upperArmX * forearmX) + (upperArmY * forearmY);
  final cosine = (dot / (upperLength * forearmLength)).clamp(-1.0, 1.0);
  return (1 - cosine) / 2;
}
