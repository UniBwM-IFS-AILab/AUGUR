import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Represents a sensor mode from auspex_msgs/SensorMode.msg
enum SensorMode {
  electroOptical(0),
  infraRed(1);

  const SensorMode(this.value);
  final int value;

  String get name {
    switch (this) {
      case SensorMode.electroOptical:
        return 'Electro-Optical';
      case SensorMode.infraRed:
        return 'Infra-Red';
    }
  }

  static SensorMode fromValue(int value) {
    switch (value) {
      case 0:
        return SensorMode.electroOptical;
      case 1:
        return SensorMode.infraRed;
      default:
        return SensorMode.electroOptical;
    }
  }
}

/// Represents a platform class from auspex_msgs/PlatformClass.msg
enum PlatformClass {
  drone(0),
  ultraLight(1),
  other(2);

  const PlatformClass(this.value);
  final int value;

  String get name {
    switch (this) {
      case PlatformClass.drone:
        return 'Drone';
      case PlatformClass.ultraLight:
        return 'Ultra-Light Aircraft';
      case PlatformClass.other:
        return 'Other';
    }
  }

  static PlatformClass fromValue(int value) {
    switch (value) {
      case 0:
        return PlatformClass.drone;
      case 1:
        return PlatformClass.ultraLight;
      case 2:
        return PlatformClass.other;
      default:
        return PlatformClass.other;
    }
  }
}

/// Represents an area type from auspex_msgs/Area.msg
enum AreaType {
  noFly(0),
  search(1),
  danger(2),
  highPriority(3);

  const AreaType(this.value);
  final int value;

  String get name {
    switch (this) {
      case AreaType.noFly:
        return 'No Fly Zone';
      case AreaType.search:
        return 'Search Area';
      case AreaType.danger:
        return 'Danger Area';
      case AreaType.highPriority:
        return 'High Priority Area';
    }
  }

  Color get color {
    switch (this) {
      case AreaType.noFly:
        return Colors.red.withOpacity(0.3);
      case AreaType.search:
        return Colors.green
            .withOpacity(0.3); // Changed to green to match mission creation
      case AreaType.danger:
        return Colors.orange.withOpacity(0.3);
      case AreaType.highPriority:
        return Colors.blue
            .withOpacity(0.3); // Changed to blue to match mission creation
    }
  }

  Color get borderColor {
    switch (this) {
      case AreaType.noFly:
        return Colors.red;
      case AreaType.search:
        return Colors.green; // Changed to green to match mission creation
      case AreaType.danger:
        return Colors.orange;
      case AreaType.highPriority:
        return Colors.blue; // Changed to blue to match mission creation
    }
  }

  static AreaType fromValue(int value) {
    switch (value) {
      case 0:
        return AreaType.noFly;
      case 1:
        return AreaType.search;
      case 2:
        return AreaType.danger;
      case 3:
        return AreaType.highPriority;
      default:
        return AreaType.search;
    }
  }
}

/// Represents a geographic point with latitude, longitude, and altitude
class GeoPoint {
  final double latitude;
  final double longitude;
  final double altitude; // in meters AGL

  GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  factory GeoPoint.fromMessage(Map<String, dynamic> message) {
    return GeoPoint(
      latitude:
          double.tryParse(message['latitude']?.toString() ?? '0.0') ?? 0.0,
      longitude:
          double.tryParse(message['longitude']?.toString() ?? '0.0') ?? 0.0,
      altitude:
          double.tryParse(message['altitude']?.toString() ?? '0.0') ?? 0.0,
    );
  }

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toMessage() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeoPoint &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude;
  }

  @override
  int get hashCode =>
      latitude.hashCode ^ longitude.hashCode ^ altitude.hashCode;
}

/// Represents an area from auspex_msgs/Area.msg
class Area {
  final AreaType type;
  final String description;
  final List<GeoPoint> points;

  Area({
    required this.type,
    required this.description,
    required this.points,
  });

  factory Area.fromMessage(Map<String, dynamic> message) {
    List<GeoPoint> pointsList = [];
    if (message.containsKey('points') && message['points'] is List) {
      pointsList = (message['points'] as List)
          .map((point) => GeoPoint.fromMessage(point))
          .toList();
    }

    return Area(
      type: AreaType.fromValue(
          int.tryParse(message['type']?.toString() ?? '1') ?? 1),
      description: message['description']?.toString() ?? '',
      points: pointsList,
    );
  }

  List<LatLng> get latLngPoints => points.map((p) => p.latLng).toList();

