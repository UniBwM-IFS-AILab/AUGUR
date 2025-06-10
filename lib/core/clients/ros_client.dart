import 'dart:async';
import 'package:roslibdart/roslibdart.dart';

class RosClient {
  final String url; // ROS WebSocket URL
  late Ros _ros;    // ROS instance
  bool _isConnected = false;

  // Map to store stream controllers for each topic
  final Map<String, StreamController<dynamic>> _topicStreamControllers = {};
  // Map to store topic subscriptions
  final Map<String, Topic> _topicSubscriptions = {};
  // Map to store all created topics (for both publishing and subscribing)
  final Map<String, Topic> _topics = {};

  RosClient({required this.url}) {
    _ros = Ros(url: url);
    _ros.statusStream.listen(onStatusUpdate);
  }

  // Connect to the ROS bridge
  Future<void> connect() async {
    if (!_isConnected) {
      _ros.connect();
    }
    print("ROSClient: Connected to ROS at $url");
  }

  // Disconnect from ROS bridge
  void close() {
    // Unsubscribe from all topics
    _topicSubscriptions.forEach((_, topic) {
      topic.unsubscribe();
    });

    // Close all stream controllers
    _topicStreamControllers.forEach((_, controller) {
      if (!controller.isClosed) {
        controller.close();
      }
    });

    _topicStreamControllers.clear();
    _topicSubscriptions.clear();
    _topics.clear();

    _ros.close();
  }

  // Check connection status
  bool isConnected() => _isConnected;

  // Handle connection status updates
  void onStatusUpdate(Status status) {
    _isConnected = (status == Status.connected);
  }

  // Get or create a topic
  Topic getOrCreateTopic({
    required String name,
    required String messageType,
    int queueSize = 10,
    int queueLength = 10,
    bool reconnectOnClose = true,
  }) {
    // Create a unique key based on topic name and message type
    final String topicKey = "$name:$messageType";

    // Return existing topic if it exists
    if (_topics.containsKey(topicKey)) {
      return _topics[topicKey]!;
    }

    // Create a new topic if it doesn't exist
    final topic = Topic(
      ros: _ros,
      name: name,
      type: messageType,
      reconnectOnClose: reconnectOnClose,
      queueLength: queueLength,
      queueSize: queueSize,
    );

    // Store the topic
    _topics[topicKey] = topic;

    return topic;
  }

  // Subscribe to a topic and get a stream of messages
  Stream<dynamic> subscribeToTopic({
    required String topicName,
    required String messageType,
    bool throttleRate = false,
    int queueSize = 10,
    int queueLength = 10,
  }) {
    // Create a stream controller if one doesn't exist
    if (!_topicStreamControllers.containsKey(topicName)) {
      _topicStreamControllers[topicName] = StreamController<dynamic>.broadcast();

      // Get or create the topic
      final topic = getOrCreateTopic(
        name: topicName,
        messageType: messageType,
        queueSize: queueSize,
        queueLength: queueLength,
      );

      // Store the topic subscription
      _topicSubscriptions[topicName] = topic;

      // Subscribe to the topic and forward messages to the stream
      topic.subscribe((msg) => subscribeHandler(msg, topicName));
    }

    return _topicStreamControllers[topicName]!.stream;
  }

  Future<void> subscribeHandler(Map<String, dynamic> msg, String topicName) async {
    if (!_topicStreamControllers[topicName]!.isClosed) {
      _topicStreamControllers[topicName]!.add(msg);
    }
  }

  // Publish to a topic
  void publish({
    required String topicName,
    required String messageType,
    required Map<String, dynamic> message
  }) {
    // Get or create the topic
    final topic = getOrCreateTopic(
      name: topicName,
      messageType: messageType
    );

    // Publish message
    topic.publish(message);
  }

  // Unsubscribe from a topic
  void unsubscribeFromTopic(String topicName) {
    if (_topicSubscriptions.containsKey(topicName)) {
      _topicSubscriptions[topicName]!.unsubscribe();
      _topicSubscriptions.remove(topicName);
    }

    if (_topicStreamControllers.containsKey(topicName)) {
      if (!_topicStreamControllers[topicName]!.isClosed) {
        _topicStreamControllers[topicName]!.close();
      }
      _topicStreamControllers.remove(topicName);
    }

    // Note: We're not removing from _topics here to allow reuse
    // Topics will be cleaned up when the client is closed
  }

  // Access ROS instance
  Ros get ros => _ros;

  // Access status stream
  Stream<Status> get statusStream => _ros.statusStream;
}