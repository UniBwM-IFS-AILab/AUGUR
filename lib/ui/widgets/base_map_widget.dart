// Base Map widget containing all common map functionality
import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/state/settings_provider.dart';
import 'package:augur/config/api_keys.dart';
import 'package:augur/config/map_config.dart';
import 'package:augur/ui/widgets/plan_drawer.dart';
import 'package:augur/ui/widgets/mission_drawer.dart';
import 'package:augur/ui/widgets/object_drawer.dart';
import 'package:augur/core/classes/platform.dart';
import 'package:augur/core/classes/waypoint.dart';
import 'package:augur/core/classes/plan.dart';
import 'package:augur/core/classes/mission.dart';
import 'package:augur/core/classes/detected_object.dart';

abstract class BaseMapWidget extends ConsumerStatefulWidget {
  final Function(TapPosition, LatLng) onMapTapped;
  final Function(String routeId, int waypointIndex, LatLng position)?
      onWaypointTapped;
  final Function(bool isDrawerOpen)? onDrawerStateChanged;
  final Function()? onEditModeEntered; // Callback when edit mode starts
  final Function()? onEditModeExited; // Callback when edit mode ends
  final Function(Map<String, dynamic> planData)?
      onPlanSelected; // Callback to open plan drawer externally

  const BaseMapWidget({
    super.key,
    required this.onMapTapped,
    this.onWaypointTapped,
    this.onDrawerStateChanged,
    this.onEditModeEntered,
    this.onEditModeExited,
    this.onPlanSelected,
  });
}

