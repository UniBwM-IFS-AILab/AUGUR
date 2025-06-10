import 'dart:async';

import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/ui/widgets/map_page/mic_button.dart';
import 'package:augur/ui/widgets/utility_widgets/speech_bubble.dart';
import 'package:flutter/material.dart';
import 'package:augur/ui/widgets/map_page/map_widget.dart';
import 'package:augur/ui/widgets/map_page/settings_drawer.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/state/ros_provider.dart';

enum CommandState { start, cancel, rth }

class MapPage extends ConsumerStatefulWidget {
  final Function(TapPosition, LatLng) showCircularMenuCallback;
  final Function() removeCircularMenuCallback;
  final Function(bool isTrajectorySelected) onTrajectorySwitchToggled;
  final bool isTrajectoryOn;
  const MapPage({super.key,
      required this.showCircularMenuCallback,
      required this.removeCircularMenuCallback,
      required this.onTrajectorySwitchToggled,
      required this.isTrajectoryOn,
});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  bool isSatelliteOn = false;
  final StreamController<String> _textStreamController = StreamController<String>.broadcast();
  CommandState _commandState = CommandState.start;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Container(
        alignment: Alignment.topRight,
        margin: const EdgeInsets.only(top: 50),
        child: FractionallySizedBox(
          heightFactor: 0.5,
          child: SettingsDrawer(
            onSatelliteSwitchToggled: (isSatelliteSelected) {
                setState(() {
                  isSatelliteOn = isSatelliteSelected;// Update the selected index
                });
              },
            isSatelliteOn:isSatelliteOn,
            onTrajectorySwitchToggled: (isTrajectorySelected) {
              setState(() {
                widget.onTrajectorySwitchToggled(isTrajectorySelected);
              });
            },
            isTrajectoryOn:widget.isTrajectoryOn,
          ),
        ),
      ),
      body: Stack(
        children: [
              MapWidget(
                isSatelliteSwitchOn: isSatelliteOn,
                showCircularMenuCallback: widget.showCircularMenuCallback,
                removeCircularMenuCallback: widget.removeCircularMenuCallback,
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Builder(
                  builder: (BuildContext context) {
                    return IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        widget.removeCircularMenuCallback();
                        Scaffold.of(context).openEndDrawer();
                      },
                    );
                  },
                ),
              ),
              Stack(
                children: [
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _handleCommand(ref);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.text),
                          child: Text(_getCommandText()),
                        ),
                        SizedBox(
                          width: 200,
                          child: SpeechBubble(
                            textStream: _textStreamController.stream,
                            onAccept: (modifiedText) {
                              print("Accepted text: $modifiedText");
                          },),
                        ),
                        const SizedBox(height: 20),
                        MicButton(textStreamController: _textStreamController),
                      ],
                    ),
                  ),
                ],
              ),
            ],
      ),
      endDrawerEnableOpenDragGesture: false,
    );
  }

  String _getCommandText() {
    switch (_commandState) {
      case CommandState.start:
        return "Start";
      case CommandState.cancel:
        return "Cancel";
      case CommandState.rth:
        return "RTH";
    }
  }

  // Handles button press & sends corresponding command, then cycles state.
  void _handleCommand(WidgetRef ref) {
    if (_commandState == CommandState.start) {
      _sendCommand(ref, 4); // Send command for "Start"
      setState(() {
        _commandState = CommandState.cancel;
      });
    } else if (_commandState == CommandState.cancel) {
      _sendCommand(ref, 1); // Send command for "Cancel"
      setState(() {
        _commandState = CommandState.rth;
      });
    } else if (_commandState == CommandState.rth) {
      _sendCommand(ref, 8); // Send command for "RTH"
      setState(() {
        _commandState = CommandState.start;
      });
    }
  }

  // Publishes a command using the ROS provider
  void _sendCommand(WidgetRef ref, int command) {
    // Access the ROS client through the provider
    ref.read(rosClientProvider.notifier).publishToTopic(
      topicName: '/planner_command',
      messageType: 'auspex_msgs/msg/UserCommand',
      message: {
        'user_command': command,
      },
    );
  }

}
