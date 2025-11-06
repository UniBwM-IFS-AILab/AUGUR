import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:augur/core/models/speech_synthesizer.dart';
import 'package:augur/core/models/speech_recorder_light.dart';

/// Global service for managing speech recognition and synthesis
/// Initializes models once at startup to avoid delays during usage
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  // Shared model instances
  sherpa_onnx.OnlineRecognizer? _recognizer;
  SpeechSynthesizer? _speechSynthesizer;

  // Initialization state
  bool _isInitialized = false;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// Initialize speech models at app startup
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) {
      await _initCompleter.future;
      return;
    }

    _isInitializing = true;

    try {
      debugPrint('SpeechService: Initializing speech models...');

      // Initialize speech synthesizer
      _speechSynthesizer = SpeechSynthesizer();
      await _speechSynthesizer!.initialize();

      // Initialize shared speech recognition model
      await _initializeRecognizer();

      _isInitialized = true;
      _initCompleter.complete();

      debugPrint('SpeechService: Speech models initialized successfully');
    } catch (e) {
      debugPrint('SpeechService: Failed to initialize speech models: $e');
      _initCompleter.completeError(e);
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initializeRecognizer() async {
    final Directory directory = await getApplicationDocumentsDirectory();

    final transducer = sherpa_onnx.OnlineTransducerModelConfig(
      encoder: p.join(directory.path, "AUGUR_tmp/models/asr",
          "encoder-epoch-99-avg-1.onnx"),
      decoder: p.join(directory.path, "AUGUR_tmp/models/asr",
          "decoder-epoch-99-avg-1.onnx"),
      joiner: p.join(
          directory.path, "AUGUR_tmp/models/asr", "joiner-epoch-99-avg-1.onnx"),
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
    debugPrint("SpeechService: Sherpa-ONNX recognizer initialized successfully.");
  }

  /// Get the shared speech recognizer
  sherpa_onnx.OnlineRecognizer get recognizer {
    if (!_isInitialized || _recognizer == null) {
      throw StateError(
          'SpeechService not initialized. Call initialize() first.');
    }
    return _recognizer!;
  }

  /// Get the initialized speech synthesizer
  SpeechSynthesizer get speechSynthesizer {
    if (!_isInitialized || _speechSynthesizer == null) {
      throw StateError(
          'SpeechService not initialized. Call initialize() first.');
    }
    return _speechSynthesizer!;
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Wait for initialization to complete
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      if (!_isInitializing) {
        await initialize();
      } else {
        await _initCompleter.future;
      }
    }
  }

  /// Create a lightweight speech recorder that uses the shared recognizer
  SpeechRecorderLight createRecorder({required Function(String) onResult}) {
    if (!_isInitialized) {
      throw StateError(
          'SpeechService not initialized. Call initialize() first.');
    }

    return SpeechRecorderLight(
      recognizer: _recognizer!,
      onResult: onResult,
    );
  }

  /// Synthesize and play text using the pre-initialized synthesizer
  Future<void> synthesizeAndPlay(String text,
      {int sid = 0, double speed = 1.0}) async {
    await ensureInitialized();
    return _speechSynthesizer!.synthesizeAndPlay(text, sid: sid, speed: speed);
  }

  /// Dispose of all resources
  void dispose() {
    _recognizer?.free();
    _speechSynthesizer?.dispose();
    _recognizer = null;
    _speechSynthesizer = null;
    _isInitialized = false;
  }
}
