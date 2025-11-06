import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/ui/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:augur/ui/pages/launch_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Import to check for kIsWeb
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart'
    as sherpa_onnx; // Import to check the platform
import 'package:augur/core/services/speech_service.dart';
import 'package:media_kit/media_kit.dart';
//sudo apt install -y libmpv-dev libmpv2 mpv
//sudo apt update && sudo apt install -y libasound2-dev
void main() async {
  // Ensure all bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit for video playback
  MediaKit.ensureInitialized();

  // Set the preferred orientations only for Android and iOS
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
  }

  // Initialize Sherpa-ONNX bindings
  sherpa_onnx.initBindings();

  // Copy asset files
  await copyAllAssetFiles('Augur_tmp');

  // Initialize speech service in background to avoid delays later
  debugPrint('Starting speech service initialization in background...');
  SpeechService().initialize().then((_) {
    debugPrint('Speech service initialized successfully');
  }).catchError((error) {
    debugPrint('Failed to initialize speech service: $error');
  });

  runApp(ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Augur',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: MaterialColor(
            AppColors.primary.toARGB32(), getColorSwatch(AppColors.primary)),
      ),
      home: LaunchMenu(),
    );
  }
}
