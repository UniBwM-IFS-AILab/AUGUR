import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/clients/ros_client.dart';

class RosProvider extends StateNotifier<RosClient?> {
  RosProvider() : super(null);

  void initialize(String rosUrl, VoidCallback onConnectionLost) {
    if (state != null) return; // Prevent multiple initializations

    state = RosClient(url: rosUrl);

    // Listen to connection status changes
    state!.statusStream.listen((status) {
      debugPrint("RosProvider: Status changed to: $status");
      if (!state!.isConnected()) {
        debugPrint("RosProvider: Connection lost, but only warning");
      }
    });
  }

  Future<void> connect() async {
    try {
      await state?.connect();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> disconnect() async {
    state?.close();
  }

  bool isConnected() {
    return state?.isConnected() ?? false;
  }

  @override
  void dispose() {
    state?.close();
    super.dispose();
  }

  Stream<dynamic> subscribeToTopic({
    required String topicName,
    required String messageType,
    bool throttleRate = false,
    int queueSize = 10,
    int queueLength = 10,
  }) {
    if (state == null) {
      return Stream.value(null); // Return empty stream if not initialized
    }

    return state!.subscribeToTopic(
      topicName: topicName,
      messageType: messageType,
      throttleRate: throttleRate,
      queueSize: queueSize,
      queueLength: queueLength,
    );
  }

  void publishToTopic(
      {required String topicName,
      required String messageType,
      required Map<String, dynamic> message}) {
    state?.publish(
        topicName: topicName, messageType: messageType, message: message);
  }
}

// Provider that starts as `null` until initialized with a URL
final rosClientProvider = StateNotifierProvider<RosProvider, RosClient?>(
  (ref) => RosProvider(),
);

// Connection status provider
final rosConnectionStatusProvider = Provider<bool>((ref) {
  final client = ref.watch(rosClientProvider);
  return client?.isConnected() ?? false;
});

// Topic configuration class
class RosTopicConfig {
  final String topicName;
  final String messageType;
  final int queueSize;
  final int queueLength;

  const RosTopicConfig({
    required this.topicName,
    required this.messageType,
    this.queueSize = 10,
    this.queueLength = 10,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RosTopicConfig &&
          runtimeType == other.runtimeType &&
          topicName == other.topicName &&
          messageType == other.messageType &&
          queueSize == other.queueSize &&
          queueLength == other.queueLength;

  @override
  int get hashCode =>
      Object.hash(topicName, messageType, queueSize, queueLength);
}

// A family provider for ROS topic streams
final rosTopicStreamProvider =
    StreamProvider.autoDispose.family<dynamic, RosTopicConfig>((ref, config) {
  final rosClient = ref.watch(rosClientProvider);
  if (rosClient == null) {
    return Stream.value(null); // Return empty stream if not initialized
  }

  return rosClient.subscribeToTopic(
    topicName: config.topicName,
    messageType: config.messageType,
    queueSize: config.queueSize,
    queueLength: config.queueLength,
  );
});