  Map<String, dynamic> toMessage() {
    return {
      'type': type.value,
      'description': description,
      'points': points.map((point) => point.toMessage()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Area &&
        other.type == type &&
        other.description == description &&
        other.points.length == points.length;
  }

  @override
  int get hashCode =>
      type.hashCode ^ description.hashCode ^ points.length.hashCode;
}

/// Represents a Mission from auspex_msgs/SearchMission.msg
class Mission {
  final String teamId; // Unique identifier for the mission
  PlatformClass platformClass;
  List<Area> searchAreas;
  List<Area> noFlyZones;
  int maxHeight; // in meters AGL
  int minHeight; // in meters AGL
  int desiredGroundDistance; // in meters above ground
  GeoPoint startingPoint;
  List<String> targetObjects;
  String missionGoal;
  List<GeoPoint> pois; // Points of Interest
  List<Area> priorityAreas;
  SensorMode sensorMode;
  List<Area> dangerZones;

  // Visual and management properties
  Color color;
  DateTime lastUpdated;

  Mission({
    required this.teamId,
    required this.platformClass,
    required this.searchAreas,
    required this.noFlyZones,
    required this.maxHeight,
    required this.minHeight,
    required this.desiredGroundDistance,
    required this.startingPoint,
    required this.targetObjects,
    required this.missionGoal,
    required this.pois,
    required this.priorityAreas,
    required this.sensorMode,
    required this.dangerZones,
    required this.color,
  }) : lastUpdated = DateTime.now();

  /// Creates a Mission instance from a ROS message map
  factory Mission.fromMessage(
    Map<String, dynamic> message,
    Color assignedColor,
  ) {
    // Parse platform class
    PlatformClass platformClass = PlatformClass.other;
    if (message.containsKey('platform_class') &&
        message['platform_class'] is Map) {
      final platformClassMap =
          message['platform_class'] as Map<String, dynamic>;
      final value = platformClassMap['value'];
      int platformClassValue = 0; // default to 'other'

      platformClassValue = int.tryParse(value?.toString() ?? '0') ?? 0;

      platformClass = PlatformClass.fromValue(platformClassValue);
    }

    // Parse search areas
    List<Area> searchAreas = [];
    if (message.containsKey('search_areas') &&
        message['search_areas'] is List) {
      searchAreas = (message['search_areas'] as List)
          .map((searchAreaData) => Area.fromMessage(searchAreaData))
          .toList();
    }

    // If no search areas found, create a default empty one
    if (searchAreas.isEmpty) {
      searchAreas = [
        Area(type: AreaType.search, description: 'Search Area', points: [])
      ];
    }

    // Parse no fly zones
    List<Area> noFlyZones = [];
    if (message.containsKey('no_fly_zones') &&
        message['no_fly_zones'] is List) {
      noFlyZones = (message['no_fly_zones'] as List)
          .map((zone) => Area.fromMessage(zone))
          .toList();
    }

    // Parse starting point
    GeoPoint startingPoint =
        GeoPoint(latitude: 0.0, longitude: 0.0, altitude: 0.0);
    if (message.containsKey('starting_point') &&
        message['starting_point'] is Map) {
      startingPoint = GeoPoint.fromMessage(message['starting_point']);
    }

    // Parse target objects
    List<String> targetObjects = [];
    if (message.containsKey('target_objects') &&
        message['target_objects'] is List) {
      targetObjects = (message['target_objects'] as List)
          .map((obj) => obj.toString())
          .toList();
    }

    // Parse POIs
    List<GeoPoint> pois = [];
    if (message.containsKey('pois') && message['pois'] is List) {
      pois = (message['pois'] as List)
          .map((poi) => GeoPoint.fromMessage(poi))
          .toList();
    }

    // Parse priority areas
    List<Area> priorityAreas = [];
    if (message.containsKey('prio_areas') && message['prio_areas'] is List) {
      priorityAreas = (message['prio_areas'] as List)
          .map((area) => Area.fromMessage(area))
          .toList();
    }

    // Parse sensor mode
    SensorMode sensorMode = SensorMode.electroOptical;
    if (message.containsKey('sensor_mode') && message['sensor_mode'] is Map) {
      final sensorModeMap = message['sensor_mode'] as Map<String, dynamic>;
      final value = sensorModeMap['value'];
      int sensorModeValue = 0; // default to electroOptical

      sensorModeValue = int.tryParse(value?.toString() ?? '0') ?? 0;

      sensorMode = SensorMode.fromValue(sensorModeValue);
    }

    // Parse danger zones
    List<Area> dangerZones = [];
    if (message.containsKey('danger_zones') &&
        message['danger_zones'] is List) {
      dangerZones = (message['danger_zones'] as List)
          .map((zone) => Area.fromMessage(zone))
          .toList();
    }

    return Mission(
      teamId: message['team_id']?.toString() ?? '',
      platformClass: platformClass,
      searchAreas: searchAreas,
      noFlyZones: noFlyZones,
      maxHeight:
          (int.tryParse(message['max_height']?.toString() ?? '100') ?? 100),
      minHeight: (int.tryParse(message['min_height']?.toString() ?? '5') ?? 5),
      desiredGroundDistance:
          (int.tryParse(message['desired_ground_dist']?.toString() ?? '50') ??
              50),
      startingPoint: startingPoint,
      targetObjects: targetObjects,
      missionGoal: message['mission_goal']?.toString() ?? '',
      pois: pois,
      priorityAreas: priorityAreas,
      sensorMode: sensorMode,
      dangerZones: dangerZones,
      color: assignedColor,
    );
  }

  /// Updates the mission from a new message
  void updateFromMessage(Map<String, dynamic> message) {
    // Update platform class if present
    if (message.containsKey('platform_class') &&
        message['platform_class'] is Map) {
      final platformClassMap =
          message['platform_class'] as Map<String, dynamic>;
      final value = platformClassMap['value'];
      int platformClassValue =
          platformClass.value; // keep current value as default

      platformClassValue =
          int.tryParse(value?.toString() ?? platformClass.value.toString()) ??
              platformClass.value;

      platformClass = PlatformClass.fromValue(platformClassValue);
    }

    // Update search areas if present
    if (message.containsKey('search_areas') &&
        message['search_areas'] is List) {
      searchAreas.clear();
      searchAreas.addAll((message['search_areas'] as List)
          .map((searchAreaData) => Area.fromMessage(searchAreaData))
          .toList());
    }

    // Update no fly zones if present
    if (message.containsKey('no_fly_zones') &&
        message['no_fly_zones'] is List) {
      noFlyZones.clear();
      noFlyZones.addAll((message['no_fly_zones'] as List)
          .map((zone) => Area.fromMessage(zone))
          .toList());
    }

    // Update heights if present
    if (message.containsKey('max_height')) {
      maxHeight = int.tryParse(message['max_height'].toString()) ?? maxHeight;
    }
    if (message.containsKey('min_height')) {
      minHeight = int.tryParse(message['min_height'].toString()) ?? minHeight;
    }
    if (message.containsKey('desired_ground_dist')) {
      desiredGroundDistance =
          int.tryParse(message['desired_ground_dist'].toString()) ??
              desiredGroundDistance;
    }

    // Update starting point if present
    if (message.containsKey('starting_point') &&
        message['starting_point'] is Map) {
      startingPoint = GeoPoint.fromMessage(message['starting_point']);
    }

    // Update target objects if present
    if (message.containsKey('target_objects') &&
        message['target_objects'] is List) {
      targetObjects.clear();
      targetObjects.addAll((message['target_objects'] as List)
          .map((obj) => obj.toString())
          .toList());
    }

    // Update mission goal if present
    if (message.containsKey('mission_goal')) {
      missionGoal = message['mission_goal']?.toString() ?? missionGoal;
    }

    // Update POIs if present
    if (message.containsKey('pois') && message['pois'] is List) {
      pois.clear();
      pois.addAll((message['pois'] as List)
          .map((poi) => GeoPoint.fromMessage(poi))
          .toList());
    }

    // Update priority areas if present
    if (message.containsKey('prio_areas') && message['prio_areas'] is List) {
      priorityAreas.clear();
      priorityAreas.addAll((message['prio_areas'] as List)
          .map((area) => Area.fromMessage(area))
          .toList());
    }

    // Update sensor mode if present
    if (message.containsKey('sensor_mode') && message['sensor_mode'] is Map) {
      final sensorModeMap = message['sensor_mode'] as Map<String, dynamic>;
      final value = sensorModeMap['value'];
      int sensorModeValue = 0; // default to electroOptical

      sensorModeValue = int.tryParse(value?.toString() ?? '0') ?? 0;

      sensorMode = SensorMode.fromValue(sensorModeValue);
    }

    // Update danger zones if present
    if (message.containsKey('danger_zones') &&
        message['danger_zones'] is List) {
      dangerZones.clear();
      dangerZones.addAll((message['danger_zones'] as List)
          .map((zone) => Area.fromMessage(zone))
          .toList());
    }

    lastUpdated = DateTime.now();
  }

  /// Get all areas combined (for easy iteration)
  List<Area> get allAreas {
    List<Area> areas = [...searchAreas];
    areas.addAll(noFlyZones);
    areas.addAll(priorityAreas);
    areas.addAll(dangerZones);
    return areas;
  }

  /// Convert mission back to message format for Redis storage
  Map<String, dynamic> toMessage() {
    return {
      'team_id': teamId,
      'platform_class': {'value': platformClass.value},
      'search_areas': searchAreas.map((area) => area.toMessage()).toList(),
      'no_fly_zones': noFlyZones.map((zone) => zone.toMessage()).toList(),
      'max_height': maxHeight,
      'min_height': minHeight,
      'desired_ground_dist': desiredGroundDistance,
      'starting_point': startingPoint.toMessage(),
      'target_objects': targetObjects,
      'mission_goal': missionGoal,
      'pois': pois.map((poi) => poi.toMessage()).toList(),
      'prio_areas': priorityAreas.map((area) => area.toMessage()).toList(),
      'sensor_mode': {'value': sensorMode.value},
      'danger_zones': dangerZones.map((zone) => zone.toMessage()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Mission && other.teamId == teamId;
  }

  @override
  int get hashCode => teamId.hashCode;

  @override
  String toString() {
    return 'Mission(teamId: $teamId, platformClass: ${platformClass.name}, missionGoal: $missionGoal)';
  }
}
