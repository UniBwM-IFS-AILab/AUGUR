// Copyright (c)  2024  Xiaomi Corporation
// from https://github.com/k2-fsa/sherpa-onnx
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<List<String>> getAllAssetFiles() async {
  final AssetManifest assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final List<String> assets = assetManifest.listAssets()
      .where((path) => p.split(path)[1] == 'models')
      .toList();
  return assets;
}

String stripLeadingDirectory(String src, {int n = 1}) {
  return p.joinAll(p.split(src).sublist(n));
}

Future<void> copyAllAssetFiles(String dirName) async {
  final allFiles = await getAllAssetFiles();
  for (final src in allFiles) {
    final dst = stripLeadingDirectory(src);
    await copyAssetFile(src, dst);
  }
}

Future<String> copyAssetFile(String src, [String? dst]) async {
  final Directory directory = await getApplicationDocumentsDirectory();
  dst ??= p.basename(src);

  final Directory augurTmpDir = Directory(p.join(directory.path, "AUGUR_tmp"));
  if (!augurTmpDir.existsSync()) {
    augurTmpDir.createSync(recursive: true);
  }

  final target = p.join(augurTmpDir.path, dst);
  bool exists = await File(target).exists();

  final data = await rootBundle.load(src);
  if (!exists || File(target).lengthSync() != data.lengthInBytes) {
    final List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await (await File(target).create(recursive: true)).writeAsBytes(bytes);
  }

  return target;
}

Float32List convertBytesToFloat32(Uint8List bytes, [endian = Endian.little]) {
  final values = Float32List(bytes.length ~/ 2);

  final data = ByteData.view(bytes.buffer);

  for (var i = 0; i < bytes.length; i += 2) {
    int short = data.getInt16(i, endian);
    values[i ~/ 2] = short / 32678.0;
  }

  return values;
}

Uint8List convertFloatToPCM16(Float32List floatSamples) {
  final ByteData byteData = ByteData(floatSamples.length * 2);
  for (int i = 0; i < floatSamples.length; i++) {
    int value = (floatSamples[i] * 32767).clamp(-32768, 32767).toInt();
    byteData.setInt16(i * 2, value, Endian.little);
  }
  return byteData.buffer.asUint8List();
}

Future<String> generateWaveFilename([String suffix = '']) async {
  final Directory directory = await getApplicationDocumentsDirectory();
  DateTime now = DateTime.now();
  final filename =
      '${now.year.toString()}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}$suffix.wav';

  return p.join(directory.path, filename);
}


Uint8List encodeWAV(Float32List floatSamples, int sampleRate) {
  final int numSamples = floatSamples.length;
  final int byteRate = sampleRate * 2; // 16-bit PCM = 2 bytes per sample
  final int dataSize = numSamples * 2;

  ByteData wavHeader = ByteData(44);
  wavHeader.setUint32(0, 0x52494646, Endian.big); // "RIFF"
  wavHeader.setUint32(4, 36 + dataSize, Endian.little); // File size
  wavHeader.setUint32(8, 0x57415645, Endian.big); // "WAVE"
  wavHeader.setUint32(12, 0x666D7420, Endian.big); // "fmt "
  wavHeader.setUint32(16, 16, Endian.little); // Subchunk1Size (PCM)
  wavHeader.setUint16(20, 1, Endian.little); // Audio format (PCM)
  wavHeader.setUint16(22, 1, Endian.little); // Num channels (mono)
  wavHeader.setUint32(24, sampleRate, Endian.little); // Sample rate
  wavHeader.setUint32(28, byteRate, Endian.little); // Byte rate
  wavHeader.setUint16(32, 2, Endian.little); // Block align
  wavHeader.setUint16(34, 16, Endian.little); // Bits per sample (16-bit)
  wavHeader.setUint32(36, 0x64617461, Endian.big); // "data"
  wavHeader.setUint32(40, dataSize, Endian.little); // Data size

  // Convert float samples to PCM 16-bit
  ByteData pcmData = ByteData(dataSize);
  for (int i = 0; i < numSamples; i++) {
    int value = (floatSamples[i] * 32767).clamp(-32768, 32767).toInt();
    pcmData.setInt16(i * 2, value, Endian.little);
  }

  // Combine WAV header and PCM data
  Uint8List wavBytes = Uint8List(44 + dataSize);
  wavBytes.setRange(0, 44, wavHeader.buffer.asUint8List());
  wavBytes.setRange(44, 44 + dataSize, pcmData.buffer.asUint8List());

  return wavBytes;
}

