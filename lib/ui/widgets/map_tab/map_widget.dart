import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:augur/ui/widgets/base_map_widget.dart';
import 'package:augur/core/classes/waypoint.dart';
import 'package:augur/core/classes/platform.dart';
import 'package:augur/core/classes/mission.dart';
import 'package:augur/core/classes/plan.dart';
import 'package:augur/state/redis_provider.dart';

// Focus zoom constants
const double missionFocusZoom = 18.0;
const double planFocusZoom = 18.0;
const double platformFocusZoom = 18.0;

class MapWidget extends BaseMapWidget {
  final Function(Platform)?
      onPlatformSelected; // Updated to pass Platform object
  final List<WaypointWithAltitude>? planningPoints;
  final List<Polyline>? planningPolylines; // Optional planning polylines
  final Function(WaypointWithAltitude)?
      onPlanningMarkerTapped; // Callback for planning marker taps
  final String? focusPlatformId; // Platform ID to focus on
  final Plan? externalPlanData; // External plan data to open in drawer
  final VoidCallback?
      onExternalPlanOpened; // Callback when external plan is opened
  final Mission? focusMission; // Mission to focus on
  final Function(Mission)?
      onMissionSelected; // Callback when mission is selected from focus
  final Plan? focusPlan; // Plan to focus on
  final Function(Plan)?
      onPlanFocused; // Callback when plan is selected from focus

  const MapWidget({
    super.key,
    this.onPlatformSelected,
    required super.onMapTapped,
    super.onWaypointTapped,
    super.onDrawerStateChanged,
    super.onEditModeEntered,
    super.onEditModeExited,
    super.onPlanSelected,
    this.planningPoints,
    this.planningPolylines,
    this.onPlanningMarkerTapped,
    this.focusPlatformId,
    this.externalPlanData,
    this.onExternalPlanOpened,
    this.focusMission,
    this.onMissionSelected,
    this.focusPlan,
    this.onPlanFocused,
  });

  @override
  BaseMapWidgetState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends BaseMapWidgetState<MapWidget> {
  // MapWidget-specific state
  bool isPlatformBoxVisible = false;
  String focusedPlatformId = '';
  String focusedPlatformStatus = '';

  String? lastFocusPlatformId; // Track last focus request
  Mission? lastFocusMission; // Track last mission focus request
  Plan? lastFocusPlan; // Track last plan focus request

  final List<Marker> planningMarkers = []; // For trajectory/waypoint planning

  void focusOnPlatform(String platformId) {
    final marker = getPlatformMarkerById(platformId, platformMarkers);
    if (marker != null) {
      safeMapMove(marker.point, platformFocusZoom);

      // Get the platform object and trigger platform selection to open the info drawer
      final platforms = ref.read(platformDataProvider).value ?? [];
      final platform = platforms.firstWhere(
        (p) => p.platformId == platformId,
        orElse: () => Platform(
          platformId: platformId,
          platformIp: '<platform_ip>',
          teamId: '',
          gpsPosition: const LatLng(0, 0),
          pose: {},
          yaw: 0,
          status: 'UNKNOWN',
          color: Colors.blue,
        ),
      );
      widget.onPlatformSelected?.call(platform);
    } else {
      debugPrint('Platform marker not found for ID: $platformId');
    }
  }

  void focusOnMission(Mission mission) {
    if (mission.searchAreas.isNotEmpty) {
      final searchArea =
          mission.searchAreas.first; // Focus on first search area
      if (searchArea.latLngPoints.isNotEmpty) {
        // Calculate the center of the search area polygon
        double totalLat = 0;
        double totalLng = 0;
        for (var point in searchArea.latLngPoints) {
          totalLat += point.latitude;
          totalLng += point.longitude;
        }
        final centerLat = totalLat / searchArea.latLngPoints.length;
        final centerLng = totalLng / searchArea.latLngPoints.length;
        final searchAreaCenter = LatLng(centerLat, centerLng);

        // Focus map on the search area center
        safeMapMove(searchAreaCenter, missionFocusZoom);

        // Show the mission drawer directly
        setState(() {
          selectedMission = mission;
          isMissionDrawerVisible = true;
          // Close plan drawer if open
          isPlanDrawerVisible = false;
          selectedPlan = null;
          selectedOriginalWaypointIndex = null;
        });
        widget.onDrawerStateChanged?.call(true);

        // Notify the callback if provided
        widget.onMissionSelected?.call(mission);
      }
    }
  }

  void focusOnPlan(Plan plan) {
    // Calculate the center of the plan waypoints
    if (plan.waypoints.isNotEmpty) {
      double totalLat = 0;
      double totalLng = 0;
      for (var waypoint in plan.waypoints) {
        totalLat += waypoint.position.latitude;
        totalLng += waypoint.position.longitude;
      }
      final centerLat = totalLat / plan.waypoints.length;
      final centerLng = totalLng / plan.waypoints.length;
      final planCenter = LatLng(centerLat, centerLng);

      // Focus map on the plan center
      safeMapMove(planCenter, planFocusZoom);

      // Show the plan drawer directly with plan object
      setState(() {
        selectedPlan = plan;
        isPlanDrawerVisible = true;
        // Close mission drawer if open
        isMissionDrawerVisible = false;
        selectedMission = null;
      });
      widget.onDrawerStateChanged?.call(true);
    }
  }

  @override
  List<Widget> buildAdditionalLayers() {
    // Handle external plan opening request
    if (widget.externalPlanData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openPlanDrawer(widget.externalPlanData!);
        widget.onExternalPlanOpened?.call(); // Notify that plan was opened
      });
    }

