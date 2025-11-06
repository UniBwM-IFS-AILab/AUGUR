import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/clients/redis_client.dart';
import '../core/classes/plan.dart';
import '../core/classes/platform.dart';
import '../core/classes/mission.dart';
import '../core/classes/detected_object.dart';

class RedisProvider extends StateNotifier<RedisClient?> {
  Timer? _debounceTimer;

  RedisProvider() : super(null);

  void initialize(String redisIp, VoidCallback onConnectionLost) {
    if (state != null) return; // Prevent multiple initializations

    debugPrint("RedisProvider: Initializing with callback");
    state = RedisClient(
      redisIp: redisIp,
      onConnectionLost: () {
        debugPrint(
            "RedisProvider: onConnectionLost callback called, calling UI callback");
        // Debounce connection lost callbacks to prevent rapid fire reconnection attempts
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          onConnectionLost(); // Notify UI when connection is lost
        });
      },
    );
  }

  Future<void> connect() async {
    try {
      await state!.connect();
    } catch (e) {
      // If connection fails, notify UI
      state?.onConnectionLost?.call();
      rethrow;
    }
  }

  void setTrajectoryMode(bool value) {
    state?.setTrajectoryMode(value);
  }

  Future<bool> deletePlan(String planId) async {
    return await state?.deletePlan(planId) ?? false;
  }

  Future<bool> updatePlanPriority(String planId, int newPriority) async {
    return await state?.updatePlanPriority(planId, newPriority) ?? false;
  }

  Future<bool> updatePlanActions(
      String planId, List<Map<String, dynamic>> newActions) async {
    return await state?.updatePlanActions(planId, newActions) ?? false;
  }

  Future<bool> updatePlan(String planId, Map<String, dynamic> updates) async {
    return await state?.updatePlan(planId, updates) ?? false;
  }

  Future<Map<String, dynamic>?> getPlan(String planId) async {
    return await state?.getPlan(planId);
  }

  Future<bool> deleteMission(String teamId) async {
    return await state?.deleteMission(teamId) ?? false;
  }

  Future<bool> updateMission(
      String teamId, Map<String, dynamic> updates) async {
    return await state?.updateMission(teamId, updates) ?? false;
  }

  Future<Map<String, dynamic>?> getMission(String teamId) async {
    return await state?.getMission(teamId);
  }

  Future<bool> confirmDetectedObject(String objectId) async {
    return await state?.confirmDetectedObject(objectId) ?? false;
  }

  Future<bool> deleteDetectedObject(String objectId) async {
    return await state?.deleteDetectedObject(objectId) ?? false;
  }

  Future<Map<String, dynamic>?> getDetectedObject(String objectId) async {
    return await state?.getDetectedObject(objectId);
  }

  Future<void> reconnect() async {
    try {
      await state?.disconnect();
      await state?.connect();
    } catch (e) {
      // If reconnection fails, notify UI
      state?.onConnectionLost?.call();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await state?.disconnect();
  }

  @override
  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await state?.dispose();
    super.dispose();
  }
}

// Provider that starts as `null` until initialized with an IP
final redisClientProvider = StateNotifierProvider<RedisProvider, RedisClient?>(
  (ref) => RedisProvider(),
);

final platformDataProvider = StreamProvider<List<Platform>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value([]);
  return redisClient.platformStream;
});

final trajectoryDataProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value([]);
  return redisClient.trajectoryStream;
});

final planStreamProvider = StreamProvider<List<Plan>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value([]);
  return redisClient.planStream;
});

final missionsStreamProvider = StreamProvider<List<Mission>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value([]);
  return redisClient.missionsStream;
});

final teamIdsDataProvider = StreamProvider<List<String>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value([]);
  return redisClient.teamIdsStream;
});

final detectedObjectsDataProvider = StreamProvider<List<DetectedObject>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value([]);
  return redisClient.detectedObjectsStream;
});
