import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/ui/widgets/mission_tab/mission_map_widget.dart';
import 'package:augur/ui/widgets/mission_tab/mic_button.dart';
import 'package:augur/ui/widgets/mission_tab/mission_conflict_dialog.dart';
import 'package:augur/ui/widgets/utility_widgets/speech_bubble.dart';
import 'package:augur/state/ros_provider.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/core/classes/mission.dart';
import 'dart:async';

enum AreaType { searchArea, noFlyZone, areaOfInterest, pointOfInterest }

class AreaDefinition {
  final String id;
  final AreaType type;
  final List<LatLng> points;
  final String name;
  final Color color;

  AreaDefinition({
    required this.id,
    required this.type,
    required this.points,
    required this.name,
    required this.color,
  });
}

class MissionTabPage extends ConsumerStatefulWidget {
  const MissionTabPage({super.key});

  @override
  ConsumerState<MissionTabPage> createState() => _MissionTabPageState();
}

class _MissionTabPageState extends ConsumerState<MissionTabPage> {
  AreaType? _currentAreaType;
  final List<LatLng> _currentPoints = [];
  final List<AreaDefinition> _definedAreas = [];
  bool _isDefiningArea = false;
  bool _isPlanDrawerOpen = false; // Track plan drawer state
  bool _shouldHideUIElements = false; // UI hiding state for plan edit mode
  final StreamController<String> _textStreamController =
      StreamController<String>.broadcast();

  // Detection classes for search mission
  final List<String> _availableDetectionClasses = [
    'car',
    'person',
    'bicycle',
    'truck',
    'motorcycle',
    'bus',
    'boat',
    'aircraft'
  ];
  final Set<String> _selectedDetectionClasses = <String>{};

  // Map overlay markers for visualization during definition
  final List<Marker> _tempMarkers = [];
  final List<Polyline> _tempPolylines = [];

  // Final map overlays for defined areas
  final List<Marker> _areaMarkers = [];
  final List<Polygon> _areaPolygons = [];
  final List<Polyline> _areaPolylines = [];

