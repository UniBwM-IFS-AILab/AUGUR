import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/clients/redis_client.dart';

class RedisProvider extends StateNotifier<RedisClient?> {
  RedisProvider() : super(null);

  void initialize(String redisIp, VoidCallback onConnectionLost) {
    if (state != null) return; // Prevent multiple initializations

    state = RedisClient(
      redisIp: redisIp,
      onConnectionLost: () {
        onConnectionLost(); // Notify UI when connection is lost
      },
    );
  }

  Future<void> connect() async{
    await state!.connect();
  }

  void setTrajectoryMode(bool value) {
    state?.setTrajectoryMode(value);
  }

  Future<void> reconnect() async{
    await state?.disconnect();
    await state?.connect();
  }

  Future<void> disconnect() async {
    await state?.disconnect();
  }

  @override
  Future<void> dispose() async{
    await state?.dispose();
    super.dispose();
  }
}

// Provider that starts as `null` until initialized with an IP
final redisClientProvider = StateNotifierProvider<RedisProvider, RedisClient?>(
  (ref) => RedisProvider(),
);

final platformDataProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value([]); // Prevent null issues
  return redisClient.platformStream;
});

final trajectoryDataProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value([]);
  return redisClient.trajectoryStream;
});

final missionDataProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value({});
  return redisClient.missionStream;
});

final waypointDataProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value([]);
  return redisClient.waypointStream;
});

final platformNamesDataProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final redisClient = ref.watch(redisClientProvider);
  if (redisClient == null) return Stream.value([]);
  return redisClient.platformNamesStream;
});
