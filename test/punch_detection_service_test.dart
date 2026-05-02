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

    expect(
      detector.detect(_pose(leftWristX: 90), timestamp: start),
      PunchType.none,
    );
    expect(
      detector.detect(
        _pose(leftWristX: -30),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.jab,
    );
  });

  test('detects cross from right hand extension', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    expect(
      detector.detect(_pose(rightWristX: 210), timestamp: start),
      PunchType.none,
    );
    expect(
      detector.detect(
        _pose(rightWristX: 330),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.cross,
    );
  });

  test('returns none for small movements', () {
    final detector = PunchDetectionService();
    final start = DateTime(2026);

    detector.detect(_pose(leftWristX: 90), timestamp: start);

    expect(
      detector.detect(
        _pose(leftWristX: 96),
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
        _pose(leftWristX: -30),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.jab,
    );
    expect(
      detector.detect(
        _pose(rightWristX: 340),
        timestamp: start.add(const Duration(milliseconds: 220)),
      ),
      PunchType.none,
    );
  });

  test('mirror mode swaps jab and cross hand mapping', () {
    final detector = PunchDetectionService(
      config: const PunchDetectionConfig(mirrorMode: true),
    );
    final start = DateTime(2026);

    detector.detect(_pose(leftWristX: 90), timestamp: start);

    expect(
      detector.detect(
        _pose(leftWristX: -30),
        timestamp: start.add(const Duration(milliseconds: 120)),
      ),
      PunchType.cross,
    );
  });
}

PoseResult _pose({
  double leftWristX = 90,
  double rightWristX = 210,
  double leftWristY = 100,
  double rightWristY = 100,
}) {
  return PoseResult(
    detected: true,
    landmarkCount: 4,
    landmarks: {
      BodyLandmarkType.leftShoulder: _landmark(100, 100),
      BodyLandmarkType.rightShoulder: _landmark(200, 100),
      BodyLandmarkType.leftWrist: _landmark(leftWristX, leftWristY),
      BodyLandmarkType.rightWrist: _landmark(rightWristX, rightWristY),
    },
  );
}

BodyLandmark _landmark(double x, double y) {
  return BodyLandmark(x: x, y: y, z: 0, likelihood: 1);
}
