import 'package:roslibdart/roslibdart.dart';

class RosConnection {
  final String url; // ROS WebSocket URL
  late Ros _ros;    // ROS instance
  bool _isConnected = false;

  RosConnection({required this.url}) {
    _ros = Ros(url: url);
    _ros.statusStream.listen(onStatusUpdate);
  }

  // Connect to the ROS bridge
  void connect() {
    if (!_isConnected) {
      _ros.connect();
    }
  }

  // Disconnect from ROS bridge
  void close() {
    _ros.close();
  }

  // Check connection status
  bool isConnected() => _isConnected;

  // Handle connection status updates
  void onStatusUpdate(Status status) {
    _isConnected = (status == Status.connected);
  }

  // Create a topic
  Topic createTopic({
    required String name,
    required String type,
    int queueSize = 10,
    int queueLength = 10,
    bool reconnectOnClose = true,
  }) {
    return Topic(
      ros: _ros,
      name: name,
      type: type,
      reconnectOnClose: reconnectOnClose,
      queueLength: queueLength,
      queueSize: queueSize,
    );
  }

  // Access ROS instance
  Ros get ros => _ros;

  // Access status stream
  Stream<Status> get statusStream => _ros.statusStream;
}