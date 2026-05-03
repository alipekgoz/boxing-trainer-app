import 'package:boxing_trainer_app/pose/pose_landmark.dart';
import 'package:boxing_trainer_app/pose/pose_result.dart';
import 'package:boxing_trainer_app/punch/punch_detection_config.dart';
import 'package:boxing_trainer_app/punch/punch_detection_service.dart';
import 'package:boxing_trainer_app/punch/punch_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects jab from left hand extension', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    expect(detector.detect(_guardPose(), timestamp: start), PunchType.none);
    expect(
      detector.detect(
        _leftPunchPose(),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.jab,
    );
  });

  test('detects cross from right hand extension', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    expect(detector.detect(_guardPose(), timestamp: start), PunchType.none);
    expect(
      detector.detect(
        _rightPunchPose(),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.cross,
    );
  });

  test('detects a moderate jab extension', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);

    expect(
      detector.detect(
        _leftModeratePunchPose(),
        timestamp: start.add(const Duration(milliseconds: 140)),
      ),
      PunchType.jab,
    );
  });

  test('detects a moderate cross extension', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);

    expect(
      detector.detect(
        _rightModeratePunchPose(),
        timestamp: start.add(const Duration(milliseconds: 140)),
      ),
      PunchType.cross,
    );
  });

  test('returns none for small movements', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);

    expect(
      detector.detect(
        _guardPose(leftWristX: 94),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.none,
    );
  });

  test('returns none when required landmarks are missing', () {
    final detector = PunchDetectionService();

    expect(
      detector.detect(
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
      ),
      PunchType.none,
    );
  });

  test('cooldown prevents immediate repeated detections', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_pose(leftWristX: 90), timestamp: start);
    expect(
      detector.detect(
        _leftPunchPose(),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.jab,
    );
    expect(
      detector.detect(
        _rightPunchPose(),
        timestamp: start.add(const Duration(milliseconds: 220)),
      ),
      PunchType.none,
    );
  });

  test('front camera with mirror keeps jab and cross hand mapping', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);

    expect(
      detector.detect(
        _leftPunchPose(),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.jab,
    );
  });

  test('rear camera with mirror swaps jab and cross hand mapping', () {
    final detector = PunchDetectionService(
      config: const PunchDetectionConfig(
        cameraFacing: PunchCameraFacing.rear,
        mirrorMode: true,
      ),
    );
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);

    expect(
      detector.detect(
        _leftPunchPose(),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.cross,
    );
  });

  test('returns none when wrist moves without elbow extension', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);

    expect(
      detector.detect(
        _guardPose(leftWristX: -30),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.none,
    );
  });

  test('returns none for slow extension', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);

    expect(
      detector.detect(
        _leftPunchPose(),
        timestamp: start.add(const Duration(milliseconds: 700)),
      ),
      PunchType.none,
    );
  });

  test('returns none for low landmark likelihood', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);

    expect(
      detector.detect(
        _leftPunchPose(likelihood: 0.4),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.none,
    );
  });

  test('returns none for ambiguous two-hand movement', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_guardPose(), timestamp: start);

    expect(
      detector.detect(
        _pose(
          leftElbowX: 30,
          leftElbowY: 100,
          leftWristX: -30,
          rightElbowX: 270,
          rightElbowY: 100,
          rightWristX: 330,
        ),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.none,
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

PoseResult _leftPunchPose({double likelihood = 1}) {
  return _pose(
    leftElbowX: 30,
    leftElbowY: 100,
    leftWristX: -30,
    likelihood: likelihood,
  );
}

PoseResult _rightPunchPose() {
  return _pose(rightElbowX: 270, rightElbowY: 100, rightWristX: 330);
}

PoseResult _leftModeratePunchPose() {
  return _pose(leftElbowX: 55, leftElbowY: 100, leftWristX: 15);
}

PoseResult _rightModeratePunchPose() {
  return _pose(rightElbowX: 245, rightElbowY: 100, rightWristX: 285);
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
