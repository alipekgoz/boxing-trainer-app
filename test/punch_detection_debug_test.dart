import 'package:boxing_trainer_app/pose/pose_landmark.dart';
import 'package:boxing_trainer_app/pose/pose_result.dart';
import 'package:boxing_trainer_app/punch/punch_detection_debug.dart';
import 'package:boxing_trainer_app/punch/punch_detection_service.dart';
import 'package:boxing_trainer_app/punch/punch_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug exposes left hand score and decision for jab', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);
    final punch = detector.detect(
      _leftPunchPose(),
      timestamp: start.add(const Duration(milliseconds: 120)),
    );
    final debug = detector.lastDebug;

    expect(punch, PunchType.jab);
    expect(debug.reason, PunchDetectionDebugReason.leftSelected);
    expect(debug.detectedPunch, PunchType.jab);
    expect(debug.left!.score, greaterThan(debug.right!.score));
    expect(debug.left!.wristReach, greaterThan(debug.left!.elbowReach));
    expect(debug.left!.failedThresholds, isEmpty);
  });

  test('debug exposes right hand score and decision for cross', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);
    final punch = detector.detect(
      _rightPunchPose(),
      timestamp: start.add(const Duration(milliseconds: 120)),
    );
    final debug = detector.lastDebug;

    expect(punch, PunchType.cross);
    expect(debug.reason, PunchDetectionDebugReason.rightSelected);
    expect(debug.detectedPunch, PunchType.cross);
    expect(debug.right!.score, greaterThan(debug.left!.score));
    expect(debug.right!.wristReach, greaterThan(debug.right!.elbowReach));
    expect(debug.right!.failedThresholds, isEmpty);
  });

  test('debug reports failed thresholds for ignored movement', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);
    final punch = detector.detect(
      _guardPose(leftWristX: 94),
      timestamp: start.add(const Duration(milliseconds: 120)),
    );
    final debug = detector.lastDebug;

    expect(punch, PunchType.none);
    expect(debug.reason, PunchDetectionDebugReason.belowThreshold);
    expect(debug.left!.score, 0);
    expect(debug.left!.failedThresholds, isNotEmpty);
  });

  test('debug reports ambiguous two hand movement', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);
    final punch = detector.detect(
      _pose(
        leftElbowX: 30,
        leftElbowY: 100,
        leftWristX: -30,
        rightElbowX: 270,
        rightElbowY: 100,
        rightWristX: 330,
      ),
      timestamp: start.add(const Duration(milliseconds: 120)),
    );
    final debug = detector.lastDebug;

    expect(punch, PunchType.none);
    expect(debug.reason, PunchDetectionDebugReason.ambiguous);
    expect(debug.left!.score, greaterThan(0));
    expect(debug.right!.score, greaterThan(0));
  });

  test('debug reports missing landmarks', () {
    final detector = PunchDetectionService();

    final punch = detector.detect(
      const PoseResult(
        detected: true,
        landmarkCount: 1,
        landmarks: {
          BodyLandmarkType.leftWrist: BodyLandmark(
            x: 0,
            y: 0,
            z: 0,
            likelihood: 1,
          ),
        },
      ),
    );

    expect(punch, PunchType.none);
    expect(
      detector.lastDebug.reason,
      PunchDetectionDebugReason.missingLandmarks,
    );
  });
}

PoseResult _guardPose({double leftWristX = 90, double rightWristX = 210}) {
  return _pose(
    leftElbowX: 92,
    leftElbowY: 126,
    leftWristX: leftWristX,
    rightElbowX: 208,
    rightElbowY: 126,
    rightWristX: rightWristX,
  );
}

PoseResult _leftPunchPose() {
  return _pose(leftElbowX: 30, leftElbowY: 100, leftWristX: -30);
}

PoseResult _rightPunchPose() {
  return _pose(rightElbowX: 270, rightElbowY: 100, rightWristX: 330);
}

PoseResult _pose({
  double leftElbowX = 92,
  double leftElbowY = 126,
  double leftWristX = 90,
  double rightElbowX = 208,
  double rightElbowY = 126,
  double rightWristX = 210,
  double leftWristY = 100,
  double rightWristY = 100,
  double likelihood = 1,
}) {
  return PoseResult(
    detected: true,
    landmarkCount: 6,
    landmarks: {
      BodyLandmarkType.leftShoulder: _landmark(100, 100, likelihood),
      BodyLandmarkType.rightShoulder: _landmark(200, 100, likelihood),
      BodyLandmarkType.leftElbow: _landmark(leftElbowX, leftElbowY, likelihood),
      BodyLandmarkType.rightElbow: _landmark(
        rightElbowX,
        rightElbowY,
        likelihood,
      ),
      BodyLandmarkType.leftWrist: _landmark(leftWristX, leftWristY, likelihood),
      BodyLandmarkType.rightWrist: _landmark(
        rightWristX,
        rightWristY,
        likelihood,
      ),
    },
  );
}

BodyLandmark _landmark(double x, double y, double likelihood) {
  return BodyLandmark(x: x, y: y, z: 0, likelihood: likelihood);
}
