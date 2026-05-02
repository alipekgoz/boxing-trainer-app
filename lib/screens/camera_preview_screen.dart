import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../camera/camera_service.dart';
import '../pose/pose_detection_service.dart';
import '../punch/punch_detection_service.dart';
import '../punch/punch_type.dart';

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final PoseDetectionService _poseDetectionService = PoseDetectionService();
  final PunchDetectionService _punchDetectionService = PunchDetectionService();

  CameraController? _controller;
  Future<void>? _initializeCameraFuture;
  String? _errorMessage;
  PunchType _detectedPunch = PunchType.none;

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
    if (punch != _detectedPunch) {
      setState(() {
        _detectedPunch = punch;
      });
    }
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
                  child: CameraPreview(controller),
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
                      _detectedPunch.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
}
