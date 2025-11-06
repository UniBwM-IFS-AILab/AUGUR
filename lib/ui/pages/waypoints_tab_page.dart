import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:rational/rational.dart';
import 'package:augur/ui/widgets/waypoints_tab/waypoints_map_widget.dart';
import 'package:augur/ui/widgets/waypoints_tab/platform_selection_wheel.dart';
import 'package:augur/ui/widgets/waypoints_tab/height_selection_drawer.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/state/ros_provider.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/core/classes/waypoint.dart';

enum PlanningMode { none, waypoint, trajectory }

class WaypointsTabPage extends ConsumerStatefulWidget {
  const WaypointsTabPage({super.key});

  @override
  ConsumerState<WaypointsTabPage> createState() => _WaypointsTabPageState();
}

class _WaypointsTabPageState extends ConsumerState<WaypointsTabPage> {
  // Takeoff and landing options
  bool _addTakeoff = false;
  bool _addLanding = false;
  String _landingType = 'Simple Land';
  final List<String> _landingOptions = ['Simple Land', 'RTH and Land'];
  PlanningMode _currentMode = PlanningMode.none;
  final List<WaypointWithAltitude> _trajectoryPoints = [];
  OverlayEntry? _overlayEntry;

  // Height selection drawer state
  bool _isHeightDrawerOpen = false;
  int? _selectedTrajectoryPointIndex;
  double _selectedHeight = 50.0;

  // Waypoint altitude preset
  double _waypointAltitude = 50.0;

  // UI hiding state for plan edit mode
  bool _shouldHideUIElements = false;

  // Helper function to convert double to proper fraction representation
  Map<String, int> _doubleToFraction(double value) {
    final rational = Rational.parse(value.toString());
    return {
      'numerator': rational.numerator.toInt(),
      'denominator': rational.denominator.toInt(),
    };
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onEditModeEntered() {
    setState(() {
      _shouldHideUIElements = true;
    });
  }

  void _onEditModeExited() {
    setState(() {
      _shouldHideUIElements = false;
    });
  }

  void _onPlanningModeChanged(PlanningMode mode) {
    setState(() {
      _currentMode = mode;
      _trajectoryPoints.clear();
      // Reset checkboxes to default values when entering planning mode
      _addTakeoff = false;
      _addLanding = false;
      _landingType = 'Simple Land';
    });
    _removeOverlay();
  }

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    // Close height drawer if open
    if (_isHeightDrawerOpen) {
      _closeHeightDrawer();
    }

    // If overlay is open, close it and don't add new waypoints
    if (_overlayEntry != null) {
      setState(() {
        _trajectoryPoints
            .removeLast(); // Remove the last added waypoint that triggered the overlay
      });
      _removeOverlay();
      return;
    }

    if (_currentMode == PlanningMode.waypoint) {
      // Use the selected waypoint altitude
      final waypoint = WaypointWithAltitude(
          position: point, altitudeMeters: _waypointAltitude);
      setState(() {
        _trajectoryPoints.add(waypoint);
      });
      _showPlatformSelectionForWaypoint(tapPosition, waypoint);
    } else if (_currentMode == PlanningMode.trajectory) {
      // Inherit altitude from the last trajectory point if one exists
      final double defaultAltitude = _trajectoryPoints.isNotEmpty
          ? _trajectoryPoints.last.altitudeMeters
          : 50.0; // Default to 50m if no previous points (instead of 10m)

      final waypoint = WaypointWithAltitude(
          position: point, altitudeMeters: defaultAltitude);
      setState(() {
        _trajectoryPoints.add(waypoint);
      });
    }
  }

