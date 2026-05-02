import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

typedef CameraFrameCallback = void Function(CameraImage image);

class CameraService {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _isStreamingFrames = false;

  CameraController? get controller => _controller;
  CameraDescription? get camera => _camera;

  Future<CameraController> initialize({CameraFrameCallback? onFrame}) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('NoCameraFound', 'No camera is available.');
    }

    final camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await controller.initialize();
    _camera = camera;
    _controller = controller;

    if (onFrame != null) {
      await startFrameStream(onFrame);
    }

    return controller;
  }

  Future<void> startFrameStream(CameraFrameCallback onFrame) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isStreamingFrames) {
      return;
    }

    await controller.startImageStream(onFrame);
    _isStreamingFrames = true;
  }

  Future<void> stopFrameStream() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_isStreamingFrames) {
      return;
    }

    await controller.stopImageStream();
    _isStreamingFrames = false;
  }

  Future<void> dispose() async {
    await stopFrameStream();
    await _controller?.dispose();
    _controller = null;
    _camera = null;
  }
}
