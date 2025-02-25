import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:augur/ros/ros_connection.dart';
import 'dart:io';
import 'dart:typed_data';

class CameraStreamWidget extends StatefulWidget {
  final int selectedDroneIndex;
  final String ipAddress;
  const CameraStreamWidget({super.key, required this.selectedDroneIndex, required this.ipAddress});

  @override
  State<CameraStreamWidget> createState() => _CameraStreamWidgetState();
}

class _CameraStreamWidgetState extends State<CameraStreamWidget> with AutomaticKeepAliveClientMixin {
  late Topic _cameraStream; 
  late RosConnection _rosConnection;
  String get droneStreamPath => '/vhcl${widget.selectedDroneIndex}/raw_camera_stream';

  @override
  void initState() {
    super.initState();
    _rosConnection = RosConnection(url: 'ws://${widget.ipAddress}:9090');
    _rosConnection.connect();

    _cameraStream = _rosConnection.createTopic(
    name: droneStreamPath,
    type: 'auspex_msgs/msg/DroneImage',
    );

    _cameraStream.subscribe(subscribeCameraStreamHandler);
  }

  @override
  void didUpdateWidget(CameraStreamWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update the stream if the selected drone index changes
    if (oldWidget.selectedDroneIndex != widget.selectedDroneIndex) {
      _cameraStream.unsubscribe();
      _cameraStream = _rosConnection.createTopic(
        name: droneStreamPath,
        type: 'auspex_msgs/msg/DroneImage',
      );

      if (_rosConnection.isConnected()) {
        _cameraStream.subscribe(subscribeCameraStreamHandler);
      } else {
        // Listen for connection updates and subscribe when connected
        _rosConnection.statusStream.listen((status) {
            if (status == Status.connected) {
              _cameraStream.subscribe(subscribeCameraStreamHandler);
            }
          }
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required when using AutomaticKeepAliveClientMixin

    if (widget.selectedDroneIndex == -1) {
      return const Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
            Text("VIDEO STREAM"),
            Text("State: No Connection."),
            Text("Select Drone to Connect..."),
          ]));
    }
    return (_rosConnection.isConnected() &&  widget.selectedDroneIndex != -1) ? StreamBuilder(
            stream: _cameraStream.subscription,
            builder: (context, AsyncSnapshot<dynamic> snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return _getImageFromBase64(snapshot.data['msg']['image_compressed']['data'] as String);
            },
          )
        : const Center(
            child: Text("No Connection."),
          );
  }


 Widget _getImageFromBase64(String  msg) {  
    Uint8List bytes = base64.decode(msg);
    return Center(
      child: Image.memory(
        bytes,
        gaplessPlayback: true,
        fit: BoxFit.fitWidth,
      )
    );
  }


 // A handler to subscribe to the camera stream. Not used, but if removed subscribe throws an error.
  Future<void> subscribeCameraStreamHandler(Map<String, dynamic> msg) async {
    setState(() {});
  }

  void destroyConnection() async {
    _cameraStream.unsubscribe();
    _rosConnection.close();
    setState(() {});
  }


  @override
  void dispose(){
    _cameraStream.unsubscribe();
    _rosConnection.close();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void saveImageToFile(Uint8List bytes) async {
    final file = File('output_image.png');
    await file.writeAsBytes(bytes);
    print("Image saved to file: ${file.path}");
  }
}
