import 'package:flutter/material.dart';
import 'package:augur/pages/launch_page.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter/foundation.dart'; // Import to check for kIsWeb
import 'dart:io' show Platform; // Import to check the platform

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
  runApp(const MainApp());
  
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Augur',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LaunchMenu(),
    );
  }
}
