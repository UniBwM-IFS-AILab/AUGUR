// Waypoints Map widget for waypoint and trajectory planning
//
// This widget extends BaseMapWidget and adds waypoint planning functionality
// including planning markers, planning polylines, and planning callbacks.
//
// IMPORTANT: Update the contact email in lib/config/map_config.dart
//
// For more information, see docs/OSM_TILE_CONFIGURATION.md

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:augur/ui/widgets/base_map_widget.dart';
import 'package:augur/core/classes/waypoint.dart';

class WaypointsMapWidget extends BaseMapWidget {
  final List<WaypointWithAltitude>?
      planningPoints; // Optional planning points (waypoints/trajectory)
  final List<Polyline>? planningPolylines; // Optional planning polylines
  final Function(WaypointWithAltitude)?
      onPlanningMarkerTapped; // Callback for planning marker taps

  const WaypointsMapWidget({
    super.key,
    required super.onMapTapped,
    super.onWaypointTapped,
    super.onDrawerStateChanged,
    super.onEditModeEntered,
    super.onEditModeExited,
    this.planningPoints,
    this.planningPolylines,
    this.onPlanningMarkerTapped,
  });

  @override
  BaseMapWidgetState<WaypointsMapWidget> createState() =>
      _WaypointsMapWidgetState();
}

class _WaypointsMapWidgetState extends BaseMapWidgetState<WaypointsMapWidget> {
  final List<Marker> planningMarkers = []; // For trajectory/waypoint planning

  @override
  List<Widget> buildAdditionalLayers() {
    // Update planning markers when planning points change
    updatePlanningMarkers();

    List<Widget> additionalLayers = [];

    // Add planning polylines
    if (widget.planningPolylines != null) {
      additionalLayers.add(PolylineLayer(polylines: widget.planningPolylines!));
    }

    // Add planning markers
    additionalLayers.add(MarkerLayer(markers: planningMarkers));

    return additionalLayers;
  }

  @override
  void onMapTap(TapPosition tapPosition, LatLng point) {
    // Call parent to hide waypoint box
    super.onMapTap(tapPosition, point);
    // No additional map tap handling for waypoints widget
    // All other map tap handling is done in the parent page
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
