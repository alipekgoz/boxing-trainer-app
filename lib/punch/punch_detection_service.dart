import 'dart:math' as math;

import '../pose/pose_landmark.dart';
import '../pose/pose_result.dart';
import 'punch_detection_config.dart';
import 'punch_type.dart';

class PunchDetectionService {
  PunchDetectionService({this.config = const PunchDetectionConfig()});

  final PunchDetectionConfig config;

  _PunchFrame? _previousFrame;
  DateTime? _lastPunchAt;

  PunchType detect(PoseResult pose, {DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    final frame = _PunchFrame.fromPose(pose, config, now);
    if (frame == null) {
      _previousFrame = null;
      return PunchType.none;
    }

    final previous = _previousFrame;
    _previousFrame = frame;
    if (previous == null ||
        _isCoolingDown(now) ||
        frame.timestamp.difference(previous.timestamp) > config.maxFrameGap) {
      return PunchType.none;
    }

    final leftScore = _scoreHand(
      previous.left,
      frame.left,
      frame.shoulderWidth,
      frame.timestamp.difference(previous.timestamp),
    );
    final rightScore = _scoreHand(
      previous.right,
      frame.right,
      frame.shoulderWidth,
      frame.timestamp.difference(previous.timestamp),
    );

    if (leftScore <= 0 && rightScore <= 0) {
      return PunchType.none;
    }

    final scoreGap = (leftScore - rightScore).abs();
    if (leftScore > 0 &&
        rightScore > 0 &&
        scoreGap < config.ambiguousScoreMargin) {
      return PunchType.none;
    }

    final hand = leftScore >= rightScore ? PunchHand.left : PunchHand.right;
    _lastPunchAt = now;
    return _typeForHand(hand);
  }

  void reset() {
    _previousFrame = null;
    _lastPunchAt = null;
  }

  bool _isCoolingDown(DateTime now) {
    final lastPunchAt = _lastPunchAt;
    return lastPunchAt != null && now.difference(lastPunchAt) < config.cooldown;
  }

  double _scoreHand(
    _ArmFrame previous,
    _ArmFrame current,
    double scale,
    Duration elapsed,
  ) {
    final elapsedSeconds =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (elapsedSeconds <= 0) {
      return 0;
    }

    final extensionDelta = current.wristReach - previous.wristReach;
    final elbowDelta = current.elbowReach - previous.elbowReach;
    final wristVelocity = extensionDelta / elapsedSeconds;
    final straightnessDelta = current.straightness - previous.straightness;
    final verticalDelta = (current.wrist.y - previous.wrist.y).abs() / scale;
    if (extensionDelta < config.minForwardDelta ||
        elbowDelta < config.minElbowForwardDelta ||
        wristVelocity < config.minWristVelocity ||
        current.wristReach < config.minExtensionFromShoulder ||
        current.wristAheadOfElbow < config.minWristAheadOfElbow ||
        current.straightness < config.minArmStraightness ||
        straightnessDelta < config.minArmStraightnessDelta ||
        verticalDelta > config.maxVerticalDelta) {
      return 0;
    }

    final movementScore =
        (extensionDelta * 1.7) +
        (elbowDelta * 0.8) +
        (wristVelocity * 0.16) +
        (straightnessDelta * 0.7) +
        (current.wristAheadOfElbow * 0.35);

    return movementScore >= config.minMovementScore ? movementScore : 0;
  }

  PunchType _typeForHand(PunchHand hand) {
    final jabHand = config.shouldSwapHands
        ? _opposite(config.jabHand)
        : config.jabHand;
    return hand == jabHand ? PunchType.jab : PunchType.cross;
  }

  PunchHand _opposite(PunchHand hand) =>
      hand == PunchHand.left ? PunchHand.right : PunchHand.left;
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
        !_isReliable(leftShoulder, config) ||
        !_isReliable(rightShoulder, config) ||
        !_isReliable(leftElbow, config) ||
        !_isReliable(rightElbow, config) ||
        !_isReliable(leftWrist, config) ||
        !_isReliable(rightWrist, config)) {
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

  static bool _isReliable(BodyLandmark landmark, PunchDetectionConfig config) {
    return landmark.likelihood >= config.minLandmarkLikelihood;
  }
}

class _ArmFrame {
  const _ArmFrame({
    required this.wrist,
    required this.wristReach,
    required this.elbowReach,
    required this.wristAheadOfElbow,
    required this.straightness,
  });

  final BodyLandmark wrist;
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
