import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/ui/pages/camera_stream_page.dart';
import 'package:augur/ui/pages/map_page.dart';
import 'package:augur/ui/widgets/utility_widgets/circular_menu.dart';
import 'package:augur/ui/widgets/map_page/platform_selection_wheel.dart';
import 'package:augur/ui/widgets/utility_widgets/connection_lost_dialog.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/state/ros_provider.dart';

class MainPage extends ConsumerStatefulWidget  {
  final String ip;
  const MainPage({super.key, required this.ip});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  late List<String> platformNames = [];

  double dividerPosition = 0.75; // Initial position of the divider (50%)
  OverlayEntry? _overlayEntry;
  OverlayEntry? _overlayEntryDroneSelection;
  bool isOffline = false;
  bool isTrajectoryOn = false;

  late  TextEditingController _ipController; // Default IP


  @override
  void initState(){
    super.initState();
    _ipController = TextEditingController(text: widget.ip);
    Future.microtask(() async {
      ref.read(redisClientProvider.notifier).initialize(
        widget.ip,
        showConnectionLostDialog);
      ref.read(rosClientProvider.notifier).initialize(
        'ws://${widget.ip}:9090',
        () => setState(() {}),
      );

      await ref.read(rosClientProvider.notifier).connect();
      await ref.read(redisClientProvider.notifier).connect();
    });
  }

   @override
  void dispose() {
    super.dispose();
  }

  Future<bool> _connectToDatabase() async {
    try {
      await ref.read(redisClientProvider.notifier).connect();
      ref.read(redisClientProvider.notifier).setTrajectoryMode(isTrajectoryOn);
      return true;
    } catch (e) {
      print("Connection failed: $e");
      return false;
    }
  }

  void showConnectionLostDialog() async {
    await ref.read(redisClientProvider.notifier).disconnect();
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
          numberOfPlatforms: platformNames.length,  // Specify the number of platforms dynamically
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
      ref.read(redisClientProvider.notifier).setTrajectoryMode(isTrajectoryOn);
  }

  @override
  Widget build(BuildContext context) {
    //return widget
    final platformNamesData = ref.watch(platformNamesDataProvider);
    platformNamesData.when(
      data: (data) => platformNames = data,
      loading: () => {},
      error: (err, _) => print("Error loading platform names: $err"),
    );

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
                          backgroundColor: AppColors.primary,
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
                color: AppColors.primary,
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
                color: AppColors.primary,
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