    // Handle focus platform request
    if (widget.focusPlatformId != null) {
      // Always process focus request if platform ID is provided, regardless of previous focus
      if (widget.focusPlatformId != lastFocusPlatformId) {
        lastFocusPlatformId = widget.focusPlatformId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          focusOnPlatform(widget.focusPlatformId!);
        });
      }
    } else {
      // Reset last focus platform ID when no focus is requested
      lastFocusPlatformId = null;
    }

    // Handle focus mission request
    if (widget.focusMission != null) {
      if (widget.focusMission != lastFocusMission) {
        lastFocusMission = widget.focusMission;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          focusOnMission(widget.focusMission!);
        });
      }
    } else {
      // Reset last focus mission when no focus is requested
      lastFocusMission = null;
    }

    // Handle focus plan request
    if (widget.focusPlan != null) {
      if (widget.focusPlan != lastFocusPlan) {
        lastFocusPlan = widget.focusPlan;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          focusOnPlan(widget.focusPlan!);
        });
      }
    } else {
      // Reset last focus plan when no focus is requested
      lastFocusPlan = null;
    }

    // Update planning markers when planning points change
    updatePlanningMarkers();

    Offset platformBox = Offset(0, 0);
    LatLng focusedPlatformPosition =
        getPlatformMarkerById(focusedPlatformId, platformMarkers)?.point ??
            LatLng(0.0, 0.0);
    if (isPlatformBoxVisible) {
      if (focusedPlatformPosition.latitude != 0.0 &&
          focusedPlatformPosition.longitude != 0.0) {
        safeMapMove(focusedPlatformPosition, 17.0);
      }
      platformBox = getMarkerScreenPosition(focusedPlatformPosition);
    }

    List<Widget> additionalLayers = [];

    // Add planning polylines
    if (widget.planningPolylines != null) {
      additionalLayers.add(PolylineLayer(polylines: widget.planningPolylines!));
    }

    // Add planning markers
    additionalLayers.add(MarkerLayer(markers: planningMarkers));

    // Add info boxes
    if (isPlatformBoxVisible) {
      additionalLayers.add(
        Positioned(
          left: platformBox.dx,
          top: platformBox.dy,
          child: GestureDetector(
            onTap: () {
              // prevent closing when tapping inside the info box
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 4, spreadRadius: 1)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Platform ID: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(focusedPlatformId),
                    ],
                  ),
                  Row(
                    children: [
                      Text('State: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(focusedPlatformStatus),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    return additionalLayers;
  }

  @override
  void onMapTap(TapPosition tapPosition, LatLng point) {
    // Call parent to hide waypoint box
    super.onMapTap(tapPosition, point);

    // hide the platform info box when the map is tapped
    setState(() {
      isPlatformBoxVisible = false;
    });
  }

  @override
  Marker createPlatformMarker(
      String id, LatLng latlng, double yaw, String status, Color color) {
    // Determine if platform is disconnected
    final isDisconnected = status.toUpperCase() == 'DISCONNECTED';
    
    return Marker(
      key: Key(id), // Use same key format as base class for consistency
      width: 30.0,
      height: 30.0,
      point: latlng,
      child: GestureDetector(
          onTap: () {
            // Call platform selection callback if available, otherwise show info box
            if (widget.onPlatformSelected != null) {
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
              widget.onPlatformSelected!(platform);
            } else {
              setState(() {
                isPlatformBoxVisible = true;
                focusedPlatformId = id;
                focusedPlatformStatus = status;
              });
            }
          },
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
                )),
    );
  }

  void updatePlanningMarkers() {
    planningMarkers.clear();

    if (widget.planningPoints != null && widget.planningPoints!.isNotEmpty) {
      for (int i = 0; i < widget.planningPoints!.length; i++) {
        final waypoint = widget.planningPoints![i];
        final isFirst = i == 0;
        final isLast = i == widget.planningPoints!.length - 1;

        // Different colors for start, end, and middle points
        Color markerColor = Colors.blue;
        IconData markerIcon = Icons.place;

        if (isFirst) {
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
            onTap: () => widget.onPlanningMarkerTapped?.call(waypoint),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Altitude text above marker
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

        planningMarkers.add(marker);
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
