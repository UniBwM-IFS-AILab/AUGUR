// Mission Map widget for displaying OpenStreetMap tiles and mission data
//
// This widget extends BaseMapWidget and adds mission-specific functionality
// including temporary markers, area polygons, and waypoint info boxes.
// Note: This widget does not include platform selection functionality.
//
// IMPORTANT: Update the contact email in lib/config/map_config.dart
//
// For more information, see docs/OSM_TILE_CONFIGURATION.md

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:augur/ui/widgets/base_map_widget.dart';

class MissionMapWidget extends BaseMapWidget {
  final List<Marker> tempMarkers;
  final List<Polyline> tempPolylines;
  final List<Marker> areaMarkers;
  final List<Polygon> areaPolygons;
  final List<Polyline> areaPolylines;

  const MissionMapWidget({
    super.key,
    required super.onMapTapped,
    super.onWaypointTapped,
    super.onDrawerStateChanged,
    super.onEditModeEntered,
    super.onEditModeExited,
    required this.tempMarkers,
    required this.tempPolylines,
    required this.areaMarkers,
    required this.areaPolygons,
    required this.areaPolylines,
  });

  @override
  BaseMapWidgetState<MissionMapWidget> createState() =>
      _MissionMapWidgetState();
}

class _MissionMapWidgetState extends BaseMapWidgetState<MissionMapWidget> {
  // Mission-specific state (waypoint state is now handled in base class)

  @override
  List<Widget> buildAdditionalLayers() {
    List<Widget> additionalLayers = [];

    // Mission-specific overlays
    additionalLayers.add(PolygonLayer(polygons: widget.areaPolygons));
    additionalLayers.add(PolylineLayer(polylines: widget.areaPolylines));
    additionalLayers.add(PolylineLayer(polylines: widget.tempPolylines));

    // Mission-specific markers
    additionalLayers.add(MarkerLayer(markers: widget.areaMarkers));
    additionalLayers.add(MarkerLayer(markers: widget.tempMarkers));

    return additionalLayers;
  }

  @override
  void onMapTap(TapPosition tapPosition, LatLng point) {
    // Call parent to hide waypoint box
    super.onMapTap(tapPosition, point);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
