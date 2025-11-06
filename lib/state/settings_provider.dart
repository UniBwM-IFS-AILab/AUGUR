import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Settings state class
class AppSettings {
  final bool isSatelliteMode;
  final bool isTrajectoryMode;
  final bool isVoiceControlEnabled;

  const AppSettings({
    this.isSatelliteMode = false,
    this.isTrajectoryMode = false,
    this.isVoiceControlEnabled = true,
  });

  AppSettings copyWith({
    bool? isSatelliteMode,
    bool? isTrajectoryMode,
    bool? isVoiceControlEnabled,
  }) {
    return AppSettings(
      isSatelliteMode: isSatelliteMode ?? this.isSatelliteMode,
      isTrajectoryMode: isTrajectoryMode ?? this.isTrajectoryMode,
      isVoiceControlEnabled:
          isVoiceControlEnabled ?? this.isVoiceControlEnabled,
    );
  }
}

// Settings notifier
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setSatelliteMode(bool enabled) {
    state = state.copyWith(isSatelliteMode: enabled);
    debugPrint('Settings: Satellite mode set to $enabled');
  }

  void setTrajectoryMode(bool enabled) {
    state = state.copyWith(isTrajectoryMode: enabled);
    debugPrint('Settings: Trajectory mode set to $enabled');
  }

  void setVoiceControlEnabled(bool enabled) {
    state = state.copyWith(isVoiceControlEnabled: enabled);
    debugPrint('Settings: Voice control set to $enabled');
  }
}

// Settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
