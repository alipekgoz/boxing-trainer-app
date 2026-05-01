import 'package:flutter/material.dart';

import 'screens/camera_preview_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BoxingTrainerApp());
}

class BoxingTrainerApp extends StatelessWidget {
  const BoxingTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Boxing Trainer',
      theme: ThemeData.dark(useMaterial3: true),
      home: const CameraPreviewScreen(),
    );
  }
}
