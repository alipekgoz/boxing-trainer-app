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
    final frame = _PunchFrame.fromPose(pose, config);
    if (frame == null) {
      _previousFrame = null;
      return PunchType.none;
    }

    final previous = _previousFrame;
    _previousFrame = frame;
    if (previous == null || _isCoolingDown(now)) {
      return PunchType.none;
    }

    final leftScore = _scoreHand(
      previous.left,
      frame.left,
      frame.shoulderWidth,
    );
    final rightScore = _scoreHand(
      previous.right,
      frame.right,
      frame.shoulderWidth,
    );

    if (leftScore <= 0 && rightScore <= 0) {
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

  double _scoreHand(_HandFrame previous, _HandFrame current, double scale) {
    final extensionDelta = current.extension - previous.extension;
    final verticalDelta = (current.wrist.y - previous.wrist.y).abs() / scale;
    if (extensionDelta < config.minForwardDelta ||
        current.extension < config.minExtensionFromShoulder ||
        verticalDelta > config.maxVerticalDelta) {
      return 0;
    }

    return extensionDelta;
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
  });

  final _HandFrame left;
  final _HandFrame right;
  final double shoulderWidth;

  static _PunchFrame? fromPose(PoseResult pose, PunchDetectionConfig config) {
    if (!pose.detected) {
      return null;
    }

    final leftShoulder = pose.landmarks[BodyLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[BodyLandmarkType.rightShoulder];
    final leftWrist = pose.landmarks[BodyLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[BodyLandmarkType.rightWrist];
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftWrist == null ||
        rightWrist == null ||
        !_isReliable(leftShoulder, config) ||
        !_isReliable(rightShoulder, config) ||
        !_isReliable(leftWrist, config) ||
        !_isReliable(rightWrist, config)) {
      return null;
    }

    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    if (shoulderWidth <= 0) {
      return null;
    }

    return _PunchFrame(
      left: _HandFrame.fromLandmarks(leftWrist, leftShoulder, shoulderWidth),
      right: _HandFrame.fromLandmarks(rightWrist, rightShoulder, shoulderWidth),
      shoulderWidth: shoulderWidth,
    );
  }

  static bool _isReliable(BodyLandmark landmark, PunchDetectionConfig config) {
    return landmark.likelihood >= config.minLandmarkLikelihood;
  }
}

class _HandFrame {
  const _HandFrame({required this.wrist, required this.extension});

  final BodyLandmark wrist;
  final double extension;

  factory _HandFrame.fromLandmarks(
    BodyLandmark wrist,
    BodyLandmark shoulder,
    double shoulderWidth,
  ) {
    final dx = wrist.x - shoulder.x;
    final dy = wrist.y - shoulder.y;
    final planarDistance = math.sqrt((dx * dx) + (dy * dy)) / shoulderWidth;
    final depthReach = (shoulder.z - wrist.z) / shoulderWidth;

    return _HandFrame(wrist: wrist, extension: planarDistance + depthReach);
  }
}
