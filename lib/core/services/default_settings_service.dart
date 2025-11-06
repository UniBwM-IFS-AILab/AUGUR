import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DefaultSettingsService {
  static const String _settingsFileName = 'default_settings.json';
  static const String _defaultIp = '127.0.0.1';

  // Singleton pattern
  static final DefaultSettingsService _instance =
      DefaultSettingsService._internal();
  factory DefaultSettingsService() => _instance;
  DefaultSettingsService._internal();

  Map<String, dynamic> _settings = {};
  bool _isInitialized = false;

  /// Initialize the settings service and load existing settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadSettings();
      _isInitialized = true;
      debugPrint('DefaultSettingsService: Initialized successfully');
    } catch (e) {
      debugPrint('DefaultSettingsService: Error during initialization: $e');
      // Set default values if loading fails
      _settings = {'defaultIp': _defaultIp};
      await _saveSettings();
      _isInitialized = true;
    }
  }

  /// Get the settings file path
  Future<String> _getSettingsFilePath() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String augurTmpPath = p.join(directory.path, 'AUGUR_tmp');

    // Create AUGUR_tmp directory if it doesn't exist
    final Directory augurTmpDir = Directory(augurTmpPath);
    if (!await augurTmpDir.exists()) {
      await augurTmpDir.create(recursive: true);
    }

    return p.join(augurTmpPath, _settingsFileName);
  }

  /// Load settings from file
  Future<void> _loadSettings() async {
    final String filePath = await _getSettingsFilePath();
    final File settingsFile = File(filePath);

    if (await settingsFile.exists()) {
      try {
        final String content = await settingsFile.readAsString();
        _settings = json.decode(content) as Map<String, dynamic>;
        debugPrint('DefaultSettingsService: Loaded settings from $filePath');
      } catch (e) {
        debugPrint('DefaultSettingsService: Error reading settings file: $e');
        // Use default settings if file is corrupted
        _settings = {'defaultIp': _defaultIp};
      }
    } else {
      // Create default settings if file doesn't exist
      _settings = {'defaultIp': _defaultIp};
      await _saveSettings();
      debugPrint('DefaultSettingsService: Created default settings file');
    }
  }

  /// Save settings to file
  Future<void> _saveSettings() async {
    try {
      final String filePath = await _getSettingsFilePath();
      final File settingsFile = File(filePath);
      final String jsonContent = json.encode(_settings);
      await settingsFile.writeAsString(jsonContent);
      debugPrint('DefaultSettingsService: Settings saved to $filePath');
    } catch (e) {
      debugPrint('DefaultSettingsService: Error saving settings: $e');
      rethrow;
    }
  }

  /// Get the default IP address
  Future<String> getDefaultIp() async {
    await initialize();
    return _settings['defaultIp'] ?? _defaultIp;
  }

  /// Set the default IP address
  Future<void> setDefaultIp(String ip) async {
    await initialize();
    _settings['defaultIp'] = ip;
    await _saveSettings();
    debugPrint('DefaultSettingsService: Default IP updated to $ip');
  }

  /// Validate IP address format
  static bool isValidIp(String ip) {
    if (ip.isEmpty) return false;

    List<String> parts = ip.split('.');
    if (parts.length != 4) return false;

    for (String part in parts) {
      int? num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  /// Get all settings (for future extensibility)
  Future<Map<String, dynamic>> getAllSettings() async {
    await initialize();
    return Map<String, dynamic>.from(_settings);
  }

  /// Set a custom setting
  Future<void> setSetting(String key, dynamic value) async {
    await initialize();
    _settings[key] = value;
    await _saveSettings();
  }

  /// Get a custom setting
  Future<T?> getSetting<T>(String key) async {
    await initialize();
    return _settings[key] as T?;
  }
}