  void _showPlatformSelectionForWaypoint(
      TapPosition tapPosition, WaypointWithAltitude waypoint) {
    _removeOverlay();

    final platformsData = ref.read(platformDataProvider);
    final platforms = platformsData.asData?.value ?? [];
    final platformNames = platforms.map((p) => p.platformId).toList();

    // If no platforms are available, don't show the selection wheel at all
    if (platformNames.isEmpty) {
      setState(() {
        _trajectoryPoints.removeLast(); // Remove the last added waypoint
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No platforms available to send waypoint to'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Add "Any Drone" option to the platform list
    final platformsWithAnyOption = [...platformNames, 'Any Drone'];

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Semi-transparent background that allows taps to pass through to markers
            Positioned.fill(
              child: IgnorePointer(
                ignoring:
                    true, // This allows taps to pass through to the map and markers
                child: Container(
                  color: Colors.black.withAlpha(
                      26), // Very light background to indicate overlay (0.1 * 255 = 26)
                ),
              ),
            ),
            // Platform selection wheel
            Positioned(
              left: tapPosition.global.dx - 75,
              top: tapPosition.global.dy - 75,
              child: PlatformSelectionWheel(
                platformIDs: platformsWithAnyOption,
                onPlatformSelected: (platformId) {
                  _sendWaypointToPlatform(platformId.toString(), waypoint);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(platformId == 'Any Drone'
                          ? 'Send Waypoint to Any Available Drone'
                          : 'Send Waypoint to Platform with ID: $platformId'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                onClose: () {
                  setState(() {
                    _trajectoryPoints
                        .removeLast(); // Remove the last added waypoint
                  });
                  _onPlanningModeChanged(PlanningMode.none);
                  _removeOverlay();
                },
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _finishTrajectoryPlanning() {
    if (_trajectoryPoints.length >= 2) {
      _showPlatformSelectionForTrajectory();
    }
  }

  void _showPlatformSelectionForTrajectory() {
    final platformsData = ref.read(platformDataProvider);
    final platforms = platformsData.asData?.value ?? [];
    final platformNames = platforms.map((p) => p.platformId).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Select Platform for Trajectory',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 180,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (platformNames.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No platforms available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else ...[
                  // Add "Any Drone" button if there are platforms available
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        onPressed: () {
                          _sendTrajectoryToPlatform(
                              'Any Drone', _trajectoryPoints);
                          Navigator.of(context).pop();
                          _onPlanningModeChanged(PlanningMode.none);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Send Trajectory to Any Available Drone'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: const Text('Any Drone'),
                      ),
                    ),
                  ),
                  // Individual platform buttons
                  ...platformNames.map((platformId) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            onPressed: () {
                              _sendTrajectoryToPlatform(
                                  platformId, _trajectoryPoints);
                              Navigator.of(context).pop();
                              _onPlanningModeChanged(PlanningMode.none);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Send Trajectory to Platform with ID: $platformId'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: Text(platformId),
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sendWaypointToPlatform(
      String platformId, WaypointWithAltitude waypoint) {
    debugPrint(
        'Sending waypoint to $platformId: ${waypoint.position.latitude}, ${waypoint.position.longitude}, altitude: ${waypoint.altitudeMeters}m');

    List<Map<String, dynamic>> actionInstances = [];
    int actionId = 0;

    // Check if "Any Drone" was selected
    final bool isAnyDrone = platformId == 'Any Drone';
    final String actualPlatformId = isAnyDrone ? '' : platformId;

    // Add takeoff action if selected
    if (_addTakeoff) {
      actionInstances.add({
        'id': actionId,
        'action_name': 'take_off',
        'task_id': actionId,
        'parameters': [
          {
            'symbol_atom': isAnyDrone ? [] : [actualPlatformId],
            'int_atom': [],
            'real_atom': [],
            'boolean_atom': [],
          },
          {
            'symbol_atom': [],
            'int_atom': [],
            'real_atom': [
              {
                ..._doubleToFraction(10.0),
              }
            ],
            'boolean_atom': [],
          },
        ],
        'status': 'INACTIVE',
      });
      actionId++;
    }

    // Add fly_step_3D action for the waypoint
    actionInstances.add({
      'id': actionId,
      'action_name': 'fly_step_3D',
      'task_id': actionId,
      'parameters': [
        {
          'symbol_atom': isAnyDrone ? [] : [actualPlatformId],
          'int_atom': [],
          'real_atom': [],
          'boolean_atom': [],
        },
        {
          'symbol_atom': [],
          'int_atom': [],
          'real_atom': [
            {
              ..._doubleToFraction(waypoint.position.latitude),
            }
          ],
          'boolean_atom': [],
        },
        {
          'symbol_atom': [],
          'int_atom': [],
          'real_atom': [
            {
              ..._doubleToFraction(waypoint.position.longitude),
            }
          ],
          'boolean_atom': [],
        },
        {
          'symbol_atom': [],
          'int_atom': [],
          'real_atom': [
            {
              ..._doubleToFraction(waypoint.altitudeMeters),
            }
          ],
          'boolean_atom': [],
        },
      ],
      'status': 'INACTIVE',
    });
    actionId++;

    // Add landing action if selected
    if (_addLanding) {
      if (_landingType == 'RTH and Land') {
        // Add fly_step_3D to home position
        actionInstances.add({
          'id': actionId,
          'action_name': 'fly_step_3D',
          'task_id': actionId,
          'parameters': [
            {
              'symbol_atom': isAnyDrone ? [] : [actualPlatformId],
              'int_atom': [],
              'real_atom': [],
              'boolean_atom': [],
            },
            {
              'symbol_atom': isAnyDrone ? ["home"] : ["home_$actualPlatformId"],
              'int_atom': [],
              'real_atom': [],
              'boolean_atom': [],
            }
          ],
          'status': 'INACTIVE',
        });
        actionId++;
      }

      // Add land action
      actionInstances.add({
        'id': actionId,
        'action_name': 'land',
        'task_id': actionId,
        'parameters': [
          {
            'symbol_atom': isAnyDrone ? [] : [actualPlatformId],
            'int_atom': [],
            'real_atom': [],
            'boolean_atom': [],
          },
        ],
        'status': 'INACTIVE',
      });
    }

    // Create Plan message - omit platform_id if "Any Drone" was selected
    final Map<String, dynamic> planMessage = {
      'team_id': 'drone_team',
      'priority': 1,
      'plan_id': 0,
      'status': 'INACTIVE',
      'tasks': actionInstances,
      'actions': actionInstances,
    };

    // Only add platform_id if not "Any Drone"
    if (!isAnyDrone) {
      planMessage['platform_id'] = actualPlatformId;
    }

    ref.read(rosClientProvider.notifier).publishToTopic(
          topicName: '/add_plan',
          messageType: 'auspex_msgs/msg/Plan',
          message: planMessage,
        );
  }

  void _sendTrajectoryToPlatform(
      String platformId, List<WaypointWithAltitude> trajectory) {
    debugPrint('Sending trajectory to $platformId: ${trajectory.length} points');

    List<Map<String, dynamic>> actionInstances = [];
    int actionId = 0;

    // Check if "Any Drone" was selected
    final bool isAnyDrone = platformId == 'Any Drone';
    final String actualPlatformId = isAnyDrone ? '' : platformId;

    // Add takeoff action if selected
    if (_addTakeoff) {
      actionInstances.add({
        'id': actionId,
        'action_name': 'take_off',
        'task_id': actionId,
        'parameters': [
          {
            'symbol_atom': isAnyDrone ? [] : [actualPlatformId],
            'int_atom': [],
            'real_atom': [],
            'boolean_atom': [],
          },
          {
            'symbol_atom': [],
            'int_atom': [],
            'real_atom': [
              {
                ..._doubleToFraction(10.0),
              }
            ],
            'boolean_atom': [],
          },
        ],
        'status': 'INACTIVE',
      });
      actionId++;
    }

    // Add fly_step_3D action for each waypoint in the trajectory
    for (final waypoint in trajectory) {
      actionInstances.add({
        'id': actionId,
        'action_name': 'fly_step_3D',
        'task_id': actionId,
        'parameters': [
          {
            'symbol_atom': isAnyDrone ? [] : [actualPlatformId],
            'int_atom': [],
            'real_atom': [],
            'boolean_atom': [],
          },
          {
            'symbol_atom': [],
            'int_atom': [],
            'real_atom': [
              {
                ..._doubleToFraction(waypoint.position.latitude),
              }
            ],
            'boolean_atom': [],
          },
          {
            'symbol_atom': [],
            'int_atom': [],
            'real_atom': [
              {
                ..._doubleToFraction(waypoint.position.longitude),
              }
            ],
            'boolean_atom': [],
          },
          {
            'symbol_atom': [],
            'int_atom': [],
            'real_atom': [
              {
                ..._doubleToFraction(waypoint.altitudeMeters),
              }
            ],
            'boolean_atom': [],
          },
        ],
        'status': 'INACTIVE',
      });
      actionId++;
    }

    // Add landing action if selected
    if (_addLanding) {
      if (_landingType == 'RTH and Land') {
        // Add fly_step_3D to home position
        actionInstances.add({
          'id': actionId,
          'action_name': 'fly_step_3D',
          'task_id': actionId,
          'parameters': [
            {
              'symbol_atom': isAnyDrone ? [] : [actualPlatformId],
              'int_atom': [],
              'real_atom': [],
              'boolean_atom': [],
            },
            {
              'symbol_atom': isAnyDrone ? ["home"] : ["home_$actualPlatformId"],
              'int_atom': [],
              'real_atom': [],
              'boolean_atom': [],
            }
          ],
          'status': 'INACTIVE',
        });
        actionId++;
      }

      // Add land action
      actionInstances.add({
        'id': actionId,
        'action_name': 'land',
        'task_id': actionId,
        'parameters': [
          {
            'symbol_atom': isAnyDrone ? [] : [actualPlatformId],
            'int_atom': [],
            'real_atom': [],
            'boolean_atom': [],
          },
        ],
        'status': 'INACTIVE',
      });
    }

    // Create Plan message - omit platform_id if "Any Drone" was selected
    final Map<String, dynamic> planMessage = {
      'team_id': 'drone_team',
      'priority': 1,
      'plan_id': 0,
      'status': 'INACTIVE',
      'tasks': actionInstances,
      'actions': actionInstances,
    };

    // Only add platform_id if not "Any Drone"
    if (!isAnyDrone) {
      planMessage['platform_id'] = actualPlatformId;
    }

    ref.read(rosClientProvider.notifier).publishToTopic(
          topicName: '/add_plan',
          messageType: 'auspex_msgs/msg/Plan',
          message: planMessage,
        );
  }

  List<Polyline> _createTrajectoryPolylines() {
    if (_trajectoryPoints.length < 2) {
      return [];
    }

    return [
      Polyline(
        points: _trajectoryPoints.map((w) => w.position).toList(),
        color: Colors.blue,
        strokeWidth: 3.0,
        pattern: const StrokePattern.solid(),
      ),
    ];
  }

  void _onPlanningMarkerTapped(WaypointWithAltitude waypoint) {
    // Only handle trajectory point taps to open height drawer
    if (_currentMode == PlanningMode.trajectory) {
      final index =
          _trajectoryPoints.indexWhere((w) => w.position == waypoint.position);
      if (index != -1) {
        setState(() {
          _selectedTrajectoryPointIndex = index;
          _selectedHeight = waypoint.altitudeMeters;
          _isHeightDrawerOpen = true;
        });
      }
    }
    // Waypoints don't have height adjustment anymore
  }

  void _closeHeightDrawer() {
    setState(() {
      _isHeightDrawerOpen = false;
      _selectedTrajectoryPointIndex = null;
    });
  }

  void _updateTrajectoryPointHeight(double newHeight) {
    if (_selectedTrajectoryPointIndex != null) {
      setState(() {
        _trajectoryPoints[_selectedTrajectoryPointIndex!] =
            _trajectoryPoints[_selectedTrajectoryPointIndex!]
                .copyWith(altitudeMeters: newHeight);
        _selectedHeight = newHeight;
      });
    }
  }

  Widget _buildHeightSelectionDrawer() {
    if (!_isHeightDrawerOpen || _selectedTrajectoryPointIndex == null) {
      return const SizedBox.shrink();
    }

    return HeightSelectionDrawer(
      waypointIndex: _selectedTrajectoryPointIndex!,
      currentHeight: _selectedHeight,
      onHeightChanged: (height) {
        setState(() {
          _selectedHeight = height;
        });
        _updateTrajectoryPointHeight(height);
      },
      onClose: _closeHeightDrawer,
      onDelete: () {
        setState(() {
          if (_selectedTrajectoryPointIndex != null &&
              _selectedTrajectoryPointIndex! < _trajectoryPoints.length) {
            _trajectoryPoints.removeAt(_selectedTrajectoryPointIndex!);
          }
        });
        _closeHeightDrawer();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch platform data to ensure it's loaded and available for callbacks
    // ignore: unused_local_variable
    final platformsData = ref.watch(platformDataProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Map view with planning points
          WaypointsMapWidget(
            onMapTapped: _onMapTapped,
            planningPoints: _trajectoryPoints,
            planningPolylines: _createTrajectoryPolylines(),
            onPlanningMarkerTapped: _onPlanningMarkerTapped,
            onEditModeEntered: _onEditModeEntered,
            onEditModeExited: _onEditModeExited,
          ),

          // Planning control panel
          if (!_shouldHideUIElements)
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                width: 230,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.route, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'Waypoint Planning',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentMode == PlanningMode.none) ...[
                            const Text(
                              'Select Planning Mode:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Planning mode buttons
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _onPlanningModeChanged(
                                    PlanningMode.waypoint),
                                icon: const Icon(Icons.place, size: 18),
                                label: const Text('Plan Waypoint'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _onPlanningModeChanged(
                                    PlanningMode.trajectory),
                                icon: const Icon(Icons.timeline, size: 18),
                                label: const Text('Plan Trajectory'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ] else if (_currentMode == PlanningMode.waypoint) ...[
                            const Text(
                              'Waypoint Planning Mode',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap on map to place waypoints',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Takeoff and Landing checkboxes
                            Row(
                              children: [
                                Transform.scale(
                                  scale: 0.8,
                                  child: Checkbox(
                                    value: _addTakeoff,
                                    onChanged: (val) {
                                      setState(() {
                                        _addTakeoff = val ?? false;
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const Text('Add Takeoff',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Transform.scale(
                                  scale: 0.8,
                                  child: Checkbox(
                                    value: _addLanding,
                                    onChanged: (val) {
                                      setState(() {
                                        _addLanding = val ?? false;
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const Text('Add Land:',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: IgnorePointer(
                                    ignoring: !_addLanding,
                                    child: Opacity(
                                      opacity: _addLanding ? 1.0 : 0.5,
                                      child: DropdownButton<String>(
                                        value: _landingType,
                                        isDense: true,
                                        isExpanded: true,
                                        items: _landingOptions
                                            .map((option) => DropdownMenuItem(
                                                  value: option,
                                                  child: Text(option,
                                                      style: const TextStyle(
                                                          fontSize: 11)),
                                                ))
                                            .toList(),
                                        onChanged: _addLanding
                                            ? (val) {
                                                setState(() {
                                                  _landingType =
                                                      val ?? _landingOptions[0];
                                                });
                                              }
                                            : null,
                                        underline: Container(
                                            height: 1,
                                            color: AppColors.primary
                                                .withAlpha(128)),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Height preset selection
                            const Text(
                              'Waypoint Altitude:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                10.0,
                                25.0,
                                30.0,
                                40.0,
                                50.0,
                                75.0,
                                80.0,
                                100.0
                              ].map((height) {
                                final isSelected = _waypointAltitude == height;
                                return ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _waypointAltitude = height;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? AppColors.primary
                                        : Colors.grey[200],
                                    foregroundColor: isSelected
                                        ? Colors.white
                                        : Colors.black54,
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.grey[300]!,
                                      width: 1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: Text(
                                    '${height.toInt()}m',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _onPlanningModeChanged(PlanningMode.none),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ] else if (_currentMode ==
                              PlanningMode.trajectory) ...[
                            const Text(
                              'Trajectory Planning Mode',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap on map to add trajectory points.\nTap markers to adjust height.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Points: ${_trajectoryPoints.length}${_trajectoryPoints.length >= 2 ? " (Ready to finish)" : " (Min 2 required)"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            // Takeoff and Landing checkboxes
                            Row(
                              children: [
                                Transform.scale(
                                  scale: 0.8,
                                  child: Checkbox(
                                    value: _addTakeoff,
                                    onChanged: (val) {
                                      setState(() {
                                        _addTakeoff = val ?? false;
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const Text('Add Takeoff',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Transform.scale(
                                  scale: 0.8,
                                  child: Checkbox(
                                    value: _addLanding,
                                    onChanged: (val) {
                                      setState(() {
                                        _addLanding = val ?? false;
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const Text('Add Land:',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: IgnorePointer(
                                    ignoring: !_addLanding,
                                    child: Opacity(
                                      opacity: _addLanding ? 1.0 : 0.5,
                                      child: DropdownButton<String>(
                                        value: _landingType,
                                        isDense: true,
                                        isExpanded: true,
                                        items: _landingOptions
                                            .map((option) => DropdownMenuItem(
                                                  value: option,
                                                  child: Text(option,
                                                      style: const TextStyle(
                                                          fontSize: 11)),
                                                ))
                                            .toList(),
                                        onChanged: _addLanding
                                            ? (val) {
                                                setState(() {
                                                  _landingType =
                                                      val ?? _landingOptions[0];
                                                });
                                              }
                                            : null,
                                        underline: Container(
                                            height: 1,
                                            color: AppColors.primary
                                                .withAlpha(128)),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _trajectoryPoints.length >= 2
                                        ? () {
                                            if (_isHeightDrawerOpen) {
                                              _closeHeightDrawer();
                                            }
                                            _finishTrajectoryPlanning();
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Finish'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (_isHeightDrawerOpen) {
                                        _closeHeightDrawer();
                                      }
                                      _onPlanningModeChanged(PlanningMode.none);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _buildHeightSelectionDrawer(),
        ],
      ),
    );
  }
}
