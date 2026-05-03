import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../camera/camera_service.dart';
import '../game/boxing_combo_game.dart';
import '../pose/pose_detection_service.dart';
import '../punch/punch_detection_config.dart';
import '../punch/punch_detection_debug.dart';
import '../punch/punch_detection_service.dart';
import '../punch/punch_type.dart';

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen>
    with WidgetsBindingObserver {
  static const Duration _debugConsoleLogInterval = Duration(seconds: 1);

  final CameraService _cameraService = CameraService();
  final BoxingComboGame _comboGame = BoxingComboGame();
  final PoseDetectionService _poseDetectionService = PoseDetectionService();
  PunchDetectionService _punchDetectionService = PunchDetectionService(
    config: const PunchDetectionConfig(
      cameraFacing: PunchCameraFacing.front,
      mirrorMode: true,
    ),
  );

  CameraController? _controller;
  Future<void>? _initializeCameraFuture;
  String? _errorMessage;
  PunchType _detectedPunch = PunchType.none;
  DateTime? _lastDebugConsoleLogAt;
  String _debugOverlayReason = 'noPrev';
  String? _lastLeftDebugLog;
  String? _lastRightDebugLog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final controller = await _cameraService.initialize(
        onFrame: _handleCameraFrame,
      );

      if (!mounted) {
        await _cameraService.dispose();
        return;
      }

      _punchDetectionService = PunchDetectionService(
        config: _punchConfigForCamera(controller.description),
      );

      setState(() {
        _controller = controller;
        _errorMessage = null;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _messageForCameraException(error);
      });
    }
  }

  void _handleCameraFrame(CameraImage image) {
    final camera = _cameraService.camera;
    final controller = _controller;
    if (camera == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    unawaited(_detectPose(image, camera, controller.value.deviceOrientation));
  }

  Future<void> _detectPose(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    final result = await _poseDetectionService.detectFromCameraImage(
      image: image,
      camera: camera,
      deviceOrientation: deviceOrientation,
    );

    if (!mounted || result == null) {
      return;
    }

    final punch = _punchDetectionService.detect(result);
    if (punch != PunchType.none) {
      _comboGame.processPunch(punch);
    }

    final debugReadoutChanged = _refreshDebugReadout();
    if (punch == _detectedPunch && !debugReadoutChanged) {
      return;
    }

    setState(() {
      _detectedPunch = punch;
    });
  }

  String _messageForCameraException(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera permission is required.';
      case 'NoCameraFound':
        return 'No camera is available on this device.';
      default:
        return 'Camera could not be started.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _punchDetectionService.reset();
      _comboGame.reset();
      _resetDebugOverlay();
      unawaited(_cameraService.dispose());
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraFuture = _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraService.dispose());
    unawaited(_poseDetectionService.dispose());
    _punchDetectionService.reset();
    _comboGame.reset();
    _resetDebugOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeCameraFuture,
        builder: (context, snapshot) {
          if (_errorMessage != null) {
            return Center(
              child: Text(_errorMessage!, textAlign: TextAlign.center),
            );
          }

          final controller = _controller;
          if (controller == null || !controller.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: _buildCameraPreview(controller),
                ),
              ),
              Positioned(
                left: 16,
                top: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      'Detected: ${_detectedPunch.label}\n'
                      'Reason: $_debugOverlayReason',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCameraPreview(CameraController controller) {
    return CameraPreview(controller);
  }

  bool _refreshDebugReadout() {
    final debug = _punchDetectionService.lastDebug;
    final nextReason = _shortReason(debug.reason);
    _logDebugReadout(debug);

    final changed = nextReason != _debugOverlayReason;
    _debugOverlayReason = nextReason;
    return changed;
  }

  void _logDebugReadout(PunchDetectionDebug debug) {
    final now = DateTime.now();
    final lastLog = _lastDebugConsoleLogAt;
    if (lastLog != null && now.difference(lastLog) < _debugConsoleLogInterval) {
      return;
    }

    final config = debug.config;
    final leftLog = _stableHandDebugLog(
      label: 'L',
      hand: debug.left,
      config: config,
      previousLog: _lastLeftDebugLog,
      fallbackReason: _shortReason(debug.reason),
    );
    final rightLog = _stableHandDebugLog(
      label: 'R',
      hand: debug.right,
      config: config,
      previousLog: _lastRightDebugLog,
      fallbackReason: _shortReason(debug.reason),
    );

    if (debug.left != null) {
      _lastLeftDebugLog = leftLog;
    }
    if (debug.right != null) {
      _lastRightDebugLog = rightLog;
    }

    debugPrint(
      'PunchDebug reason=${_shortReason(debug.reason)} '
      'detected=${debug.detectedPunch.label} | $leftLog | $rightLog',
    );
    _lastDebugConsoleLogAt = now;
  }

  String _fmt(double value) => value.toStringAsFixed(2);
  String _fmtCompact(double value) => value.toStringAsFixed(1);

  String _stableHandDebugLog({
    required String label,
    required PunchHandDebug? hand,
    required PunchDetectionConfig config,
    required String? previousLog,
    required String fallbackReason,
  }) {
    if (hand == null) {
      return previousLog ?? '$label $fallbackReason';
    }

    return '$label FWD=${_fmt(hand.extensionDelta)}/${_fmt(config.minForwardDelta)} '
        'VEL=${_fmtCompact(hand.wristVelocity)}/${_fmtCompact(config.minWristVelocity)} '
        'SCORE=${_fmt(hand.rawMovementScore)}/${_fmt(config.minMovementScore)} '
        'fail=${_failText(hand.failedThresholds)}';
  }

  void _resetDebugOverlay() {
    _lastDebugConsoleLogAt = null;
    _lastLeftDebugLog = null;
    _lastRightDebugLog = null;
    _debugOverlayReason = 'noPrev';
  }

  String _shortReason(PunchDetectionDebugReason reason) {
    return switch (reason) {
      PunchDetectionDebugReason.waitingForPreviousFrame => 'noPrev',
      PunchDetectionDebugReason.noPose => 'noPose',
      PunchDetectionDebugReason.missingLandmarks => 'missing/lowConf',
      PunchDetectionDebugReason.invalidScale => 'badScale',
      PunchDetectionDebugReason.cooldown => 'cooldown',
      PunchDetectionDebugReason.frameGap => 'gap',
      PunchDetectionDebugReason.belowThreshold => 'below',
      PunchDetectionDebugReason.ambiguous => 'ambig',
      PunchDetectionDebugReason.leftSelected => 'left',
      PunchDetectionDebugReason.rightSelected => 'right',
    };
  }

  String _failText(List<String> failedThresholds) {
    if (failedThresholds.isEmpty) {
      return 'none';
    }

    return failedThresholds.take(4).map(_thresholdCode).join(',');
  }

  String _thresholdCode(String threshold) {
    return switch (threshold) {
      'minForwardDelta' => 'FWD',
      'minElbowForwardDelta' => 'ELB',
      'minWristVelocity' => 'VEL',
      'minExtensionFromShoulder' => 'EXT',
      'minWristAheadOfElbow' => 'AHEAD',
      'minArmStraightness' => 'STR',
      'minArmStraightnessDelta' => 'STRD',
      'maxVerticalDelta' => 'VERT',
      'minMovementScore' => 'SCORE',
      'elapsed' => 'TIME',
      _ => threshold,
    };
  }

  PunchDetectionConfig _punchConfigForCamera(CameraDescription camera) {
    final isFrontCamera = camera.lensDirection == CameraLensDirection.front;
    return PunchDetectionConfig(
      cameraFacing: isFrontCamera
          ? PunchCameraFacing.front
          : PunchCameraFacing.rear,
      mirrorMode: isFrontCamera,
    );
  }
}