  void _clearSpeechStream() {
    // Add an empty string to signal clearing to any listeners
    _textStreamController.add('');
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

  void _startAreaDefinition(AreaType type) {
    setState(() {
      _currentAreaType = type;
      _currentPoints.clear();
      _isDefiningArea = true;
      _updateMapOverlays();
    });
  }

  void _finishAreaDefinition() {
    final minPoints = _currentAreaType == AreaType.pointOfInterest ? 1 : 3;
    if (_currentPoints.length >= minPoints && _currentAreaType != null) {
      final area = AreaDefinition(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: _currentAreaType!,
        points: List.from(_currentPoints),
        name: _getAreaTypeName(_currentAreaType!),
        color: _getAreaTypeColor(_currentAreaType!),
      );

      setState(() {
        _definedAreas.add(area);
        _currentPoints.clear();
        _currentAreaType = null;
        _isDefiningArea = false;

        // Update visual overlays
        _updateMapOverlays();
      });
    }
  }

  void _updateMapOverlays() {
    // Clear previous overlays
    _tempMarkers.clear();
    _tempPolylines.clear();
    _areaMarkers.clear();
    _areaPolygons.clear();
    _areaPolylines.clear();

    // Add temporary markers for current definition
    if (_isDefiningArea && _currentPoints.isNotEmpty) {
      for (int i = 0; i < _currentPoints.length; i++) {
        _tempMarkers.add(
          Marker(
            point: _currentPoints[i],
            width: 20,
            height: 20,
            child: Container(
              decoration: BoxDecoration(
                color: _getAreaTypeColor(_currentAreaType!),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Add temp polyline for areas (not points of interest)
      if (_currentAreaType != AreaType.pointOfInterest &&
          _currentPoints.length > 1) {
        _tempPolylines.add(
          Polyline(
            points: _currentPoints,
            strokeWidth: 2,
            color: _getAreaTypeColor(_currentAreaType!).withAlpha(204),
            pattern: StrokePattern.dashed(segments: [5, 5]),
          ),
        );
      }
    }

    // Add final overlays for defined areas
    for (final area in _definedAreas) {
      if (area.type == AreaType.pointOfInterest) {
        // Single marker for point of interest
        _areaMarkers.add(
          Marker(
            point: area.points.first,
            width: 30,
            height: 30,
            child: GestureDetector(
              onTap: () => _showRemoveAreaDialog(area),
              child: Container(
                decoration: BoxDecoration(
                  color: area.color.withAlpha(204),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  _getAreaTypeIcon(area.type),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      } else {
        // Polygon for areas
        _areaPolygons.add(
          Polygon(
            points: area.points,
            color: area.color,
            borderColor: area.color.withAlpha(204),
            borderStrokeWidth: 2,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textStreamController.close();
    super.dispose();
  }

  void _cancelAreaDefinition() {
    setState(() {
      _currentPoints.clear();
      _currentAreaType = null;
      _isDefiningArea = false;
      _updateMapOverlays();
    });
  }

  void _removeArea(String areaId) {
    setState(() {
      _definedAreas.removeWhere((area) => area.id == areaId);
      _updateMapOverlays();
    });
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (_isDefiningArea) {
      setState(() {
        _currentPoints.add(point);
        _updateMapOverlays();
      });
    } else {
      // Check if tap is on an existing area to remove it
      for (final area in _definedAreas) {
        if (area.type == AreaType.pointOfInterest) {
          // Check if tap is near the point marker
          if (_isPointNearMarker(point, area.points.first)) {
            _showRemoveAreaDialog(area);
            break;
          }
        } else if (_isPointInPolygon(point, area.points)) {
          _showRemoveAreaDialog(area);
          break;
        }
      }
    }
  }

  bool _isPointNearMarker(LatLng point, LatLng marker) {
    // Check if the tap is within ~20 meters of the marker
    const double threshold = 0.0002; // Approximately 20 meters
    double distance = ((point.latitude - marker.latitude).abs() +
        (point.longitude - marker.longitude).abs());
    return distance < threshold;
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    // Simple point-in-polygon algorithm
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      int j = (i + 1) % polygon.length;
      if (((polygon[i].latitude <= point.latitude &&
                  point.latitude < polygon[j].latitude) ||
              (polygon[j].latitude <= point.latitude &&
                  point.latitude < polygon[i].latitude)) &&
          point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  void _showRemoveAreaDialog(AreaDefinition area) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${area.name}?'),
        content: Text(
            'Are you sure you want to remove this ${area.name.toLowerCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _removeArea(area.id);
              Navigator.of(context).pop();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _getAreaTypeName(AreaType type) {
    switch (type) {
      case AreaType.searchArea:
        return 'Search Area';
      case AreaType.noFlyZone:
        return 'No-Fly Zone';
      case AreaType.areaOfInterest:
        return 'Area of Interest';
      case AreaType.pointOfInterest:
        return 'Point of Interest';
    }
  }

  Color _getAreaTypeColor(AreaType type) {
    switch (type) {
      case AreaType.searchArea:
        return Colors.green.withAlpha(77);
      case AreaType.noFlyZone:
        return Colors.red.withAlpha(77);
      case AreaType.areaOfInterest:
        return Colors.blue.withAlpha(77);
      case AreaType.pointOfInterest:
        return Colors.orange.withAlpha(77);
    }
  }

  IconData _getAreaTypeIcon(AreaType type) {
    switch (type) {
      case AreaType.searchArea:
        return Icons.search;
      case AreaType.noFlyZone:
        return Icons.not_interested;
      case AreaType.areaOfInterest:
        return Icons.location_on;
      case AreaType.pointOfInterest:
        return Icons.place;
    }
  }

  bool _canFinishAreaDefinition() {
    final minPoints = _currentAreaType == AreaType.pointOfInterest ? 1 : 3;
    return _currentPoints.length >= minPoints;
  }

  String _getPointsStatusText() {
    if (_currentAreaType == AreaType.pointOfInterest) {
      return _currentPoints.isNotEmpty
          ? " (Ready to finish)"
          : " (1 point required)";
    } else {
      return _currentPoints.length >= 3
          ? " (Ready to finish)"
          : " (Min 3 required)";
    }
  }

  void _createMission() {
    if (_definedAreas.isEmpty) return;
    _handleTeamSelected("drone_team");
  }

  void _handleTeamSelected(String teamId) {
    // Check if there's already a mission for this team
    final missionsAsync = ref.read(missionsStreamProvider);

    missionsAsync.when(
      data: (missions) {
        Mission? existingMission;
        try {
          existingMission = missions.firstWhere(
            (mission) => mission.teamId == teamId,
          );
        } catch (e) {
          existingMission = null;
        }

        if (existingMission != null) {
          // Show conflict dialog
          _showMissionConflictDialog(teamId);
        } else {
          // No conflict, proceed with mission creation
          _sendSearchMission(teamId);
        }
      },
      loading: () {
        // If missions are still loading, proceed anyway
        _sendSearchMission(teamId);
      },
      error: (error, stack) {
        // If there's an error loading missions, proceed anyway
        _sendSearchMission(teamId);
      },
    );
  }

  void _showMissionConflictDialog(String teamId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MissionConflictDialog(
        teamId: teamId,
        onCancel: () {
          // Dialog will close automatically, no additional action needed
        },
        onConfirmOverwrite: () {
          _sendSearchMissionWithOverwrite(teamId);
        },
      ),
    );
  }

  void _sendSearchMission(String teamId) {
    // Create SearchMission message
    final searchMissionMessage = _createSearchMissionMessage(teamId);
    //final searchMissionMessage = _createSpecificSearchMissionMessage();

    // Send to ROS topic
    ref.read(rosClientProvider.notifier).publishToTopic(
          topicName: '/search_mission',
          messageType: 'auspex_msgs/msg/SearchMission',
          message: searchMissionMessage,
        );

    // Clear everything
    setState(() {
      _definedAreas.clear();
      _currentPoints.clear();
      _currentAreaType = null;
      _isDefiningArea = false;
      _selectedDetectionClasses.clear();
      _updateMapOverlays();
    });

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Search mission sent to $teamId successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteMissionAndGoals(String teamId) async {
    try {
      final redisProvider = ref.read(redisClientProvider.notifier);
      bool success = await redisProvider.deleteMission(teamId);

      if (!success) {
        debugPrint('Warning: Failed to delete existing mission for team $teamId');
        // Continue anyway since we want to create the new mission
      }
    } catch (e) {
      debugPrint('Error deleting existing mission for team $teamId: $e');
      // Continue anyway since we want to create the new mission
    }
  }

  void _sendSearchMissionWithOverwrite(String teamId) async {
    try {
      // First delete the existing mission and its goals
      await _deleteMissionAndGoals(teamId);

      // Then proceed with normal mission creation
      _sendSearchMission(teamId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error overwriting mission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _createSearchMissionMessage(String teamId) {
    // Find search area (required)
    final searchAreas = _definedAreas
        .where((area) => area.type == AreaType.searchArea)
        .toList();
    final noFlyZones =
        _definedAreas.where((area) => area.type == AreaType.noFlyZone).toList();
    final poisList = _definedAreas
        .where((area) => area.type == AreaType.pointOfInterest)
        .toList();
    final prioAreas = _definedAreas
        .where((area) => area.type == AreaType.areaOfInterest)
        .toList();

    // Use first search area as main search area, or create default if none
    if (searchAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please define at least one Search Area before creating a mission.'),
          backgroundColor: Colors.red,
        ),
      );
      return {};
    }

    // Convert all search areas to the new format
    final allSearchAreas = searchAreas
        .map((area) => _createAreaMessage(area, 1)) // AREA_TYPE_SEARCH = 1
        .toList();

    // Starting point - use first point of first search area or leave empty
    Map<String, dynamic>? startingPoint;
    if (searchAreas.first.points.isNotEmpty) {
      startingPoint = _createGeoPointMessage(searchAreas.first.points.first);
    }

    return {
      'header': {
        'stamp': {
          'sec': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'nanosec': (DateTime.now().millisecondsSinceEpoch % 1000) * 1000000,
        },
        'frame_id': 'map',
      },
      'mission_status': 'UNPROCESSED',
      'team_id': teamId,
      'platform_class': {
        'value': teamId == 'drone_team'
            ? 0
            : 1, // PLATFORM_CLASS_DRONE = 0, PLATFORM_CLASS_UL = 1
      },
      'search_areas': allSearchAreas,
      'no_fly_zones': noFlyZones
          .map((area) => _createAreaMessage(area, 0))
          .toList(), // AREA_TYPE_NO_FLY = 0
      'max_height': 120, // Default max height in meters AGL
      'min_height': 10, // Default min height in meters AGL
      'desired_ground_dist': 25, // Default desired ground distance in meters
      'starting_point': startingPoint,
      'target_objects': _selectedDetectionClasses.toList(),
      'mission_goal': 'Search',
      'pois': poisList
          .expand((area) =>
              area.points.map((point) => _createGeoPointMessage(point)))
          .toList(),
      'prio_areas': prioAreas
          .map((area) => _createAreaMessage(area, 3))
          .toList(), // AREA_TYPE_H_PRIO = 3
      'sensor_mode': {
        'value': 0, // SENSOR_MODE_EO = 0 (electro-optical)
      },
      'danger_zones': [], // Empty for now, could be extended later
    };
  }

  Map<String, dynamic> _createSpecificSearchMissionMessage() {
    // Returns a hardcoded search mission for testing purposes
    return {
      'header': {
        'stamp': {
          'sec': 1738333629,
          'nanosec': 533620559,
        },
        'frame_id': '0',
      },
      'team_id': 'drone_team',
      'platform_class': {
        'value': 0,
      },
      'search_areas': [
        {
          'type': 1,
          'description': 'drone_search_area_1',
          'points': [
            {
              'latitude': 48.075448620490825,
              'longitude': 11.63843100438668,
              'altitude': 0.0,
            },
            {
              'latitude': 48.075232103189116,
              'longitude': 11.637312006912072,
              'altitude': 0.0,
            },
            {
              'latitude': 48.074612994002244,
              'longitude': 11.637706947197229,
              'altitude': 0.0,
            },
            {
              'latitude': 48.07483966325749,
              'longitude': 11.638760121290977,
              'altitude': 0.0,
            },
          ],
        },
        {
          'type': 1,
          'description': 'drone_search_area_2',
          'points': [
            {
              'latitude': 48.07673079022151,
              'longitude': 11.63866391789119,
              'altitude': 0.0,
            },
            {
              'latitude': 48.076507512303564,
              'longitude': 11.637134790120458,
              'altitude': 0.0,
            },
            {
              'latitude': 48.07588165236903,
              'longitude': 11.63742340032884,
              'altitude': 0.0,
            },
            {
              'latitude': 48.07614552937779,
              'longitude': 11.638886704718713,
              'altitude': 0.0,
            },
          ],
        },
      ],
      'no_fly_zones': [
        {
          'type': 0,
          'description': 'no fly zone 1',
          'points': [
            {
              'latitude': 48.075591654536304,
              'longitude': 11.639567827465772,
              'altitude': 0.0,
            },
            {
              'latitude': 48.075491068979,
              'longitude': 11.639051678923488,
              'altitude': 0.0,
            },
            {
              'latitude': 48.0750567925696,
              'longitude': 11.639285857428785,
              'altitude': 0.0,
            },
            {
              'latitude': 48.075155782367816,
              'longitude': 11.639787668511559,
              'altitude': 0.0,
            },
          ],
        },
        {
          'type': 0,
          'description': 'no fly zone 2',
          'points': [
            {
              'latitude': 48.07618930352927, 
              'longitude': 11.639290705886408,
              'altitude': 0.0,
            },
            {
              'latitude': 48.07618101215974, 
              'longitude': 11.639170746485453,
              'altitude': 0.0,
            },
            {
              'latitude': 48.075799607716256, 
              'longitude': 11.639352753852418,
              'altitude': 0.0,
            },
            {
              'latitude': 48.075799607716256,
              'longitude': 11.63947271325337,
              'altitude': 0.0,
            },
          ],
        },
      ],
      'max_height': 150,
      'min_height': 5,
      'desired_ground_dist': 25,
      'starting_point': {
        'latitude': 48.07569676896987,
        'longitude': 11.63853516192711,
        'altitude': 0.0,
      },
      'target_objects': ['person'],
      'mission_goal': '',
      'pois': [],
      'prio_areas': [],
      'sensor_mode': {
        'value': 0,
      },
      'danger_zones': [],
    };
  }

  Map<String, dynamic> _createAreaMessage(AreaDefinition area, int areaType) {
    return {
      'type': areaType,
      'description': area.name,
      'points':
          area.points.map((point) => _createGeoPointMessage(point)).toList(),
    };
  }

  Map<String, dynamic> _createGeoPointMessage(LatLng point) {
    return {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'altitude': 0.0, // Default altitude
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map with defined areas
          MissionMapWidget(
            onMapTapped: _handleMapTap,
            onDrawerStateChanged: (isOpen) {
              setState(() {
                _isPlanDrawerOpen = isOpen;
              });
            },
            onEditModeEntered: _onEditModeEntered,
            onEditModeExited: _onEditModeExited,
            tempMarkers: _tempMarkers,
            tempPolylines: _tempPolylines,
            areaMarkers: _areaMarkers,
            areaPolygons: _areaPolygons,
            areaPolylines: _areaPolylines,
          ),

          // Control panel
          if (!_shouldHideUIElements)
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                width: 280,
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
                          const Icon(Icons.layers, color: Colors.white),
                          const SizedBox(width: 8),
                          const Text(
                            'Area Management',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isDefiningArea) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add New Area:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Area type buttons
                            ...AreaType.values.map(
                              (type) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _startAreaDefinition(type),
                                    icon:
                                        Icon(_getAreaTypeIcon(type), size: 18),
                                    label: Text(_getAreaTypeName(type)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _getAreaTypeColor(type)
                                          .withAlpha(204),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),

                            // Detection Classes Section
                            const Text(
                              'Detection Classes:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Detection classes chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _availableDetectionClasses
                                  .map(
                                    (className) => FilterChip(
                                      label: Text(
                                        className,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _selectedDetectionClasses
                                                  .contains(className)
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      selected: _selectedDetectionClasses
                                          .contains(className),
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedDetectionClasses
                                                .add(className);
                                          } else {
                                            _selectedDetectionClasses
                                                .remove(className);
                                          }
                                        });
                                      },
                                      selectedColor: AppColors.primary,
                                      checkmarkColor: Colors.white,
                                      backgroundColor: Colors.grey[200],
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  )
                                  .toList(),
                            ),

                            if (_selectedDetectionClasses.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(26),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.green.withAlpha(77)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            size: 16, color: Colors.green[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Selected: ${_selectedDetectionClasses.length} classes',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedDetectionClasses.join(', '),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withAlpha(26),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.orange.withAlpha(77)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber,
                                        size: 16, color: Colors.orange[600]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'No detection classes selected',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Defining ${_getAreaTypeName(_currentAreaType!)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Points: ${_currentPoints.length}${_getPointsStatusText()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _canFinishAreaDefinition()
                                        ? _finishAreaDefinition
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
                                    onPressed: _cancelAreaDefinition,
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
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Area list and Create Mission button
          if (_definedAreas.isNotEmpty && !_isDefiningArea)
            Positioned(
              bottom: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Create Mission Button
                  Container(
                    width: 250,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton.icon(
                      onPressed: _createMission,
                      icon: const Icon(Icons.send, size: 20),
                      label: const Text(
                        'Create Mission',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Area list
                  Container(
                    width: 250,
                    constraints: const BoxConstraints(maxHeight: 250),
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.list, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Defined Areas',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _definedAreas.length,
                            itemBuilder: (context, index) {
                              final area = _definedAreas[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  _getAreaTypeIcon(area.type),
                                  color: area.color.withAlpha(204),
                                  size: 20,
                                ),
                                title: Text(
                                  area.name,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${area.points.length} points',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, size: 18),
                                  onPressed: () => _removeArea(area.id),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Voice control in bottom right (when no areas are defined and not defining areas and drawer is closed)
          if (!_isDefiningArea &&
              _definedAreas.isEmpty &&
              !_isPlanDrawerOpen &&
              !_shouldHideUIElements)
            Positioned(
              bottom: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 200,
                    child: SpeechBubble(
                      textStream: _textStreamController.stream,
                      onAccept: (modifiedText) {
                        debugPrint("Accepted text: $modifiedText");
                      },
                      onClear: _clearSpeechStream,
                    ),
                  ),
                  const SizedBox(height: 10),
                  MicButton(textStreamController: _textStreamController),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
