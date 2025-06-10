import 'dart:async';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:augur/core/models/speech_recognizer.dart';
//import 'package:augur/core/models/speech_synthesizer.dart';

class MicButton extends StatefulWidget {
  final StreamController<String> textStreamController;

  const MicButton({super.key, required this.textStreamController});

  @override
  MicButtonState createState() => MicButtonState();
}

class MicButtonState extends State<MicButton> {
  final SpeechRecorder _speechRecorder  = SpeechRecorder(onResult: (text) {});
  //late SpeechSynthesizer _synthesizer SpeechSynthesizer();

  @override
  void initState() {
    super.initState();

    _speechRecorder.onResult = (text) {
      widget.textStreamController.add(text);
    };
  }

  void _handlePressStart() async {
    //await _synthesizer.synthesizeAndPlay("Hello there, I am learning speech recognition.", speed: 0.7);
    _speechRecorder.startRecording();
  }

  void _handlePressEnd(){
    _speechRecorder.stopRecording();
  }

  @override
  void dispose() {
    //_synthesizer.dispose();
    _speechRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _handlePressStart(), // Simulate press start
      onTapUp: (_) => _handlePressEnd(), // Simulate release
      onTapCancel: () => _handlePressEnd(), // Handle canceled presses
      child: ElevatedButton(
        onPressed: (){}, // Also trigger when clicked
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return AppColors.secondary; // Change color when pressed
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
