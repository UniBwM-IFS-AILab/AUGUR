
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:augur/ui/utils/utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class SpeechRecorder {
  Function(String) onResult;
  final AudioRecorder _audioRecorder = AudioRecorder();
  late sherpa_onnx.OnlineRecognizer _recognizer;
  late sherpa_onnx.OnlineStream _stream;
  bool _isListening = false;
  final int sampleRate = 16000;
  StreamSubscription<List<int>>? _audioSubscription;

  final List<Float32List> _audioBuffer = [];
  final int _chunkSize = 1600;
  //bool _hasSentInitialPadding = false;

  SpeechRecorder({required this.onResult}) {
    _initializeSherpa();
  }

  Future<void> _initializeSherpa() async {
    final Directory directory = await getApplicationDocumentsDirectory();

    final transducer = sherpa_onnx.OnlineTransducerModelConfig(
      encoder: p.join(directory.path, "AUGUR_tmp/models/asr", "encoder-epoch-99-avg-1.onnx"),
      decoder: p.join(directory.path, "AUGUR_tmp/models/asr", "decoder-epoch-99-avg-1.onnx"),
      joiner: p.join(directory.path, "AUGUR_tmp/models/asr", "joiner-epoch-99-avg-1.onnx"),
    );

    final modelConfig = sherpa_onnx.OnlineModelConfig(
      transducer: transducer,
      tokens: p.join(directory.path, "AUGUR_tmp/models/asr", "tokens.txt"),
      modelType: 'zipformer',
      debug: true,
      numThreads: 3,
    );

    final config = sherpa_onnx.OnlineRecognizerConfig(
      model: modelConfig,
      ruleFsts: '',
    );

    _recognizer = sherpa_onnx.OnlineRecognizer(config);
    print("Sherpa-ONNX initialized successfully.");
  }

  Future<void> startRecording() async {
    print("Streaming started.");
    if (_isListening) return;
    if (!await _audioRecorder.hasPermission()) return;

    _isListening = true;
    _stream = _recognizer.createStream();
    _audioBuffer.clear();
    //_hasSentInitialPadding = false;

    try {
      var config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      );

      final stream = await _audioRecorder.startStream(config);

      _audioSubscription = stream.listen((data) {
        Float32List floatAudio = convertBytesToFloat32(Uint8List.fromList(data));
        _audioBuffer.add(floatAudio);

        // if (!_hasSentInitialPadding) {
        //   _stream.acceptWaveform(samples: Float32List(400), sampleRate: sampleRate);
        //   _hasSentInitialPadding = true;
        // }

        int totalLength = _audioBuffer.fold(0, (sum, chunk) => sum + chunk.length);
        if (totalLength >= _chunkSize) {
          Float32List mergedBuffer = Float32List(totalLength);
          int offset = 0;
          for (var chunk in _audioBuffer) {
            mergedBuffer.setRange(offset, offset + chunk.length, chunk);
            offset += chunk.length;
          }
          _stream.acceptWaveform(samples: mergedBuffer, sampleRate: sampleRate);
          _audioBuffer.clear(); // Clear buffer after processing

          while (_recognizer.isReady(_stream)) {
            _recognizer.decode(_stream);
          }
          final text = _recognizer.getResult(_stream).text;
          print("Text: $text");
          if (text.isNotEmpty) {
            onResult(text);
          }

          if (_recognizer.isEndpoint(_stream)) {
            _recognizer.reset(_stream);
          }
        }
      }, onDone: () {
        print("Streaming stopped.");
      });
    } catch (e) {
      print("Error starting recording: $e");
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
    final tailPaddings = Float32List(8000);
    _stream.acceptWaveform(samples: tailPaddings, sampleRate: sampleRate);

    while (_recognizer.isReady(_stream)) {
      _recognizer.decode(_stream);
    }

    final result = _recognizer.getResult(_stream);
    if (result.text.isNotEmpty) {
      onResult(result.text);
    }

    _stream.free();
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
    _recognizer.free();
  }
}