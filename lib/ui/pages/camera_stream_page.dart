import 'package:flutter/material.dart';
import 'package:augur/ui/widgets/camera_stream_page/camera_drawer/floating_menu_button.dart';
import 'package:augur/ui/widgets/camera_stream_page/camera_drawer/menu_drawer.dart';

import 'package:augur/ui/widgets/camera_stream_page/camera_stream_widget.dart';

class CameraStreamPage extends StatefulWidget {
  final List<String> platformNames;
  final String ipAddress;
  const CameraStreamPage({super.key, required this.platformNames, required this.ipAddress});

  @override
  State<CameraStreamPage> createState() => _CameraStreamPageState();
}

class _CameraStreamPageState extends State<CameraStreamPage> {
  int selectedDroneIndex = -1;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: MenuDrawer(
        platformNames:widget.platformNames,
        onPlatformSelected: (index) {
            if(selectedDroneIndex != index){
              setState(() {
                selectedDroneIndex = index; // Update the selected index
              });
            }
          },
        selectedPlatformIndex:selectedDroneIndex,
        ),
      body: Stack(
        children: [
              CameraStreamWidget(selectedDroneIndex: selectedDroneIndex, platformNames:widget.platformNames, ipAddress: widget.ipAddress,),
              const FloatingMenuButton()
            ],
      ),
      drawerEnableOpenDragGesture: false,
    );
  }
}