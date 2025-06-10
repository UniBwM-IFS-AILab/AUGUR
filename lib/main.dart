import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/ui/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:augur/ui/pages/launch_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Import to check for kIsWeb
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx; // Import to check the platform

void main(){
  // Ensure all bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Set the preferred orientations only for Android and iOS
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
  }
  runApp(ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    sherpa_onnx.initBindings();
    copyAllAssetFiles('Augur_tmp');
    return MaterialApp(
      title: 'Augur',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: MaterialColor(AppColors.primary.toARGB32(), getColorSwatch(AppColors.primary)),
      ),
      home: LaunchMenu(),
    );
  }
}
