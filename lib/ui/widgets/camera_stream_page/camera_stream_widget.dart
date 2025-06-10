import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/state/ros_provider.dart';
import 'dart:typed_data';

class CameraStreamWidget extends ConsumerStatefulWidget {
  final int selectedDroneIndex;
  final String ipAddress;
  final List<String> platformNames;

  const CameraStreamWidget({
    super.key,
    required this.selectedDroneIndex,
    required this.platformNames,
    required this.ipAddress
  });

  @override
  ConsumerState<CameraStreamWidget> createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends ConsumerState<CameraStreamWidget>
    with AutomaticKeepAliveClientMixin {

  late String cameraStreamPath;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required when using AutomaticKeepAliveClientMixin

    // Watch connection status
    final isConnected = ref.watch(rosConnectionStatusProvider);

    if (widget.selectedDroneIndex == -1 || !isConnected) {
      return const Center(
        child: Text("No connection or no drone selected"),
      );
    }else{
      cameraStreamPath = '${widget.platformNames[widget.selectedDroneIndex]}/raw_camera_stream';
    }

    // Create topic configuration
    final topicConfig = RosTopicConfig(
      topicName: cameraStreamPath,
      messageType: 'auspex_msgs/msg/FrameData',
    );

    // Watch the stream for the configured topic
    final cameraStream = ref.watch(rosTopicStreamProvider(topicConfig));

    return cameraStream.when(
      data: (data) {
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        // Extract image data from ROS message
        try {
          final imageData = data['image_compressed']['data'] as String;
          return _getImageFromBase64(imageData);
        } catch (e) {
          return Center(child: Text("Error processing image: $e"));
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text("Error: $error")),
    );
  }

  Widget _getImageFromBase64(String msg) {
    Uint8List bytes = base64.decode(msg);
    return Center(
      child: Image.memory(
        bytes,
        gaplessPlayback: true,
        fit: BoxFit.fitWidth,
      )
    );
  }

  @override
  bool get wantKeepAlive => true;
}