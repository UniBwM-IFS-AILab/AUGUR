import 'package:flutter/material.dart';
import 'package:augur/pages/map_widget.dart';
import 'package:augur/custom_widgets/settings_drawer.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class MapPage extends StatefulWidget {
  final Function(TapPosition, LatLng) showCircularMenuCallback; 
  final Function() removeCircularMenuCallback; 
  final Function(bool isTrajectorySelected) onTrajectorySwitchToggled; 
  final List<Map<String, dynamic>> platformStates;
  final List<Map<String, dynamic>> platformTrajectories;
  final Map<String, dynamic> platformSearchMission;
  final List<Map<String, dynamic>> platformWaypoints;
  final bool isTrajectoryOn;
  const MapPage({super.key, 
      required this.showCircularMenuCallback, 
      required this.removeCircularMenuCallback, 
      required this.onTrajectorySwitchToggled, 
      required this.platformStates, 
      required this.platformTrajectories, 
      required this.isTrajectoryOn, 
      required this.platformSearchMission,
      required this.platformWaypoints});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool isSatelliteOn = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Container(
        alignment: Alignment.topRight, // Align to the top right corner
        margin: const EdgeInsets.only(top: 50), // Adjust this value to move it higher or lower
        child: FractionallySizedBox(// This makes the drawer take half of the screen width
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
                platformStates: widget.platformStates,
                platformTrajectories: widget.platformTrajectories,
                platformSearchMission: widget.platformSearchMission,
                platformWaypoints: widget.platformWaypoints,
              ),          
              Positioned(
                top: 10, // Adjust as per your design
                right: 10, // Adjust as per your design
                child: Builder(
                  builder: (BuildContext context) {
                    return IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        widget.removeCircularMenuCallback();
                        Scaffold.of(context).openEndDrawer(); // Opens the right drawer
                      },
                    );
                  },
                ),
              ),
            ],
      ),
      endDrawerEnableOpenDragGesture: false,
    );
  }

}