abstract class BaseMapWidgetState<T extends BaseMapWidget>
    extends ConsumerState<T> {
  // Map controller and core markers/overlays
  final MapController mapController = MapController();
  final List<Marker> persistentMarkers = [];
  final List<Marker> platformMarkers = [];
  final List<Marker> waypointMarkers = [];
  final List<Marker> detectedObjectMarkers = [];

  final List<Polyline> routeLines = [];
  final List<Polyline> trajectories = [];
  final List<Polygon> areas = [];

  String routeId = '';
  int waypointIndex = 0;

  // Plan drawer state
  bool isPlanDrawerVisible = false;
  Plan? selectedPlan;
  int? selectedOriginalWaypointIndex;

  // Mission drawer state
  bool isMissionDrawerVisible = false;
  Mission? selectedMission;

  // Object drawer state
  bool isObjectDrawerVisible = false;
  DetectedObject? selectedDetectedObject;

  // Edit mode waypoints and polylines for map display
  List<Marker> editWaypointMarkers = [];
  List<Polyline> editWaypointPolylines = [];
  bool isInPlanEditMode = false;
  bool shouldHideUIElements =
      false; // New state for hiding UI elements during plan edit

  // Store current plans for easy access
  List<Plan> _currentPlans = [];

  // Store current missions for easy access
  List<Mission> _currentMissions = [];

  // Store current detected objects for easy access
  List<DetectedObject> _currentDetectedObjects = [];

  // Track last update timestamps for change detection
  Map<int, DateTime> _planLastUpdated = {};
  Map<String, DateTime> _missionLastUpdated = {};

  // Store plan data for each platform
  final Map<String, Map<String, dynamic>> platformPlans = {};

  // Plan drawer key to access methods
  final GlobalKey<PlanDrawerState> _planDrawerKey =
      GlobalKey<PlanDrawerState>();

  // Map configuration
  final Set<String> platformsWithHomeSet = <String>{};
  bool _hasAutoFocused = false; // Track if we've already auto-focused
  final String satelliteUrlTemplate =
      "https://api.mapbox.com/styles/v1/${ApiKeys.mapboxUsername}/clxiwfe7v009x01qr76hhekeo/tiles/256/{z}/{x}/{y}@2x?access_token=${ApiKeys.satelliteMapAccessToken}";

  // Use OSM tile configuration from MapConfig
  int currentTileUrlIndex = MapConfig.defaultTileServerIndex;
  String openstreetsUrlTemplate = MapConfig.defaultTileUrl;
  String currentUrlTemplate = MapConfig.defaultTileUrl;

  @override
  void initState() {
    super.initState();
    updateTileSource();
  }

  void updateTileSource() {
    openstreetsUrlTemplate = MapConfig.getTileUrl(currentTileUrlIndex);
  }

  // Method to open plan drawer externally - now accepts Plan object
  void openPlanDrawer(Plan plan) {
    setState(() {
      isPlanDrawerVisible = true;
      selectedPlan = plan;
    });
    // Notify parent about drawer opening
    widget.onDrawerStateChanged?.call(true);
  }

  // Method to switch to next tile server (useful for debugging or error recovery)
  void switchToNextTileServer() {
    setState(() {
      currentTileUrlIndex =
          (currentTileUrlIndex + 1) % MapConfig.osmTileServers.length;
      updateTileSource();
      debugPrint(
          'Switched to tile server: ${MapConfig.getTileUrl(currentTileUrlIndex)}');
    });
  }

  void safeMapMove(LatLng center, double zoom) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          mapController.move(center, zoom);
        } catch (e) {
          debugPrint('MapController not ready yet: $e');
        }
      }
    });
  }

  // Abstract methods for child widgets to override
  List<Widget> buildAdditionalLayers();

  // Base map tap behavior - can be overridden by child classes
  void onMapTap(TapPosition tapPosition, LatLng point) {
    // If we're in plan edit mode, add waypoint to the plan drawer
    if (isInPlanEditMode && isPlanDrawerVisible) {
      _planDrawerKey.currentState?.addWaypointFromMap(point);
      return;
    }

    // Check if tap is on any detected object marker
    final tappedObject = _findTappedDetectedObject(point);
    if (tappedObject != null) {
      _showObjectDrawer(tappedObject);
      return;
    }

    // Check if tap is within any mission area
    final tappedArea = _findTappedArea(point);
    if (tappedArea != null) {
      _showMissionDrawer(tappedArea);
      return;
    }

    // Close any open drawers if no area was tapped
    bool wasDrawerVisible = isPlanDrawerVisible || isMissionDrawerVisible || isObjectDrawerVisible;
    setState(() {
      isPlanDrawerVisible = false;
      selectedPlan = null;
      selectedOriginalWaypointIndex = null;
      isMissionDrawerVisible = false;
      selectedMission = null;
      isObjectDrawerVisible = false;
      selectedDetectedObject = null;
    });
    // Notify parent if drawer was closed
    if (wasDrawerVisible) {
      widget.onDrawerStateChanged?.call(false);
    }
  }

  /// Find area polygon that contains the tapped point
  Polygon? _findTappedArea(LatLng point) {
    for (var area in areas) {
      if (_isPointInPolygon(point, area.points)) {
        return area;
      }
    }
    return null;
  }

  /// Check if a point is inside a polygon using ray casting algorithm
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      if (((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude)) &&
          (point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Show mission drawer for the tapped area
  void _showMissionDrawer(Polygon tappedArea) {
    final mission = _findMissionForArea(tappedArea.label ?? '');
    if (mission != null) {
      setState(() {
        selectedMission = mission;
        isMissionDrawerVisible = true;
        // Close plan drawer if open
        isPlanDrawerVisible = false;
        selectedPlan = null;
        selectedOriginalWaypointIndex = null;
        // Close object drawer if open
        isObjectDrawerVisible = false;
        selectedDetectedObject = null;
      });
      widget.onDrawerStateChanged?.call(true);
    }
  }

  /// Find detected object marker that was tapped
  DetectedObject? _findTappedDetectedObject(LatLng point) {
    // Check if the tap is close to any detected object marker
    const double tapRadius = 0.0001; // roughly 10 meters in degrees

    for (var detectedObject in _currentDetectedObjects) {
      final objectPosition = detectedObject.position;
      final distance = (objectPosition.latitude - point.latitude).abs() +
                      (objectPosition.longitude - point.longitude).abs();
      
      if (distance <= tapRadius) {
        return detectedObject;
      }
    }
    return null;
  }

  /// Show object drawer for the tapped detected object
  void _showObjectDrawer(DetectedObject detectedObject) {
    setState(() {
      selectedDetectedObject = detectedObject;
      isObjectDrawerVisible = true;
      // Close other drawers if open
      isPlanDrawerVisible = false;
      selectedPlan = null;
      selectedOriginalWaypointIndex = null;
      isMissionDrawerVisible = false;
      selectedMission = null;
    });
    widget.onDrawerStateChanged?.call(true);
  }

  void _updateEditWaypoints(
      List<WaypointWithAltitude> waypoints,
      List<Polyline> polylines,
      Function(int)? onEditableWaypointTapped,
      int? selectedWaypointIndex) {
    editWaypointMarkers.clear();
    editWaypointPolylines.clear();

    // Add polylines
    editWaypointPolylines.addAll(polylines);

    // Create markers for waypoints
    for (int i = 0; i < waypoints.length; i++) {
      final waypoint = waypoints[i];
      final isFirst = i == 0;
      final isLast = i == waypoints.length - 1;

      // Different colors for start, end, and middle points
      Color markerColor = Colors.brown;
      IconData markerIcon = Icons.place;

      final isSelected = selectedWaypointIndex == i;

      if (isSelected) {
        markerColor = Colors.blue; // Highlight selected waypoint
        markerIcon = Icons.radio_button_checked;
      } else if (isFirst) {
        markerColor = Colors.green;
        markerIcon = Icons.play_arrow;
      } else if (isLast) {
        markerColor = Colors.red;
        markerIcon = Icons.stop;
      }

      final marker = Marker(
        width: 50.0,
        height: 60.0,
        point: waypoint.position,
        alignment: const Alignment(0, -0.25),
        child: GestureDetector(
          onTap: () => onEditableWaypointTapped?.call(i),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Altitude text above marker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: markerColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  '${waypoint.altitudeMeters.toInt()}m',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: markerColor,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(77),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    markerIcon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      editWaypointMarkers.add(marker);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platformData = ref.watch(platformDataProvider);
    final trajectoryData = ref.watch(trajectoryDataProvider);
    final missionsData = ref.watch(missionsStreamProvider);
    final planData = ref.watch(planStreamProvider);
    final detectedObjectsData = ref.watch(detectedObjectsDataProvider);
    final settings = ref.watch(settingsProvider);

    // Handle data updates - only when data actually changes and widget is mounted
    platformData.whenData((data) {
      if (mounted && data.isNotEmpty) {
        // Always update platforms since Redis client now filters changes
        final platforms = data;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            updatePlatformMarkers(platforms);
            onNewPlatformState(platforms);
          }
        });
      }
    });

    trajectoryData.whenData((data) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) onNewPlatformTrajectories(data);
        });
      }
    });

    missionsData.whenData((data) {
      if (mounted) {
        // Check if any missions have actually changed using their lastUpdated timestamps
        bool hasChanges = false;

        // Check for new or removed missions
        if (_currentMissions.length != data.length) {
          hasChanges = true;
        } else {
          // Check for updated missions using timestamps
          for (var newMission in data) {
            var lastUpdated = _missionLastUpdated[newMission.teamId];
            if (lastUpdated == null ||
                newMission.lastUpdated.isAfter(lastUpdated)) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          // Update timestamp tracking
          _missionLastUpdated.clear();
          for (var mission in data) {
            _missionLastUpdated[mission.teamId] = mission.lastUpdated;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) onNewMissionData(data);
          });
        }
      }
    });

    // Handle plan data updates - Smart change detection using Plan timestamps
    planData.whenData((data) {
      if (mounted) {
        // Check if any plans have actually changed using their lastUpdated timestamps
        bool hasChanges = false;

        // Check for new or removed plans
        if (_currentPlans.length != data.length) {
          hasChanges = true;
        } else {
          // Check for updated plans using timestamps
          for (var newPlan in data) {
            var lastUpdated = _planLastUpdated[newPlan.planId];
            if (lastUpdated == null ||
                newPlan.lastUpdated.isAfter(lastUpdated)) {
              hasChanges = true;
              debugPrint("BaseMapWidget: Plan ${newPlan.planId} updated");
              break;
            }
          }
        }

        if (hasChanges) {
          // Update timestamp tracking
          _planLastUpdated.clear();
          for (var plan in data) {
            _planLastUpdated[plan.planId] = plan.lastUpdated;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) onNewPlanData(data);
          });
        }
      }
    });

    // Handle detected objects data updates
    detectedObjectsData.whenData((data) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) onNewDetectedObjectsData(data);
        });
      }
    });

    // Update tile source based on satellite mode - only when needed
    String newUrlTemplate;
    if (settings.isSatelliteMode) {
      if (satelliteUrlTemplate == '') {
        newUrlTemplate = openstreetsUrlTemplate;
        debugPrint("Satellite URL Empty, please insert API Key.");
      } else {
        newUrlTemplate = satelliteUrlTemplate;
      }
    } else {
      updateTileSource(); // Update the OSM tile source
      newUrlTemplate = openstreetsUrlTemplate;
    }

    // Only update if template actually changed
    if (currentUrlTemplate != newUrlTemplate) {
      currentUrlTemplate = newUrlTemplate;
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: const LatLng(
                  MapConfig.defaultLatitude, MapConfig.defaultLongitude),
              initialZoom: MapConfig.defaultZoom,
              maxZoom: 19.0, // Most tile servers only go up to zoom 18
              minZoom:
                  6.5, // Prevent zooming out too far to avoid duplicate markers
              onTap: (tapPosition, point) {
                widget.onMapTapped(tapPosition, point);
                onMapTap(tapPosition, point);
              },
              onPositionChanged: (camera, hasGesture) {
                setState(() {});
              },
            ),
            children: [
              TileLayer(
                urlTemplate: currentUrlTemplate,
                userAgentPackageName: MapConfig.userAgentPackageName,
                // Respect tile server limits
                maxZoom: MapConfig.maxZoom,
                // Add error handling for tile loading
                errorTileCallback: (tile, error, stackTrace) {
                  debugPrint('Tile loading error: $error');
                  // Optionally switch to next tile server on repeated errors
                  // Uncomment the line below to enable automatic server switching on errors
                  // switchToNextTileServer();
                },
              ),
              PolylineLayer(polylines: routeLines),
              if (settings.isTrajectoryMode)
                PolylineLayer(polylines: trajectories),
              // Edit waypoint polylines
              if (isInPlanEditMode)
                PolylineLayer(polylines: editWaypointPolylines),
              PolygonLayer(polygons: areas),
              MarkerLayer(markers: persistentMarkers),
              MarkerLayer(markers: waypointMarkers),
              MarkerLayer(markers: platformMarkers),
              MarkerLayer(markers: detectedObjectMarkers),
              // Edit waypoint markers
              if (isInPlanEditMode) MarkerLayer(markers: editWaypointMarkers),
              ...buildAdditionalLayers(),
            ],
          ),
          // Plan drawer
          PlanDrawer(
            key: _planDrawerKey,
            isVisible: isPlanDrawerVisible,
            plan: selectedPlan,
            selectedOriginalWaypointIndex: selectedOriginalWaypointIndex,
            onClose: () {
              setState(() {
                isPlanDrawerVisible = false;
                selectedPlan = null;
                selectedOriginalWaypointIndex = null;
                isInPlanEditMode = false;
                editWaypointMarkers.clear();
                editWaypointPolylines.clear();
              });
              // Notify parent about drawer closing
              widget.onDrawerStateChanged?.call(false);
            },
            onPlanExecuted: () {
              // Additional callback for when plan is executed
              setState(() {
                isPlanDrawerVisible = false;
                selectedPlan = null;
                selectedOriginalWaypointIndex = null;
                isInPlanEditMode = false;
                editWaypointMarkers.clear();
                editWaypointPolylines.clear();
              });
              // Notify parent about drawer closing
              widget.onDrawerStateChanged?.call(false);
            },
            onPlanDeleted: () {
              // Additional callback for when plan is deleted
              setState(() {
                isPlanDrawerVisible = false;
                selectedPlan = null;
                selectedOriginalWaypointIndex = null;
                isInPlanEditMode = false;
                editWaypointMarkers.clear();
                editWaypointPolylines.clear();
              });
              // Notify parent about drawer closing
              widget.onDrawerStateChanged?.call(false);
            },
            onPlanEdited: () {
              // Additional callback for when plan is being edited
              setState(() {
                isInPlanEditMode = true;
              });
              debugPrint("Plan edit mode activated");
            },
            onEditModeEntered: () {
              // Hide UI elements when entering edit mode
              setState(() {
                shouldHideUIElements = true;
              });
              debugPrint("UI elements hidden for plan edit mode");
              // Notify parent page about edit mode start
              widget.onEditModeEntered?.call();
            },
            onEditModeExited: () {
              // Show UI elements when exiting edit mode
              setState(() {
                shouldHideUIElements = false;
                isInPlanEditMode = false;
              });
              debugPrint("UI elements restored after plan edit mode");
              // Notify parent page about edit mode end
              widget.onEditModeExited?.call();
            },
            onWaypointsChanged: (waypoints, polylines, editMode,
                onEditableWaypointTapped, selectedWaypointIndex) {
              setState(() {
                isInPlanEditMode = editMode;
                if (editMode) {
                  _updateEditWaypoints(waypoints, polylines,
                      onEditableWaypointTapped, selectedWaypointIndex);
                } else {
                  editWaypointMarkers.clear();
                  editWaypointPolylines.clear();
                }
              });
            },
          ),
          // Mission drawer
          MissionDrawer(
            isVisible: isMissionDrawerVisible,
            missionData: selectedMission,
            onClose: () {
              setState(() {
                isMissionDrawerVisible = false;
                selectedMission = null;
              });
              // Notify parent about drawer closing
              widget.onDrawerStateChanged?.call(false);
            },
            onMissionDeleted: () {
              // Additional callback for when mission is deleted
              setState(() {
                isMissionDrawerVisible = false;
                selectedMission = null;
              });
              // Notify parent about drawer closing
              widget.onDrawerStateChanged?.call(false);
            },
          ),
          // Object drawer
          ObjectDrawer(
            isVisible: isObjectDrawerVisible,
            detectedObject: selectedDetectedObject,
            onClose: () {
              setState(() {
                isObjectDrawerVisible = false;
                selectedDetectedObject = null;
              });
              // Notify parent about drawer closing
              widget.onDrawerStateChanged?.call(false);
            },
            onObjectConfirmed: () {
              // Additional callback for when object is confirmed
              debugPrint("BaseMapWidget: Object confirmed");
            },
            onObjectDiscarded: () {
              // Additional callback for when object is discarded
              setState(() {
                isObjectDrawerVisible = false;
                selectedDetectedObject = null;
              });
              // Notify parent about drawer closing
              widget.onDrawerStateChanged?.call(false);
            },
          ),
        ],
      ),
    );
  }

  // Platform data handling methods
  Future<void> onNewPlatformState(List<Platform> platforms) async {
    if (!mounted) return;

    // Schedule platform update for after the current build cycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          // Check for home positions on new platforms
          _checkAndSetHomePlatforms(platforms);
        } catch (e) {
          debugPrint('BaseMapWidget: Failed to process platform data: $e');
        }
      }
    });
  }

  /// Check all platforms and set home positions for those that have one but haven't been set yet
  void _checkAndSetHomePlatforms([List<Platform>? platformList]) {
    if (!mounted) return;

    try {
      final platforms =
          platformList ?? ref.read(platformDataProvider).value ?? [];

      for (final platform in platforms) {
        // Check if platform is disconnected and remove home position marker
        if (platform.status.toUpperCase() == 'DISCONNECTED' &&
            platformsWithHomeSet.contains(platform.platformId)) {
          removeHomePosition(platform.platformId);
        }
        // Check if platform has a home position and we haven't set a marker for it yet
        else if (platform.homePosition != null &&
            !platformsWithHomeSet.contains(platform.platformId)) {
          setHomePosition(
              platform.platformId, platform.color, platform.homePosition!);
        }
      }
    } catch (e) {
      debugPrint('BaseMapWidget: Failed to check home platforms: $e');
    }
  }

  /// Updates platform markers based on current platform state
  void updatePlatformMarkers(List<Platform> platforms) {
    if (!mounted) return;

    try {
      platformMarkers.clear();

      for (final platform in platforms) {
        final marker = createPlatformMarker(
          platform.platformId,
          platform.gpsPosition,
          platform.yaw,
          platform.status,
          platform.color,
        );
        platformMarkers.add(marker);
      }

      // Auto-focus on the first platform if we haven't already and no home positions exist
      if (!_hasAutoFocused && platforms.isNotEmpty && platformsWithHomeSet.isEmpty) {
        final firstPlatform = platforms.first;
        // Only focus if the platform has valid GPS coordinates
        if (firstPlatform.gpsPosition.latitude != 0.0 || firstPlatform.gpsPosition.longitude != 0.0) {
          safeMapMove(firstPlatform.gpsPosition, 17);
          _hasAutoFocused = true;
          debugPrint('BaseMapWidget: Auto-focused on first platform: ${firstPlatform.platformId}');
        }
      }

      // Always call setState to ensure UI updates
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('BaseMapWidget: Failed to update platform markers: $e');
    }
  }

  /// Updates detected object markers based on current detected objects state
  void updateDetectedObjectMarkers(List<DetectedObject> detectedObjects) {
    if (!mounted) return;

    try {
      detectedObjectMarkers.clear();

      for (final detectedObject in detectedObjects) {
        final marker = createDetectedObjectMarker(detectedObject);
        detectedObjectMarkers.add(marker);
      }

      // Always call setState to ensure UI updates
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('BaseMapWidget: Failed to update detected object markers: $e');
    }
  }

  Future<void> onNewPlatformTrajectories(
      List<Map<String, dynamic>> msgs) async {
    if (msgs.isNotEmpty) {
      trajectories.clear();
      
      for (Map<String, dynamic> msg in msgs) {
        final platformId = msg['platform_id'];
        final trajectory = msg['trajectory'];
        
        if (platformId != null && trajectory is List && trajectory.isNotEmpty) {
          Marker? marker = getPlatformMarkerById(platformId, platformMarkers);
          
          if (marker != null) {
            onUpdateTrajectories(platformId, marker.point, trajectory);
          }
        }
      }
    } else {
      trajectories.clear();
      setState(() {});
    }
  }

  Future<void> onNewMissionData(List<Mission> missions) async {
    // Store current missions for later access
    _currentMissions = missions;

    // Clear existing areas
    areas.clear();

    // Add areas from all missions with proper indexing
    for (var mission in missions) {
      // Add search areas with index
      for (int i = 0; i < mission.searchAreas.length; i++) {
        _addSearchAreaToMap(mission.searchAreas[i], mission, i + 1);
      }

      // Add no-fly zones with index
      for (int i = 0; i < mission.noFlyZones.length; i++) {
        _addNoFlyZoneToMap(mission.noFlyZones[i], mission, i + 1);
      }

      // Add priority areas with index
      for (int i = 0; i < mission.priorityAreas.length; i++) {
        _addPriorityAreaToMap(mission.priorityAreas[i], mission, i + 1);
      }

      // Add danger zones normally (assuming these are less common)
      for (var area in mission.dangerZones) {
        _addAreaToMap(area, mission);
      }
    }

    setState(() {});
  }

  Future<void> onNewDetectedObjectsData(List<DetectedObject> detectedObjects) async {
    // Store current detected objects for later access
    _currentDetectedObjects = detectedObjects;

    // Update detected object markers
    updateDetectedObjectMarkers(detectedObjects);
  }

  /// Add a search area to the map with index-based labeling
  void _addSearchAreaToMap(
      Area area, Mission ownerMission, int searchAreaIndex) {
    List<LatLng> latlngs = area.latLngPoints;

    if (latlngs.isEmpty) return;

    // Create unique label using team_id + "searcharea" + index
    String uniqueLabel = "${ownerMission.teamId}:searcharea$searchAreaIndex";

    Polygon areaPolygon = Polygon(
        points: latlngs,
        pattern: const StrokePattern.dotted(),
        holePointsList: [],
        borderStrokeWidth: 4,
        borderColor: area.type.borderColor,
        color: area.type.color,
        label: uniqueLabel,
        rotateLabel: true,
        labelPlacementCalculator:
            const PolygonLabelPlacementCalculator.centroid(),
        labelStyle: const TextStyle(color: Colors.black));

    // Remove existing area with same unique label to avoid duplicates
    areas
        .removeWhere((existingArea) => existingArea.label == areaPolygon.label);
    areas.add(areaPolygon);
  }

  /// Add a no-fly zone to the map with index-based labeling
  void _addNoFlyZoneToMap(Area area, Mission ownerMission, int noFlyZoneIndex) {
    List<LatLng> latlngs = area.latLngPoints;

    if (latlngs.isEmpty) return;

    // Create unique label using team_id + "noflyzone" + index
    String uniqueLabel = "${ownerMission.teamId}:noflyzone$noFlyZoneIndex";
    debugPrint(uniqueLabel);

    Polygon areaPolygon = Polygon(
        points: latlngs,
        pattern: const StrokePattern.dotted(),
        holePointsList: [],
        borderStrokeWidth: 4,
        borderColor: area.type.borderColor,
        color: area.type.color,
        label: uniqueLabel,
        rotateLabel: true,
        labelPlacementCalculator:
            const PolygonLabelPlacementCalculator.centroid(),
        labelStyle: const TextStyle(color: Colors.black));

    // Remove existing area with same unique label to avoid duplicates
    areas
        .removeWhere((existingArea) => existingArea.label == areaPolygon.label);
    areas.add(areaPolygon);
  }

  /// Add a priority area to the map with index-based labeling
  void _addPriorityAreaToMap(
      Area area, Mission ownerMission, int priorityAreaIndex) {
    List<LatLng> latlngs = area.latLngPoints;

    if (latlngs.isEmpty) return;

    // Create unique label using team_id + "priorityarea" + index
    String uniqueLabel =
        "${ownerMission.teamId}:priorityarea$priorityAreaIndex";
    debugPrint(uniqueLabel);

    Polygon areaPolygon = Polygon(
        points: latlngs,
        pattern: const StrokePattern.dotted(),
        holePointsList: [],
        borderStrokeWidth: 4,
        borderColor: area.type.borderColor,
        color: area.type.color,
        label: uniqueLabel,
        rotateLabel: true,
        labelPlacementCalculator:
            const PolygonLabelPlacementCalculator.centroid(),
        labelStyle: const TextStyle(color: Colors.black));

    // Remove existing area with same unique label to avoid duplicates
    areas
        .removeWhere((existingArea) => existingArea.label == areaPolygon.label);
    areas.add(areaPolygon);
  }

  /// Add a single area to the map
  void _addAreaToMap(Area area, Mission ownerMission) {
    List<LatLng> latlngs = area.latLngPoints;

    if (latlngs.isEmpty) return;

    // Create unique label using team_id + area description/type + hashCode to ensure uniqueness
    String uniqueLabel =
        area.description.isNotEmpty ? area.description : area.type.name;
    uniqueLabel = "${ownerMission.teamId}:$uniqueLabel:${area.hashCode}";
    debugPrint(uniqueLabel);

    Polygon areaPolygon = Polygon(
        points: latlngs,
        pattern: const StrokePattern.dotted(),
        holePointsList: [],
        borderStrokeWidth: 4,
        borderColor: area.type.borderColor,
        color: area.type.color,
        label: uniqueLabel,
        rotateLabel: true,
        labelPlacementCalculator:
            const PolygonLabelPlacementCalculator.centroid(),
        labelStyle: const TextStyle(color: Colors.black));

    // Remove existing area with same unique label to avoid duplicates
    areas
        .removeWhere((existingArea) => existingArea.label == areaPolygon.label);
    areas.add(areaPolygon);
  }

  /// Find which mission an area belongs to based on area description/label
  Mission? _findMissionForArea(String areaLabel) {
    // If the label contains team_id prefix (format: "team_id:area_name"), extract the team_id
    if (areaLabel.contains(':')) {
      final parts = areaLabel.split(':');
      if (parts.length >= 2) {
        final teamId = parts[0];
        try {
          return _currentMissions.firstWhere(
            (mission) => mission.teamId == teamId,
          );
        } catch (e) {
          // Team not found, fall through to original logic
        }
      }
    }

    // Fallback to original logic for backward compatibility
    for (var mission in _currentMissions) {
      for (var area in mission.allAreas) {
        final label =
            area.description.isNotEmpty ? area.description : area.type.name;
        if (label == areaLabel) {
          return mission;
        }
      }
    }
    return null;
  }

  Future<void> onNewPlanData(List<Plan> plans) async {
    // Store current plans for later access
    _currentPlans = plans;

    // Clear existing plan-related UI elements
    routeLines.clear();
    waypointMarkers.clear();
    platformPlans.clear();
    // Generate waypoints and routes from plans
    for (var plan in plans) {
      final waypoints = plan.waypoints;

      if (waypoints.isNotEmpty) {
        platformPlans[plan.planId.toString()] = {
          'platform_id': plan.platformId,
          'waypoints': waypoints
              .map((w) => {
                    'lat': w.position.latitude,
                    'lon': w.position.longitude,
                    'type': w.actionName,
                    'id': w.actionName, // Use action name as ID for now
                  })
              .toList(),
        };
        onUpdateWaypoints(
            plan.planId.toString(),
            waypoints
                .map((w) => {
                      'lat': w.position.latitude,
                      'lon': w.position.longitude,
                      'type': w.actionName,
                      'id': w.actionName,
                    })
                .toList());
      }
    }

    setState(() {});
  }

  void onUpdateTrajectories(
      String id, LatLng currentPosition, List<dynamic> points) {
    // Get platform color from platform data
    final platforms = ref.read(platformDataProvider).value ?? [];
    final platform = platforms.firstWhere(
      (p) => p.platformId == id,
      orElse: () => Platform(
        platformId: id,
        platformIp: '<platform_ip>',
        teamId: '',
        gpsPosition: const LatLng(0, 0),
        pose: {},
        yaw: 0,
        status: 'UNKNOWN',
        color: Colors.blue,
      ),
    );
    Color trajectoryColor = platform.color;

    List<LatLng> latlngs = [];

    for (var point in points) {
      final lat = (point['lat'] as num?)?.toDouble();
      final lon = (point['lon'] as num?)?.toDouble();
      
      if (lat == null || lon == null) {
        continue;
      }
      
      if (lat == 0.0 && lon == 0.0 || lat == -1.0 && lon == -1.0) {
        continue;
      }
      
      latlngs.add(LatLng(lat, lon));
    }

    if (currentPosition.latitude != 0.0 || currentPosition.longitude != 0.0) {
      latlngs.add(currentPosition);
    }

    // Create polyline for the trajectory
    Polyline route = Polyline(
      points: latlngs,
      strokeWidth: 2,
      color: trajectoryColor,
      pattern: const StrokePattern.solid(),
      borderStrokeWidth: 1,
    );

    // Store trajectory using platform ID as a key (if needed)
    trajectories.add(route);
    setState(() {});
  }

  void onUpdateWaypoints(String id, List<dynamic> points) {
    List<LatLng> latlngs = [];
    int index = 0;

    // Get the plan to determine the appropriate colors
    final planIdInt = int.tryParse(id);
    Plan? plan;
    if (planIdInt != null) {
      plan = _currentPlans.cast<Plan?>().firstWhere(
            (p) => p!.planId == planIdInt,
            orElse: () => null,
          );
    }

    for (var point in points) {
      LatLng latlng;

      // Handle both old format (waypoint nested) and new format (direct lat/lon)
      if (point['waypoint'] != null) {
        // Old format: point['waypoint']['latitude'], point['waypoint']['longitude']
        latlng = LatLng(
            point['waypoint']['latitude'], point['waypoint']['longitude']);
      } else if (point['lat'] != null && point['lon'] != null) {
        // New format: point['lat'], point['lon']
        latlng = LatLng(point['lat'], point['lon']);
      } else {
        // Skip invalid waypoints
        continue;
      }

      latlngs.add(latlng);
      
      // Use platform color with plan status-based opacity if available, otherwise use default colors
      Color color = Colors.black;
      if (plan != null) {
        // Get platform color
        final platforms = ref.read(platformDataProvider).value ?? [];
        Platform? platform;
        for (final p in platforms) {
          if (p.platformId == plan.platformId) {
            platform = p;
            break;
          }
        }

        if (platform != null) {
          // Get the display color based on plan status using platform color
          final baseColor = plan.getDisplayColor(platform.color);
          if (index == points.length - 1) {
            // Last waypoint - use a reddish tint of the display color
            color = Color.lerp(baseColor, Colors.red, 0.4) ?? baseColor;
          } else if (index == 0) {
            // First waypoint - use a greenish tint of the display color
            color = Color.lerp(baseColor, Colors.green, 0.4) ?? baseColor;
          } else {
            // Middle waypoints - use the display color directly
            color = baseColor;
          }
        } else {
          // Fallback to default colors if platform not found
          if (index == points.length - 1) {
            color = const Color.fromARGB(255, 255, 0, 0);
          } else if (index == 0) {
            color = const Color.fromARGB(255, 0, 255, 0);
          }
        }
      } else {
        // Fallback to old color scheme if plan not found
        if (index == points.length - 1) {
          color = const Color.fromARGB(255, 255, 0, 0);
        } else if (index == 0) {
          color = const Color.fromARGB(255, 0, 255, 0);
        }
      }
      
      int waypointIndex = index + 1;
      final Marker newMarker =
          createWaypointMarker(id, latlng, waypointIndex, color);
      waypointMarkers.add(newMarker);
      index++;
    }

    if (latlngs.isEmpty) return;

    Polyline route = Polyline(
        points: latlngs,
        strokeWidth: 3,
        color: getRouteColor(id),
        pattern: const StrokePattern.solid(),
        borderStrokeWidth: 1);
    routeLines.add(route);
    setState(() {});
  }

  Color getRouteColor(String planId) {
    // This method is only for plan routes - use platform color with plan status-based opacity
    final platforms = ref.read(platformDataProvider).value ?? [];
    final planIdInt = int.tryParse(planId);

    if (planIdInt != null) {
      final plan = _currentPlans.cast<Plan?>().firstWhere(
            (p) => p!.planId == planIdInt,
            orElse: () => null,
          );

      if (plan != null) {
        Platform? platform;
        for (final p in platforms) {
          if (p.platformId == plan.platformId) {
            platform = p;
            break;
          }
        }

        if (platform != null) {
          // Get the display color based on plan status using platform color
          final displayColor = plan.getDisplayColor(platform.color);
          // Apply additional opacity for polylines based on plan status
          if (plan.status == PlanStatus.completed || plan.status == PlanStatus.canceled) {
            // For completed/canceled plans, use very low opacity for routes
            return displayColor.withValues(alpha: 0.12); // 20% * 0.6 = 12% final opacity
          } else {
            // For active plans, use normal route opacity
            return displayColor.withValues(alpha: 0.6);
          }
        }
      }
    }

    return Colors.blue.withValues(alpha: 0.6);
  }

  void setHomePosition(String id, Color color, LatLng homeLatLng) {
    if (!platformsWithHomeSet.contains(id)) {
      platformsWithHomeSet.add(id);

      // Only move map to the first home position set
      if (platformsWithHomeSet.length == 1) {
        safeMapMove(homeLatLng, 17);
        _hasAutoFocused = true; // Mark that we've auto-focused
        debugPrint('BaseMapWidget: Auto-focused on home position for platform: $id');
      }

      final Marker newHomeMarker = Marker(
        key: Key('home_$id'), // Unique key for each home marker
        width: 20.0,
        height: 20.0,
        point: homeLatLng,
        child: Icon(Icons.home, size: 20.0, color: color),
      );

      // Add to persistent markers and trigger rebuild only once
      persistentMarkers.add(newHomeMarker);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void removeHomePosition(String id) {
    if (platformsWithHomeSet.contains(id)) {
      platformsWithHomeSet.remove(id);
      
      // Remove the home marker from persistent markers
      persistentMarkers.removeWhere((marker) => marker.key == Key('home_$id'));
      
      debugPrint('BaseMapWidget: Removed home position marker for platform: $id');
      
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  Offset getMarkerScreenPosition(LatLng latlng) {
    final offset = mapController.camera.latLngToScreenOffset(latlng);
    return Offset(
        offset.dx, offset.dy - 60); // Offset to position box above marker
  }

  // Abstract method for creating platform markers - can be overridden by child classes
  Marker createPlatformMarker(
      String id, LatLng latlng, double yaw, String status, Color color) {
    // Determine if platform is disconnected
    final isDisconnected = status.toUpperCase() == 'DISCONNECTED';
    
    return Marker(
      key: Key(id),
      width: 30.0,
      height: 30.0,
      point: latlng,
      child: isDisconnected
          ? Icon(
              Icons.signal_cellular_connected_no_internet_0_bar_outlined, // Outlined icon for disconnected
              size: 30.0,
              color: const Color.fromARGB(104, 255, 0, 0).withOpacity(0.7), // Grayed out
            )
          : Transform.rotate(
              angle: yaw,
              child: Icon(
                Icons.navigation,
                size: 30.0,
                color: color,
              ),
            ),
    );
  }

  // Method for creating detected object markers
  Marker createDetectedObjectMarker(DetectedObject detectedObject) {
    return Marker(
      key: Key(detectedObject.id),
      width: 35.0,
      height: 35.0,
      point: detectedObject.position,
      child: GestureDetector(
        onTap: () {
          _showObjectDrawer(detectedObject);
        },
        child: Container(
          decoration: BoxDecoration(
            color: detectedObject.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(77),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            detectedObject.classIcon,
            size: 20.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Method for creating waypoint markers with global tap functionality
  Marker createWaypointMarker(
      String id, LatLng latlng, int waypointIndex, Color color) {
    return Marker(
      width: 20.0,
      height: 20.0,
      point: latlng,
      child: GestureDetector(
        onTap: () {
          setState(() {
            this.waypointIndex = waypointIndex;
            routeId = id;

            // Show plan drawer if this is a plan waypoint
            if (platformPlans.containsKey(id)) {
              isPlanDrawerVisible = true;
              // Set the selected original waypoint index (convert from 1-based to 0-based)
              selectedOriginalWaypointIndex = waypointIndex - 1;

              // Get the actual plan data from current plans
              final planId = int.tryParse(id);
              if (planId != null) {
                try {
                  final plan = _currentPlans.firstWhere(
                    (p) => p.planId == planId,
                  );

                  selectedPlan = plan;
                } catch (e) {
                  // Plan not found in current plans, skip
                  debugPrint('Plan not found: $planId');
                  return;
                }
              } else {
                // Plan ID not parsed, skip
                debugPrint('Could not parse plan ID from: ${platformPlans[id]}');
                return;
              }

              // Notify parent about drawer opening
              widget.onDrawerStateChanged?.call(true);
            }
          });
          // Call the optional callback if provided
          widget.onWaypointTapped?.call(id, waypointIndex, latlng);
        },
        child: Icon(
          Icons.gps_fixed,
          size: 20.0,
          color: color,
        ),
      ),
    );
  }

  Marker? getPlatformMarkerById(String id, List<Marker> markerList) {
    try {
      return markerList.firstWhere((marker) => marker.key == Key(id));
    } catch (e) {
      return null;
    }
  }

  double getYawFromQuaternion(Quaternion quat) {
    double yaw = atan2(2 * (quat.w * quat.z + quat.x * quat.y),
        1 - 2 * (quat.y * quat.y + quat.z * quat.z));
    return yaw;
  }
}
