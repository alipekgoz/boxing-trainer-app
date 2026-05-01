import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../camera/camera_service.dart';

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();

  CameraController? _controller;
  Future<void>? _initializeCameraFuture;
  String? _errorMessage;

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
    // Phase 1 only prepares the frame stream. Frame processing starts later.
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

          return Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          );
        },
      ),
    );
  }
}
