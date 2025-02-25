import 'package:flutter/material.dart';
import 'package:augur/pages/camera_stream_page.dart';
import 'package:augur/pages/map_page.dart';
import 'package:augur/custom_widgets/circular_menu.dart';
import 'package:latlong2/latlong.dart';
import 'package:augur/custom_widgets/platform_selection_wheel.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:augur/redis_interface/redis_client.dart';
import 'package:augur/utils/connection_lost_dialog.dart'; 

class MainPage extends StatefulWidget {
  final String ip;
  const MainPage({super.key, required this.ip});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late List<Map<String, dynamic>> platformStates = [];
  late List<Map<String, dynamic>> platformTrajectories = [];
  late Map<String, dynamic> platformSearchMission = {};
  late List <Map<String, dynamic>> platformWaypoints = [];
  late List<String> platformNames = [];

  late int numberOfPlatforms = -1;
  double dividerPosition = 0.75; // Initial position of the divider (50%)
  OverlayEntry? _overlayEntry;
  OverlayEntry? _overlayEntryDroneSelection;
  bool isOffline = false;
  bool isTrajectoryOn = false;

  late DataBaseClient _redisClient;
  final TextEditingController _ipController = TextEditingController(text: "127.0.0.1"); // Default IP


  @override
  void initState(){
    super.initState();
    _connectToDatabase();
  }

   @override
  void dispose() {
    _redisClient.disconnect();
    super.dispose();
  }

  Future<bool> _connectToDatabase() async {
    try {
      _redisClient = DataBaseClient(
        redisIp: widget.ip,
      );

      _redisClient.isTrajectoryOn = isTrajectoryOn;

      _redisClient.onPlatformUpdate = (List<Map<String, dynamic>> platformState, List<String> newPlatformNames) {
        setState(() {
          platformStates = platformState;
          platformNames = newPlatformNames;
        });
      };

      _redisClient.onPlatformTrajectoriesUpdate = (List<Map<String, dynamic>> platformTrajectories) {
        setState(() {
          this.platformTrajectories = platformTrajectories;
        });
      };

      _redisClient.onPlatformGeneralUpdate = (Map<String, dynamic> platformSearchMission, List<Map<String, dynamic>> platformWaypoints) {

        setState(() {
          this.platformWaypoints = platformWaypoints;
          this.platformSearchMission = platformSearchMission;
        });
      };
      
      _redisClient.onRetryConnection = () {
        showConnectionLostDialog(); 
      };

      await _redisClient.connect();
      return true;
    } catch (e) {
      print("Connection failed: $e");
      return false;
    }
  }

  void showConnectionLostDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing dialog
      builder: (context) {
        return ConnectionLostDialog(
          ipController: _ipController,
          onReconnect: _connectToDatabase,
          onOffline: () {
            setState(() {platformNames= []; isOffline = true;});
          },
        );
      },
    );
  }

  void _showDroneSelectionMenu(TapPosition tapPosition, LatLng point) {
    final overlay = Overlay.of(context);
    // Overlay the DroneSelectionWheel around the same point
    _overlayEntryDroneSelection = OverlayEntry(
      builder: (context) => Positioned(
        left: tapPosition.global.dx - 125,  // Adjust X position for the larger platform menu
        top: tapPosition.global.dy - 125,   // Adjust Y position for the larger platform menu
        child: PlatformSelectionWheel(
          numberOfPlatforms: numberOfPlatforms,  // Specify the number of platforms dynamically
          onPlatformSelected: (platformIndex) {
            print('Drone $platformIndex selected');
            _removeCircularMenu();  // Close the platform selection menu
          },
          onClose: _removeDroneSelectionCircularMenu,  // Handle menu close
        ),
      ),
    );

    overlay.insert(_overlayEntryDroneSelection!);
  }

  void _showCircularMenu(TapPosition tapPosition, LatLng point){
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: tapPosition.global.dx - 90,  // Adjust X position to center the menu
        top: tapPosition.global.dy - 90,   // Adjust Y position to center the menu
        child: CircularMenu(
          onClose: _removeCircularMenu,
          onDroneSelectionRequested: () {  // Close current menu before showing the platform selection
            _showDroneSelectionMenu(tapPosition, point);  // Show platform selection menu
          },  // Handle menu close
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeCircularMenu() {
    _overlayEntryDroneSelection?.remove();
    _overlayEntryDroneSelection = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
  void _removeDroneSelectionCircularMenu() {
       _overlayEntryDroneSelection?.remove();
    _overlayEntryDroneSelection = null;
  }

  void _onTrajectorySwitchToggled(bool isTrajectorySelected){
      setState(() {
        isTrajectoryOn = isTrajectorySelected;
      });
      _redisClient.isTrajectoryOn = isTrajectorySelected;
      if(!isTrajectorySelected){
        platformTrajectories = [];
      }
  }

  @override
  Widget build(BuildContext context) {
    //init variables
    numberOfPlatforms = platformNames.length;

    //return widget
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: <Widget>[
            // Map widget
            Flexible(
              flex: (dividerPosition * 1000).toInt(),
              child: Stack(
                children: [
                  Container(
                    color: Colors.blue,
                    child: MapPage(
                      showCircularMenuCallback: _showCircularMenu,
                      removeCircularMenuCallback: _removeCircularMenu,
                      onTrajectorySwitchToggled: (isTrajectorySelected) => _onTrajectorySwitchToggled(isTrajectorySelected),
                      platformStates: platformStates,
                      platformTrajectories: platformTrajectories,
                      platformSearchMission:platformSearchMission,
                      platformWaypoints:platformWaypoints,
                      isTrajectoryOn: isTrajectoryOn,
                    ),
                  ), 
                  if (isOffline)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: TextButton(
                        onPressed: () {
                            setState(() => isOffline = false); // Update inside dialog
                            showConnectionLostDialog();
                          },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text("Connect"),
                      ),
                    ),
                ],
              ),
            ),
            // A horizontal line for dividing map and camera
            GestureDetector(
              onPanUpdate: (details) {
                _removeCircularMenu();
                setState(() {
                  dividerPosition += details.delta.dx / constraints.maxWidth;
                  dividerPosition = dividerPosition.clamp(0.01, 0.99);
                });
              },
              child: Container(
                width: 10.0,
                color: Colors.blue,
                child: Center(
                    child: Transform.rotate(
                      angle: 1.5708, // 90 degrees in radians (π/2 or 1.5708 radians)
                      child: const Icon(Icons.drag_handle, size:30.0),
                    ),
                  ),                   
                ),
              ),
            // Widget for the camera Stream
            Flexible(
              flex: ((1 - dividerPosition) * 1000).toInt(),
              child: Container(
                color: Colors.blue,
                child: CameraStreamPage(
                  platformNames: platformNames,
                  ipAddress: widget.ip,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}