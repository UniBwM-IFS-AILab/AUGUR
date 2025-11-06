import 'dart:async';
import 'dart:io';
import 'package:augur/ui/utils/utils.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class SpeechSynthesizer {
  late sherpa_onnx.OfflineTts _tts;
  late AudioPlayer _player;
  bool _isInitialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  // Remove auto-initialization from constructor
  SpeechSynthesizer();

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('SpeechSynthesizer: Loading TTS models...');
    _tts = await createOfflineTts();
    _player = AudioPlayer();
    _isInitialized = true;
    _initCompleter.complete();
    debugPrint('SpeechSynthesizer: TTS models loaded successfully');
  }

  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _initCompleter.future; // Wait until initialization is complete
    }
  }

  Future<sherpa_onnx.OfflineTts> createOfflineTts() async {
    final Directory directory = await getApplicationDocumentsDirectory();

    String modelName = p.join(
        directory.path, "AUGUR_tmp/models/tts", "en_GB-cori-medium.onnx");
    String modelTokens =
        p.join(directory.path, "AUGUR_tmp/models/tts", "tokens.txt");
    String dataDir =
        p.join(directory.path, "AUGUR_tmp/models/tts", "espeak-ng-data/");

    final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
      vits: sherpa_onnx.OfflineTtsVitsModelConfig(
        model: modelName,
        tokens: modelTokens,
        dataDir: dataDir,
      ),
      numThreads: 2,
      debug: true,
      provider: 'cpu',
    );

    final config = sherpa_onnx.OfflineTtsConfig(
      model: modelConfig,
      maxNumSenetences: 1,
    );
    return sherpa_onnx.OfflineTts(config);
  }

  Future<void> synthesizeAndPlay(String text,
      {int sid = 0, double speed = 1.0}) async {
    await ensureInitialized();
    debugPrint("Generating speech...");
    final audio = _tts.generate(text: text, sid: sid, speed: speed);
    Uint8List wavData = encodeWAV(audio.samples, audio.sampleRate);
    await _player.play(BytesSource(wavData), mode: PlayerMode.mediaPlayer);
  }

  void dispose() {
    _tts.free();
    _player.dispose();
  }
}
