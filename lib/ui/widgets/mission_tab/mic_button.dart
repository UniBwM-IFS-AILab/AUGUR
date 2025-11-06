import 'dart:async';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:augur/core/models/speech_recorder_light.dart';
import 'package:augur/core/services/speech_service.dart';

class MicButton extends StatefulWidget {
  final StreamController<String> textStreamController;

  const MicButton({super.key, required this.textStreamController});

  @override
  MicButtonState createState() => MicButtonState();
}

class MicButtonState extends State<MicButton> {
  SpeechRecorderLight? _speechRecorder;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeechRecorder();
  }

  Future<void> _initializeSpeechRecorder() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      // Wait for speech service to be ready
      await SpeechService().ensureInitialized();

      // Create a recorder instance with our callback
      _speechRecorder = SpeechService().createRecorder(
        onResult: (text) {
          widget.textStreamController.add(text);
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize speech recorder: $e');
    } finally {
      _isInitializing = false;
      if (mounted) setState(() {});
    }
  }

  void _handlePressStart() async {
    if (_speechRecorder == null) {
      debugPrint('Speech recorder not initialized yet');
      return;
    }

    // Optionally play a feedback sound
    // await SpeechService().synthesizeAndPlay("Listening...", speed: 0.7);
    _speechRecorder!.startRecording();
  }

  void _handlePressEnd() {
    _speechRecorder?.stopRecording();
  }

  @override
  void dispose() {
    _speechRecorder?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _handlePressStart(), // Simulate press start
      onTapUp: (_) => _handlePressEnd(), // Simulate release
      onTapCancel: () => _handlePressEnd(), // Handle canceled presses
      child: ElevatedButton(
        onPressed: () {}, // Also trigger when clicked
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.secondary; // Change color when pressed
            }
            return AppColors.primary; // Default color
          }),
          shape: WidgetStateProperty.all(CircleBorder()),
          padding: WidgetStateProperty.all(EdgeInsets.all(20)),
        ),
        child: Icon(Icons.mic, color: Colors.white, size: 30),
      ),
    );
  }
}
