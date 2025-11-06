import 'dart:async';
import 'dart:typed_data';
import 'package:augur/ui/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// Lightweight speech recorder that uses a shared recognizer instance
/// This avoids the heavy model initialization on each instance
class SpeechRecorderLight {
  final sherpa_onnx.OnlineRecognizer _recognizer;
  Function(String) onResult;

  final AudioRecorder _audioRecorder = AudioRecorder();
  sherpa_onnx.OnlineStream? _stream;
  bool _isListening = false;
  final int sampleRate = 16000;
  StreamSubscription<List<int>>? _audioSubscription;

  final List<Float32List> _audioBuffer = [];
  final int _chunkSize = 1600;

  SpeechRecorderLight({
    required sherpa_onnx.OnlineRecognizer recognizer,
    required this.onResult,
  }) : _recognizer = recognizer;

  Future<void> startRecording() async {
    debugPrint("Streaming started.");
    if (_isListening) return;
    if (!await _audioRecorder.hasPermission()) return;

    _isListening = true;
    _stream = _recognizer.createStream();
    _audioBuffer.clear();

    try {
      var config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      );

      final stream = await _audioRecorder.startStream(config);

      _audioSubscription = stream.listen((data) {
        Float32List floatAudio =
            convertBytesToFloat32(Uint8List.fromList(data));
        _audioBuffer.add(floatAudio);

        int totalLength =
            _audioBuffer.fold(0, (sum, chunk) => sum + chunk.length);
        if (totalLength >= _chunkSize) {
          Float32List mergedBuffer = Float32List(totalLength);
          int offset = 0;
          for (var chunk in _audioBuffer) {
            mergedBuffer.setRange(offset, offset + chunk.length, chunk);
            offset += chunk.length;
          }
          _stream!
              .acceptWaveform(samples: mergedBuffer, sampleRate: sampleRate);
          _audioBuffer.clear(); // Clear buffer after processing

          while (_recognizer.isReady(_stream!)) {
            _recognizer.decode(_stream!);
          }
          final text = _recognizer.getResult(_stream!).text;
          debugPrint("Text: $text");
          if (text.isNotEmpty) {
            onResult(text);
          }

          if (_recognizer.isEndpoint(_stream!)) {
            _recognizer.reset(_stream!);
          }
        }
      }, onDone: () {
        debugPrint("Streaming stopped.");
      });
    } catch (e) {
      debugPrint("Error starting recording: $e");
    }
  }

  Future<void> stopRecording() async {
    if (!_isListening) return;
    _isListening = false;
    await _audioRecorder.stop();
    _audioSubscription?.cancel();
    _finalizeRecognition();
  }

  void _finalizeRecognition() {
    if (_stream == null) return;

    final tailPaddings = Float32List(8000);
    _stream!.acceptWaveform(samples: tailPaddings, sampleRate: sampleRate);

    while (_recognizer.isReady(_stream!)) {
      _recognizer.decode(_stream!);
    }

    final result = _recognizer.getResult(_stream!);
    if (result.text.isNotEmpty) {
      onResult(result.text);
    }

    _stream!.free();
    _stream = null;
  }

  Future<void> pauseRecording() async {
    await _audioRecorder.pause();
  }

  Future<void> resumeRecording() async {
    await _audioRecorder.resume();
  }

  void dispose() {
    _audioSubscription?.cancel();
    _audioRecorder.dispose();
    _stream?.free();
    // Note: Don't free the shared recognizer here
  }
}
