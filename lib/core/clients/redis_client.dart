import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:augur/ui/utils/waypoint_utils.dart' show resolveStringWP;
import 'package:augur/ui/utils/app_colors.dart' show AppColors;
import 'package:augur/core/classes/plan.dart';
import 'package:augur/core/classes/platform.dart';
import 'package:augur/core/classes/mission.dart';
import 'package:augur/core/classes/detected_object.dart';
import 'package:redis/redis.dart';

class RedisClient {
  final String redisIp;
  RedisConnection? _connection;
  Command? _command;
  bool _isConnected = false;
  bool isTrajectoryOn = false;
  Function()? onConnectionLost;

  final StreamController<List<Platform>> _platformStreamController =
      StreamController<List<Platform>>.broadcast();
  final StreamController<List<Map<String, dynamic>>>
      _trajectoryStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<String>> _teamIdsStreamController =
      StreamController<List<String>>.broadcast();
  final StreamController<List<Plan>> _planStreamController =
      StreamController<List<Plan>>.broadcast();
  final StreamController<List<Mission>> _missionsStreamController =
      StreamController<List<Mission>>.broadcast();
  final StreamController<List<DetectedObject>> _detectedObjectsStreamController =
      StreamController<List<DetectedObject>>.broadcast();

  // Cache current team IDs to replay to new listeners
  List<String> _currentTeamIds = [];

  Stream<List<Platform>> get platformStream => _platformStreamController.stream;
  Stream<List<Map<String, dynamic>>> get trajectoryStream =>
      _trajectoryStreamController.stream;
  Stream<List<String>> get teamIdsStream async* {
    // First emit the current cached value
    yield _currentTeamIds;
    // Then emit all future updates
    await for (final teamIds in _teamIdsStreamController.stream) {
      yield teamIds;
    }
  }
  Stream<List<Plan>> get planStream => _planStreamController.stream;
  Stream<List<Mission>> get missionsStream => _missionsStreamController.stream;
  Stream<List<DetectedObject>> get detectedObjectsStream => _detectedObjectsStreamController.stream;

  // Getters for connection state and command
  bool get isConnected => _isConnected;
  Command? get command => _command;

  Timer? _timer50ms;
  Timer? _timer1000ms;
  Timer? _timer5000ms;

  List<Map<String, dynamic>>? _lastPlatformState;
  List<Map<String, dynamic>>? _lastTrajectoryState;
  List<Map<String, dynamic>>? _lastPlanListState;
  List<Map<String, dynamic>>? _lastMissionListState;
  List<Map<String, dynamic>>? _lastDetectedObjectsState;

  // Plan management
  final Map<int, Plan> _plans = {};
  final List<Color> _colors = [
    Color(0xFF2196F3), // Primary blue
    Color(0xFF4CAF50), // Green
    Color(0xFFF44336), // Red
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF9800), // Orange
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE91E63), // Pink
    Color(0xFF009688), // Teal
    Color(0xFF795548), // Brown
    Color(0xFF3F51B5), // Indigo
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF00BCD4), // Cyan
  ];

  // Platform management
  final Map<String, Platform> _platforms = {};
  final List<Color> _platformColors = [
    AppColors.primary,
    AppColors.secondary,
    Color(0xFF2196F3), // Primary blue
    Color(0xFF4CAF50), // Green
    Color(0xFFF44336), // Red
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF9800), // Orange
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE91E63), // Pink
    Color(0xFF009688), // Teal
    Color(0xFF795548), // Brown
    Color(0xFF3F51B5), // Indigo
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF00BCD4), // Cyan
  ];

  // Mission management
  final Map<String, Mission> _missions = {};
  final List<Color> _missionColors = [
    Color(0xFF1976D2), // Deep blue
    Color(0xFF388E3C), // Dark green
    Color(0xFFD32F2F), // Dark red
    Color(0xFF7B1FA2), // Dark purple
    Color(0xFFF57C00), // Dark orange
    Color(0xFF455A64), // Dark blue grey
    Color(0xFF5D4037), // Dark brown
    Color(0xFF00796B), // Dark teal
    Color(0xFFC2185B), // Dark pink
    Color(0xFF303F9F), // Dark indigo
  ];

  // Detected objects management
  final Map<String, DetectedObject> _detectedObjects = {};

  RedisClient({required this.redisIp, required this.onConnectionLost});

  Future<void> connect() async {
    if (_isConnected) {
      debugPrint("RedisClient: Already connected.");
      return;
    }

    _connection = RedisConnection();

    try {
      _command = await _connection?.connect(redisIp, 6379);
      await _command!.send_object(["AUTH", "default", "auspex_db"]);
      debugPrint("RedisClient: Connected to Redis at $redisIp:6379");

      _isConnected = true;

      // Seed streams with initial empty values to prevent loading state
      _currentTeamIds = [];
      _teamIdsStreamController.add(_currentTeamIds);

      // Start with more reasonable update frequencies to prevent excessive rebuilds
      _timer50ms = Timer.periodic(
          Duration(milliseconds: 100),
          (_) =>
              fetchPlatformData()); // Platform data: 100ms for real-time position updates
      _timer1000ms = Timer.periodic(Duration(milliseconds: 2000), (_) {
        fetchPlatformTrajectories(); // Trajectory data: 2s
        fetchDetectedObjects(); // Detected objects: 2s
      });
      _timer5000ms = Timer.periodic(Duration(milliseconds: 5000),
          (_) => fetchGeneralData()); // Plan/mission data: 10s (less frequent)
    } catch (e) {
      debugPrint("RedisClient: Connection Error: $e");
      _isConnected = false;
      debugPrint("RedisClient: Calling onConnectionLost from connect method");
      onConnectionLost?.call();
    }
  }

  Future<void> fetchPlatformData() async {
    try {
      var values = await _command!.send_object(['JSON.GET', 'platform', "\$"]);
      List<Map<String, dynamic>> platformStates = [];

      if (values != null) {
        final outerList = jsonDecode(values) as List<dynamic>;
        platformStates = List<Map<String, dynamic>>.from(outerList.first);
      }

      // Check for significant changes before processing
      bool hasSignificantChanges = await _hasSignificantPlatformChanges(
          _lastPlatformState ?? [], platformStates);

      if (hasSignificantChanges || _lastPlatformState == null) {
        // Process platforms and resolve home positions FIRST
        await _processPlatformsWithHomePositions(platformStates);

        // Handle team IDs - extract unique team IDs from platform data
        List<String> teamIds = _platforms.values
            .map((platform) => platform.teamId)
            .where((teamId) => teamId.isNotEmpty)
            .toSet() // Remove duplicates
            .toList();
        teamIds.sort(); // Sort for consistent ordering
        
        // Cache the current team IDs and emit to stream
        _currentTeamIds = teamIds;
        _teamIdsStreamController.add(teamIds);

        // Emit stream updates since there are significant changes
        _platformStreamController.add(List.from(_platforms.values));

        // Update the last state for next comparison
        _lastPlatformState = List.from(platformStates);
      }
    } catch (e) {
      debugPrint("RedisClient: Error fetching platform data: $e");
      reconnect();
    }
  }

  // Process platform data and create Platform objects
  Future<void> _processPlatformsWithHomePositions(
      List<Map<String, dynamic>> platformStates) async {
    final currentPlatformIds =
        platformStates.map((e) => e['platform_id'] as String).toSet();

    // Process active platforms
    for (var platformData in platformStates) {
      final platformId = platformData['platform_id'] as String;

      // Check if platform data is complete enough to process
      // Skip if only platform_id is present (initial name insertion)
      if (!_isPlatformDataComplete(platformData)) {
        debugPrint(
            "RedisClient: Skipping incomplete platform data for $platformId - waiting for full update");
        continue;
      }

      final platformStatus = platformData['platform_status']?.toString() ?? '';

      // Handle platform based on its status
      if (platformStatus == 'DISCONNECTED') {
        // For disconnected platforms: remove home position and set disconnected marker
        String location = "home_$platformId";
        
        // Delete home position from Redis
        try {
          await _command!.send_object(['JSON.DEL', 'waypoint', '\$[?(@.name == "$location")]']);
          debugPrint("RedisClient: Deleted home position for disconnected platform $platformId");
        } catch (e) {
          debugPrint("RedisClient: Error deleting home position for platform $platformId: $e");
        }
        
        // Remove home position from platform data
        platformData.remove('home_position');
        
        // Create or update Platform object with disconnected state
        if (_platforms.containsKey(platformId)) {
          _platforms[platformId]!.updateFromMessage(platformData);
        } else {
          final color = _assignPlatformColor();
          _platforms[platformId] = Platform.fromMessage(platformData, color);
        }
        
        debugPrint("RedisClient: Platform $platformId marked as DISCONNECTED with home position removed");
      } else {
        // For connected platforms: ensure home position is set
        String location = "home_$platformId";
        var homeWp = await resolveStringWP(_command!, location);
        if (homeWp['latitude'] != 0.0 || homeWp['longitude'] != 0.0) {
          platformData['home_position'] = homeWp;
        }

        // Create or update Platform object
        if (_platforms.containsKey(platformId)) {
          // Update existing platform
          _platforms[platformId]!.updateFromMessage(platformData);
        } else {
          // Create new platform with assigned color
          final color = _assignPlatformColor();
          _platforms[platformId] = Platform.fromMessage(platformData, color);
        }
      }
    }

    // Handle platforms that are no longer in the current state
    final lastPlatformIds =
        _lastPlatformState?.map((e) => e['platform_id'] as String).toSet() ??
            <String>{};
    final disconnectedIds = lastPlatformIds.difference(currentPlatformIds);

    for (String disconnectedId in disconnectedIds) {
      if (_platforms.containsKey(disconnectedId)) {
        final platform = _platforms[disconnectedId]!;
        if (platform.status != 'DISCONNECTED') {
          // Delete home position from Redis
          String location = "home_$disconnectedId";
          try {
            await _command!.send_object(['JSON.DEL', 'waypoint', '\$[?(@.name == "$location")]']);
            debugPrint("RedisClient: Deleted home position for removed platform $disconnectedId");
          } catch (e) {
            debugPrint("RedisClient: Error deleting home position for platform $disconnectedId: $e");
          }
          
          // Create disconnected platform data
          final disconnectedData = platform.toMap();
          disconnectedData['platform_status'] = 'DISCONNECTED';
          disconnectedData.remove('home_position');
          platform.updateFromMessage(disconnectedData);
          debugPrint("RedisClient: Platform $disconnectedId marked as DISCONNECTED");
        }
      }
    }
  }

  // Check if platform data contains enough information to create a Platform object
  bool _isPlatformDataComplete(Map<String, dynamic> platformData) {
    // Essential fields that must be present for a complete platform message
    final requiredFields = [
      'platform_id',
      'team_id',
      // 'platform_gps_position',
      // 'platform_pose',
      // 'platform_status'
    ];

    // Check if all required fields are present and not null
    for (String field in requiredFields) {
      if (!platformData.containsKey(field) || platformData[field] == null) {
        return false;
      }
    }

    // Additional check for nested required fields
    final gpsPosition = platformData['platform_gps_position'];
    if (gpsPosition is Map<String, dynamic>) {
      if (!gpsPosition.containsKey('latitude') ||
          !gpsPosition.containsKey('longitude')) {
        return false;
      }
    } else {
      return false;
    }

    final pose = platformData['platform_pose'];
    if (pose is Map<String, dynamic>) {
      final orientation = pose['orientation'];
      if (orientation is Map<String, dynamic>) {
        final orientationKeys = ['x', 'y', 'z', 'w'];
        for (String key in orientationKeys) {
          if (!orientation.containsKey(key)) {
            return false;
          }
        }
      } else {
        return false;
      }
    } else {
      return false;
    }

    return true;
  }

  // Assign a color to a new platform
  Color _assignPlatformColor() {
    if (_platformColors.isNotEmpty) {
      final color = _platformColors.removeAt(0);
      return color;
    }
    // If all colors are used, return a default color
    return Colors.grey;
  }

  Future<void> fetchPlatformTrajectories() async {
    try {
      if (isTrajectoryOn) {
        var values = await _command!.send_object(['JSON.GET', 'platform_history', "\$"]);
        if (values != null) {
          final outerList = jsonDecode(values) as List<dynamic>;
          List<Map<String, dynamic>> platformHistories =
              List<Map<String, dynamic>>.from(outerList.first);

          // Convert platform histories to trajectory points
          List<Map<String, dynamic>> trajectories = _convertHistoriesToTrajectories(platformHistories);

          // More efficient trajectory comparison
          bool hasTrajectoryChanges = _lastTrajectoryState == null ||
              _lastTrajectoryState!.length != trajectories.length ||
              _hasSignificantTrajectoryChanges(
                  _lastTrajectoryState!, trajectories);

          if (hasTrajectoryChanges) {
            _lastTrajectoryState = List.from(trajectories);
            _trajectoryStreamController.add(trajectories);
          }
        }
      } else {
        // Only send empty list if we previously had trajectories
        if (_lastTrajectoryState != null && _lastTrajectoryState!.isNotEmpty) {
          _lastTrajectoryState = [];
          _trajectoryStreamController.add([]);
        }
      }
    } catch (e) {
      debugPrint("RedisClient: Error fetching trajectory data: $e");
      reconnect();
    }
  }

  /// Convert platform histories to trajectory points
  /// Input format: [{platform_id: [platform_state1, platform_state2, ...]}, ...]
  /// Output format: [{platform_id: "...", trajectory: [{lat: ..., lon: ...}, ...]}, ...]
  List<Map<String, dynamic>> _convertHistoriesToTrajectories(
      List<Map<String, dynamic>> platformHistories) {
    List<Map<String, dynamic>> trajectories = [];

    for (var platformHistory in platformHistories) {
      // Each map has one key (platform_id) with a list of platform states as value
      platformHistory.forEach((platformId, platformStates) {
        if (platformStates is List && platformStates.isNotEmpty) {
          List<Map<String, dynamic>> trajectoryPoints = [];

          for (var state in platformStates) {
            if (state is Map<String, dynamic> &&
                state.containsKey('platform_gps_position')) {
              var gpsPos = state['platform_gps_position'];
              if (gpsPos != null && gpsPos is Map<String, dynamic>) {
                // Convert to double, handling both string and numeric types
                final latValue = gpsPos['latitude'];
                final lonValue = gpsPos['longitude'];
                
                double? lat;
                double? lon;
                
                if (latValue is num) {
                  lat = latValue.toDouble();
                } else if (latValue is String) {
                  lat = double.tryParse(latValue);
                }
                
                if (lonValue is num) {
                  lon = lonValue.toDouble();
                } else if (lonValue is String) {
                  lon = double.tryParse(lonValue);
                }
                
                // Only add valid GPS positions
                if (lat != null && lon != null &&
                    (lat != 0.0 || lon != 0.0) &&
                    (lat != -1.0 || lon != -1.0)) {
                  trajectoryPoints.add({
                    'lat': lat,
                    'lon': lon,
                  });
                }
              }
            }
          }

          // Only add trajectory if we have valid points
          if (trajectoryPoints.isNotEmpty) {
            trajectories.add({
              'platform_id': platformId,
              'trajectory': trajectoryPoints,
            });
          }
        }
      });
    }

    return trajectories;
  }

  // Check if trajectory data has significant changes
  bool _hasSignificantTrajectoryChanges(
      List<Map<String, dynamic>> oldTrajectories,
      List<Map<String, dynamic>> newTrajectories) {
    if (oldTrajectories.length != newTrajectories.length) return true;

    // For trajectories, we mainly care about new data points being added
    // Simple length and platform ID comparison should be sufficient
    final oldPlatforms = oldTrajectories.map((t) => t['platform_id']).toSet();
    final newPlatforms = newTrajectories.map((t) => t['platform_id']).toSet();

    return !oldPlatforms.containsAll(newPlatforms) ||
        !newPlatforms.containsAll(oldPlatforms);
  }

  // Check if platform data has significant changes, including home position updates
  Future<bool> _hasSignificantPlatformChanges(
      List<Map<String, dynamic>> oldPlatforms,
      List<Map<String, dynamic>> newPlatforms) async {
    // Quick length check
    if (oldPlatforms.length != newPlatforms.length) {
      debugPrint("RedisClient: Platform changes detected - different lengths: ${oldPlatforms.length} vs ${newPlatforms.length}");
      return true;
    }

    // Create maps for efficient comparison
    final oldMap = {for (var platform in oldPlatforms) platform['platform_id']: platform};
    final newMap = {for (var platform in newPlatforms) platform['platform_id']: platform};

    // Check if platform IDs are exactly the same
    final oldIds = oldMap.keys.toSet();
    final newIds = newMap.keys.toSet();
    if (!oldIds.containsAll(newIds) || !newIds.containsAll(oldIds)) {
      debugPrint("RedisClient: Platform changes detected - different platform IDs");
      return true;
    }

    // Check for significant changes in platform data
    for (var platformId in newMap.keys) {
      final oldPlatform = oldMap[platformId];
      final newPlatform = newMap[platformId];

      if (oldPlatform == null || newPlatform == null) {
        debugPrint("RedisClient: Platform changes detected - missing platform data for ID: $platformId");
        return true;
      }

      // Skip incomplete platform data
      if (!_isPlatformDataComplete(newPlatform)) {
        continue;
      }

      // Check basic status changes
      if (oldPlatform['platform_status'] != newPlatform['platform_status']) {
        debugPrint("RedisClient: Platform changes detected - status change for $platformId");
        return true;
      }

      if (oldPlatform['team_id'] != newPlatform['team_id']) {
        debugPrint("RedisClient: Platform changes detected - team_id change for $platformId");
        return true;
      }

      // Check GPS position changes (significant if moved more than ~1 meter)
      const double significantDistance = 0.00001; // roughly 1 meter in degrees
      final oldGpsPos = oldPlatform['platform_gps_position'] as Map<String, dynamic>?;
      final newGpsPos = newPlatform['platform_gps_position'] as Map<String, dynamic>?;
      
      if (oldGpsPos != null && newGpsPos != null) {
        final oldLat = double.tryParse(oldGpsPos['latitude']?.toString() ?? '0.0') ?? 0.0;
        final oldLng = double.tryParse(oldGpsPos['longitude']?.toString() ?? '0.0') ?? 0.0;
        final newLat = double.tryParse(newGpsPos['latitude']?.toString() ?? '0.0') ?? 0.0;
        final newLng = double.tryParse(newGpsPos['longitude']?.toString() ?? '0.0') ?? 0.0;
        
        if ((oldLat - newLat).abs() > significantDistance ||
            (oldLng - newLng).abs() > significantDistance) {
          return true; // Position changed significantly
        }
      }

      // Check for orientation changes (quaternion)
      final oldPose = oldPlatform['platform_pose'] as Map<String, dynamic>?;
      final newPose = newPlatform['platform_pose'] as Map<String, dynamic>?;
      
      if (oldPose != null && newPose != null) {
        final oldOrientation = oldPose['orientation'] as Map<String, dynamic>?;
        final newOrientation = newPose['orientation'] as Map<String, dynamic>?;
        
        if (oldOrientation != null && newOrientation != null) {
          const double orientationThreshold = 0.01; // Small threshold for quaternion changes
          for (String key in ['x', 'y', 'z', 'w']) {
            final oldVal = double.tryParse(oldOrientation[key]?.toString() ?? '0.0') ?? 0.0;
            final newVal = double.tryParse(newOrientation[key]?.toString() ?? '0.0') ?? 0.0;
            if ((oldVal - newVal).abs() > orientationThreshold) {
              return true; // Orientation changed significantly
            }
          }
        }
      }

      // Check for home position changes by resolving current home position
      String location = "home_$platformId";
      var currentHomeWp = await resolveStringWP(_command!, location);
      
      // Get previous home position from the existing Platform object if it exists
      if (_platforms.containsKey(platformId)) {
        final existingPlatform = _platforms[platformId]!;
        final oldHomePos = existingPlatform.homePosition;
        
        // Compare home positions
        if (oldHomePos != null) {
          final oldHomeLat = oldHomePos.latitude;
          final oldHomeLng = oldHomePos.longitude;
          final newHomeLat = currentHomeWp['latitude'] ?? 0.0;
          final newHomeLng = currentHomeWp['longitude'] ?? 0.0;
          
          if ((oldHomeLat - newHomeLat).abs() > significantDistance ||
              (oldHomeLng - newHomeLng).abs() > significantDistance) {
            debugPrint("RedisClient: Platform changes detected - home position change for $platformId");
            return true;
          }
        } else if (currentHomeWp['latitude'] != 0.0 || currentHomeWp['longitude'] != 0.0) {
          // Home position was added (previously null/0,0 but now has valid coordinates)
          debugPrint("RedisClient: Platform changes detected - home position added for $platformId");
          return true;
        }
      } else if (currentHomeWp['latitude'] != 0.0 || currentHomeWp['longitude'] != 0.0) {
        // New platform with home position
        debugPrint("RedisClient: Platform changes detected - new platform $platformId with home position");
        return true;
      }
    }

    // No significant changes detected
    return false;
  }

  Future<void> fetchDetectedObjects() async {
    try {
      var values = await _command!.send_object(['JSON.GET', 'object', "\$"]);
      List<Map<String, dynamic>> detectedObjectStates = [];

      if (values != null) {
        final outerList = jsonDecode(values) as List<dynamic>;
        detectedObjectStates = List<Map<String, dynamic>>.from(outerList.first);
      }

      // Check for significant changes before processing
      if (_hasSignificantDetectedObjectChanges(_lastDetectedObjectsState ?? [], detectedObjectStates)) {
        await _processDetectedObjects(detectedObjectStates);
        _lastDetectedObjectsState = List.from(detectedObjectStates);
      }
    } catch (e) {
      debugPrint("RedisClient: Error fetching detected objects data: $e");
      reconnect();
    }
  }

  // Check if detected objects data has significant changes
  bool _hasSignificantDetectedObjectChanges(
      List<Map<String, dynamic>> oldObjects,
      List<Map<String, dynamic>> newObjects) {
    if (oldObjects.length != newObjects.length) return true;

    // Create maps for efficient comparison
    final oldMap = {for (var obj in oldObjects) obj['id']: obj};
    final newMap = {for (var obj in newObjects) obj['id']: obj};

    // Check if object IDs are exactly the same
    final oldIds = oldMap.keys.toSet();
    final newIds = newMap.keys.toSet();
    if (!oldIds.containsAll(newIds) || !newIds.containsAll(oldIds)) {
      return true;
    }

    // Check for significant changes in object content
    for (var objectId in newMap.keys) {
      final oldObj = oldMap[objectId];
      final newObj = newMap[objectId];

      if (oldObj == null || newObj == null) continue;

      // Check basic properties for changes
      if (oldObj['detection_class'] != newObj['detection_class'] ||
          oldObj['priority'] != newObj['priority'] ||
          oldObj['state'] != newObj['state']) {
        return true;
      }

      // Check confidence change (significant if difference > 0.1)
      final oldConfidence = double.tryParse(oldObj['confidence']?.toString() ?? '0.0') ?? 0.0;
      final newConfidence = double.tryParse(newObj['confidence']?.toString() ?? '0.0') ?? 0.0;
      if ((oldConfidence - newConfidence).abs() > 0.1) {
        return true;
      }

      // Check position change (significant if moved more than ~1 meter)
      const double significantDistance = 0.00001; // roughly 1 meter in degrees
      final oldPos = oldObj['position'] ?? {};
      final newPos = newObj['position'] ?? {};
      final oldLat = double.tryParse(oldPos['x']?.toString() ?? '0.0') ?? 0.0;
      final oldLng = double.tryParse(oldPos['y']?.toString() ?? '0.0') ?? 0.0;
      final newLat = double.tryParse(newPos['x']?.toString() ?? '0.0') ?? 0.0;
      final newLng = double.tryParse(newPos['y']?.toString() ?? '0.0') ?? 0.0;
      
      if ((oldLat - newLat).abs() > significantDistance ||
          (oldLng - newLng).abs() > significantDistance) {
        return true;
      }
    }

    return false;
  }

  /// Process detected objects list and update detected object objects
  Future<bool> _processDetectedObjects(List<Map<String, dynamic>> objectList) async {
    final processedObjectIds = <String>{};

    for (final message in objectList) {
      final objectId = message['id']?.toString();
      if (objectId == null || objectId.isEmpty) continue;

      processedObjectIds.add(objectId);

      if (_detectedObjects.containsKey(objectId)) {
        // Update existing object
        final existingObject = _detectedObjects[objectId]!;
        final updatedObject = existingObject.updateWith(message);
        _detectedObjects[objectId] = updatedObject;
      } else {
        // Create new object with appropriate color
        final color = DetectedObject.getColorForClass(message['detection_class']?.toString() ?? 'unknown');
        _detectedObjects[objectId] = DetectedObject.fromMessage(message, color);
      }
    }

    // Remove objects that are no longer in the message
    final removedObjects = _detectedObjects.keys
        .where((id) => !processedObjectIds.contains(id))
        .toList();
    if (removedObjects.isNotEmpty) {
      for (final removedId in removedObjects) {
        _detectedObjects.remove(removedId);
      }
    }

    // Always emit to stream since this method is only called when there are significant changes
    debugPrint("RedisClient: Emitting updated detected objects to stream (${_detectedObjects.length} objects)");
    _detectedObjectsStreamController.add(_detectedObjects.values.toList());

    return true;
  }

  Future<void> fetchGeneralData() async {
    try {
      var missionValues =
          await _command!.send_object(['JSON.GET', 'mission', "\$"]);
      var planListValues =
          await _command!.send_object(['JSON.GET', 'plan', "\$"]);

      List<Map<String, dynamic>> returnSearchMission = [];
      List<Map<String, dynamic>> returnPlanList = [];

      if (missionValues != null) {
        final outerList = jsonDecode(missionValues) as List<dynamic>;
        if (outerList.isNotEmpty && outerList.first.isNotEmpty) {
          returnSearchMission =
              List<Map<String, dynamic>>.from(outerList.first);
        }
      }

      if (planListValues != null) {
        final outerList = jsonDecode(planListValues) as List<dynamic>;
        if (outerList.isNotEmpty && outerList.first.isNotEmpty) {
          returnPlanList = List<Map<String, dynamic>>.from(outerList.first);
        }
      }

      // Check for mission changes and process if needed
      bool missionChanged = _lastMissionListState == null ||
          _hasSignificantMissionChanges(
              _lastMissionListState ?? [], returnSearchMission);

      if (missionChanged) {
        // Update state tracking
        _lastMissionListState = List.from(returnSearchMission);

        // Process missions using new Mission class
        debugPrint("RedisClient: Processing missions due to detected changes");
        await _processMissions(returnSearchMission);
      }

      // Check for plan changes and process if needed
      bool planChanged = _lastPlanListState == null ||
          _hasSignificantPlanChanges(_lastPlanListState ?? [], returnPlanList);

      if (planChanged) {
        // Update state tracking
        _lastPlanListState = List.from(returnPlanList);

        // Process plans and generate waypoints only if changed
        debugPrint("RedisClient: Processing plans due to detected changes");
        await _processPlansWithWaypoints(returnPlanList);
      }
    } catch (e) {
      debugPrint("RedisClient: Error fetching mission data: $e");
      reconnect();
    }
  }

  // Check if plan data has significant changes
  bool _hasSignificantPlanChanges(List<Map<String, dynamic>> oldPlans,
      List<Map<String, dynamic>> newPlans) {
    // Quick length check
    if (oldPlans.length != newPlans.length) {
      debugPrint("RedisClient: Plan changes detected - different lengths: ${oldPlans.length} vs ${newPlans.length}");
      return true;
    }

    // Create maps for efficient comparison
    final oldMap = {for (var plan in oldPlans) plan['plan_id']: plan};
    final newMap = {for (var plan in newPlans) plan['plan_id']: plan};

    // Check if plan IDs are exactly the same
    final oldIds = oldMap.keys.toSet();
    final newIds = newMap.keys.toSet();
    if (!oldIds.containsAll(newIds) || !newIds.containsAll(oldIds)) {
      debugPrint("RedisClient: Plan changes detected - different plan IDs");
      return true;
    }

    // Check for significant changes in plan content
    for (var planId in newMap.keys) {
      final oldPlan = oldMap[planId];
      final newPlan = newMap[planId];

      if (oldPlan == null) {
        debugPrint("RedisClient: Plan changes detected - missing old plan for ID: $planId");
        return true;
      }

      // Check significant fields with null safety
      if (oldPlan['status'] != newPlan!['status']) {
        debugPrint("RedisClient: Plan changes detected - status change for plan $planId: ${oldPlan['status']} -> ${newPlan['status']}");
        return true;
      }
      if (oldPlan['priority'] != newPlan['priority']) {
        debugPrint("RedisClient: Plan changes detected - priority change for plan $planId: ${oldPlan['priority']} -> ${newPlan['priority']}");
        return true;
      }
      if (oldPlan['platform_id'] != newPlan['platform_id']) {
        debugPrint("RedisClient: Plan changes detected - platform_id change for plan $planId: ${oldPlan['platform_id']} -> ${newPlan['platform_id']}");
        return true;
      }
      if (oldPlan['team_id'] != newPlan['team_id']) {
        debugPrint("RedisClient: Plan changes detected - team_id change for plan $planId: ${oldPlan['team_id']} -> ${newPlan['team_id']}");
        return true;
      }

      // Check actions/tasks changes more carefully
      final oldActions = oldPlan['actions'] as List<dynamic>?;
      final newActions = newPlan['actions'] as List<dynamic>?;
      final oldTasks = oldPlan['tasks'] as List<dynamic>?;
      final newTasks = newPlan['tasks'] as List<dynamic>?;

      if ((oldActions?.length ?? 0) != (newActions?.length ?? 0) ||
          (oldTasks?.length ?? 0) != (newTasks?.length ?? 0)) {
        return true;
      }

      // Deep comparison of actions for significant changes
      if (oldActions != null && newActions != null) {
        for (int i = 0; i < oldActions.length; i++) {
          final oldAction = oldActions[i] as Map<String, dynamic>;
          final newAction = newActions[i] as Map<String, dynamic>;

          if (oldAction['action_name'] != newAction['action_name'] ||
              oldAction['status'] != newAction['status'] ||
              oldAction['task_id'] != newAction['task_id']) {
            return true;
          }

          // Check parameters for deeper changes (waypoint coordinates, etc.)
          final oldParams = oldAction['parameters'] as List<dynamic>?;
          final newParams = newAction['parameters'] as List<dynamic>?;

          if ((oldParams?.length ?? 0) != (newParams?.length ?? 0)) {
            return true;
          }

          // Compare parameter content
          if (oldParams != null && newParams != null) {
            for (int j = 0; j < oldParams.length; j++) {
              if (oldParams[j].toString() != newParams[j].toString()) {
                debugPrint("RedisClient: Plan changes detected - parameter change for plan $planId action $i param $j");
                return true;
              }
            }
          }
        }
      }
    }

    // No significant changes detected
    return false;
  }

  // Check if mission data has significant changes
  bool _hasSignificantMissionChanges(List<Map<String, dynamic>> oldMissions,
      List<Map<String, dynamic>> newMissions) {
    // Quick length check
    if (oldMissions.length != newMissions.length) {
      debugPrint("RedisClient: Mission changes detected - different lengths: ${oldMissions.length} vs ${newMissions.length}");
      return true;
    }

    // Create maps for efficient comparison
    final oldMap = {
      for (var mission in oldMissions) mission['team_id']: mission
    };
    final newMap = {
      for (var mission in newMissions) mission['team_id']: mission
    };

    // Check if team IDs are exactly the same
    final oldIds = oldMap.keys.toSet();
    final newIds = newMap.keys.toSet();
    if (!oldIds.containsAll(newIds) || !newIds.containsAll(oldIds)) {
      debugPrint("RedisClient: Mission changes detected - different team IDs");
      return true;
    }

    // Check for significant changes in mission content
    for (var teamId in newMap.keys) {
      final oldMission = oldMap[teamId];
      final newMission = newMap[teamId];

      if (oldMission == null) {
        debugPrint("RedisClient: Mission changes detected - missing old mission for team ID: $teamId");
        return true;
      }

      // Check significant fields with null safety
      if (oldMission['mission_goal'] != newMission!['mission_goal']) {
        debugPrint("RedisClient: Mission changes detected - mission_goal change for team $teamId");
        return true;
      }
      if (oldMission['max_height'] != newMission['max_height'] ||
          oldMission['min_height'] != newMission['min_height']) {
        debugPrint("RedisClient: Mission changes detected - height change for team $teamId");
        return true;
      }
      if (oldMission['desired_ground_dist'] != newMission['desired_ground_dist']) {
        debugPrint("RedisClient: Mission changes detected - desired_ground_dist change for team $teamId");
        return true;
      }

      // Check platform class changes
      final oldPlatformClass =
          oldMission['platform_class'] as Map<String, dynamic>?;
      final newPlatformClass =
          newMission['platform_class'] as Map<String, dynamic>?;
      if ((oldPlatformClass?['value'] ?? 0) !=
          (newPlatformClass?['value'] ?? 0)) {
        debugPrint(
            "RedisClient: Mission changes detected - platform_class change for team $teamId");
        return true;
      }

      // Check sensor mode changes
      final oldSensorMode = oldMission['sensor_mode'] as Map<String, dynamic>?;
      final newSensorMode = newMission['sensor_mode'] as Map<String, dynamic>?;
      if ((oldSensorMode?['value'] ?? 0) != (newSensorMode?['value'] ?? 0)) {
        debugPrint(
            "RedisClient: Mission changes detected - sensor_mode change for team $teamId");
        return true;
      }

      // Check search areas changes
      final oldSearchAreas = oldMission['search_areas'] as List<dynamic>?;
      final newSearchAreas = newMission['search_areas'] as List<dynamic>?;

      // Check for changes in search areas
      if ((oldSearchAreas?.length ?? 0) != (newSearchAreas?.length ?? 0)) {
        debugPrint(
            "RedisClient: Mission changes detected - search areas length change for team $teamId");
        return true;
      }

      // Check arrays for length changes (detailed comparison would be too expensive)
      final oldNoFlyZones = oldMission['no_fly_zones'] as List<dynamic>?;
      final newNoFlyZones = newMission['no_fly_zones'] as List<dynamic>?;
      if ((oldNoFlyZones?.length ?? 0) != (newNoFlyZones?.length ?? 0)) {
        debugPrint(
            "RedisClient: Mission changes detected - no_fly_zones length change for team $teamId");
        return true;
      }

      final oldPois = oldMission['pois'] as List<dynamic>?;
      final newPois = newMission['pois'] as List<dynamic>?;
      if ((oldPois?.length ?? 0) != (newPois?.length ?? 0)) {
        debugPrint(
            "RedisClient: Mission changes detected - pois length change for team $teamId");
        return true;
      }

      final oldPriorityAreas = oldMission['prio_areas'] as List<dynamic>?;
      final newPriorityAreas = newMission['prio_areas'] as List<dynamic>?;
      if ((oldPriorityAreas?.length ?? 0) != (newPriorityAreas?.length ?? 0)) {
        debugPrint(
            "RedisClient: Mission changes detected - priority_areas length change for team $teamId");
        return true;
      }

      final oldDangerZones = oldMission['danger_zones'] as List<dynamic>?;
      final newDangerZones = newMission['danger_zones'] as List<dynamic>?;
      if ((oldDangerZones?.length ?? 0) != (newDangerZones?.length ?? 0)) {
        debugPrint(
            "RedisClient: Mission changes detected - danger_zones length change for team $teamId");
        return true;
      }
    }

    // No significant changes detected
    return false;
  }

  void setTrajectoryMode(bool value) {
    isTrajectoryOn = value;
    debugPrint("RedisClient: isTrajectoryOn set to $isTrajectoryOn");
  }

  /// Process mission list and update mission objects
  Future<bool> _processMissions(List<Map<String, dynamic>> missionList) async {
    final processedTeamIds = <String>{};

    for (final message in missionList) {
      final teamId = message['team_id']?.toString();
      if (teamId == null || teamId.isEmpty) {
        debugPrint(
            "RedisClient: Skipping mission with missing team_id: ${message['team_id']}");
        continue;
      }

      processedTeamIds.add(teamId);

      if (_missions.containsKey(teamId)) {
        // Update existing mission
        _missions[teamId]!.updateFromMessage(message);
      } else {
        // Create new mission with assigned color
        final color = _getColorForMission(teamId);
        final newMission = Mission.fromMessage(message, color);
        _missions[teamId] = newMission;
      }
    }

    // Remove missions that are no longer in the message
    final removedMissions = _missions.keys
        .where((teamId) => !processedTeamIds.contains(teamId))
        .toList();
    if (removedMissions.isNotEmpty) {
      debugPrint("RedisClient: Removing missions: $removedMissions");
      _missions.removeWhere((teamId, _) => !processedTeamIds.contains(teamId));
    }

    // Always emit to stream since this method is only called when there are significant changes
    debugPrint(
        "RedisClient: Emitting updated missions to stream (${_missions.length} missions)");
    _missionsStreamController.add(_missions.values.toList());

    return true;
  }

  /// Get a color for a mission based on its team ID
  Color _getColorForMission(String teamId) {
    final hash = teamId.hashCode.abs();
    return _missionColors[hash % _missionColors.length];
  }

  /// Process plan list and generate waypoints for each plan
  Future<void> _processPlansWithWaypoints(
      List<Map<String, dynamic>> planList) async {
    final updatedPlans = <int, Plan>{};
    final processedPlanIds = <int>{};

    for (final message in planList) {
      final planIdString = message['plan_id']?.toString();
      if (planIdString == null || planIdString.isEmpty) {
        debugPrint(
            "RedisClient: Skipping plan with missing plan_id: ${message['plan_id']}");
        continue;
      }

      final planId = int.tryParse(planIdString);
      if (planId == null) {
        debugPrint(
            "RedisClient: Skipping plan with invalid plan_id format: ${message['plan_id']}");
        continue;
      }

      processedPlanIds.add(planId);

      if (_plans.containsKey(planId)) {
        // Update existing plan
        _plans[planId]!.updateFromMessage(message);
        // Generate waypoints with Redis lookup
        await _plans[planId]!.generateWaypointsWithRedis(_command);
        updatedPlans[planId] = _plans[planId]!;
      } else {
        // Create new plan with assigned color
        final color = _getColorForPlan(planId);
        final newPlan = Plan.fromMessage(message, color);
        // Generate waypoints with Redis lookup
        await newPlan.generateWaypointsWithRedis(_command);
        updatedPlans[planId] = newPlan;
        _plans[planId] = newPlan;
      }
    }

    // Remove plans that are no longer in the message
    final removedPlans = _plans.keys
        .where((planId) => !processedPlanIds.contains(planId))
        .toList();
    if (removedPlans.isNotEmpty) {
      debugPrint("RedisClient: Removing plans: $removedPlans");
      _plans.removeWhere((planId, _) => !processedPlanIds.contains(planId));
    }

    // Send updated plans to stream
    debugPrint(
        "RedisClient: Emitting updated plans to stream (${_plans.length} plans)");
    _planStreamController.add(_plans.values.toList());
  }

  /// Get a color for a plan based on its ID
  Color _getColorForPlan(int planId) {
    return _colors[planId % _colors.length];
  }

  /// Deletes a plan from the Redis 'plan' collection by plan_id
  Future<bool> deletePlan(String planId) async {
    if (!_isConnected || _command == null) {
      debugPrint("RedisClient: Cannot delete plan - not connected to Redis");
      return false;
    }

    try {
      // Use JSON.DEL with JSONPath to delete the specific plan by plan_id
      var result = await _command!
          .send_object(['JSON.DEL', 'plan', '\$[?(@.plan_id == "$planId")]']);

      if (result != null && result > 0) {
        debugPrint("RedisClient: Successfully deleted plan with ID: $planId");
        // Force refresh of plan data
        await fetchGeneralData();
        return true;
      } else {
        debugPrint("RedisClient: Plan with ID $planId not found or already deleted");
        return false;
      }
    } catch (e) {
      debugPrint("RedisClient: Error deleting plan $planId: $e");
      return false;
    }
  }

  /// Updates the priority of a specific plan
  Future<bool> updatePlanPriority(String planId, int newPriority) async {
    if (!_isConnected || _command == null) {
      debugPrint(
          "RedisClient: Cannot update plan priority - not connected to Redis");
      return false;
    }

    try {
      // Use JSON.SET with JSONPath to update the priority of the specific plan
      var result = await _command!.send_object([
        'JSON.SET',
        'plan',
        '\$[?(@.plan_id == "$planId")].priority',
        '"${newPriority.toString()}"'
      ]);

      if (result != null) {
        debugPrint(
            "RedisClient: Successfully updated priority for plan $planId to $newPriority");
        // Force refresh of plan data with a small delay
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchGeneralData();
        return true;
      } else {
        debugPrint("RedisClient: Failed to update priority for plan $planId");
        return false;
      }
    } catch (e) {
      debugPrint("RedisClient: Error updating plan priority for $planId: $e");
      return false;
    }
  }

  /// Updates the actions/tasks of a specific plan
  Future<bool> updatePlanActions(
      String planId, List<Map<String, dynamic>> newActions) async {
    if (!_isConnected || _command == null) {
      debugPrint("RedisClient: Cannot update plan actions - not connected to Redis");
      return false;
    }

    try {
      // Convert actions to JSON string for Redis
      String actionsJson = jsonEncode(newActions);

      // Use JSON.SET with JSONPath to update the actions of the specific plan
      var result = await _command!.send_object([
        'JSON.SET',
        'plan',
        '\$[?(@.plan_id == "$planId")].actions',
        actionsJson
      ]);

      if (result != null) {
        debugPrint("RedisClient: Successfully updated actions for plan $planId");
        // Force refresh of plan data with a small delay
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchGeneralData();
        return true;
      } else {
        debugPrint("RedisClient: Failed to update actions for plan $planId");
        return false;
      }
    } catch (e) {
      debugPrint("RedisClient: Error updating plan actions for $planId: $e");
      return false;
    }
  }

  /// Updates multiple fields of a specific plan
  Future<bool> updatePlan(String planId, Map<String, dynamic> updates) async {
    if (!_isConnected || _command == null) {
      debugPrint("RedisClient: Cannot update plan - not connected to Redis");
      return false;
    }

    try {
      bool success = true;

      // Update each field individually
      for (String field in updates.keys) {
        var value = updates[field];
        String valueJson;

        if (value is String) {
          valueJson = '"$value"';
        } else if (value is List || value is Map) {
          valueJson = jsonEncode(value);
        } else {
          valueJson = value.toString();
        }

        var result = await _command!.send_object([
          'JSON.SET',
          'plan',
          '\$[?(@.plan_id == "$planId")].$field',
          valueJson
        ]);

        if (result == null) {
          debugPrint("RedisClient: Failed to update field $field for plan $planId");
          success = false;
        } else {
          debugPrint(
              "RedisClient: Successfully updated field $field for plan $planId");
        }
      }

      if (success) {
        // Add a small delay to ensure Redis has processed all updates
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchGeneralData();
      }

      return success;
    } catch (e) {
      debugPrint("RedisClient: Error updating plan $planId: $e");
      return false;
    }
  }

  /// Gets a specific plan by plan_id
  Future<Map<String, dynamic>?> getPlan(String planId) async {
    if (!_isConnected || _command == null) {
      debugPrint("RedisClient: Cannot get plan - not connected to Redis");
      return null;
    }

    try {
      var result = await _command!
          .send_object(['JSON.GET', 'plan', '\$[?(@.plan_id == "$planId")]']);

      if (result != null) {
        final plans = jsonDecode(result) as List<dynamic>;
        if (plans.isNotEmpty) {
          return plans.first as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      debugPrint("RedisClient: Error getting plan $planId: $e");
      return null;
    }
  }

  /// Deletes a mission from the Redis 'mission' collection by team_id
  Future<bool> deleteMission(String teamId) async {
    if (!_isConnected || _command == null) {
      debugPrint("RedisClient: Cannot delete mission - not connected to Redis");
      return false;
    }

    try {
      // Delete manual search areas created by this mission
      // First, get all areas to find the ones that match our pattern
      var allAreasResult =
          await _command!.send_object(['JSON.GET', 'area', '\$']);
      int deletedAreasCount = 0;

      if (allAreasResult != null) {
        final outerList = jsonDecode(allAreasResult) as List<dynamic>;
        if (outerList.isNotEmpty && outerList.first is List) {
          final areasList = outerList.first as List<dynamic>;

          // Find indices of areas to delete (in reverse order to avoid index issues)
          List<int> indicesToDelete = [];
          for (int i = 0; i < areasList.length; i++) {
            final area = areasList[i] as Map<String, dynamic>;
            final areaName = area['name'] as String?;
            if (areaName != null &&
                areaName.startsWith('manual_search_area_${teamId}_')) {
              indicesToDelete.add(i);
            }
          }

          // Delete areas by index in reverse order
          for (int i = indicesToDelete.length - 1; i >= 0; i--) {
            final index = indicesToDelete[i];
            try {
              var deleteResult = await _command!
                  .send_object(['JSON.DEL', 'area', '\$[$index]']);
              if (deleteResult != null && deleteResult > 0) {
                deletedAreasCount++;
                debugPrint("RedisClient: Deleted area at index $index");
              }
            } catch (e) {
              debugPrint("RedisClient: Error deleting area at index $index: $e");
            }
          }
        }
      }

      final areaResult = deletedAreasCount;

      // Delete mission from Redis
      var missionResult = await _command!.send_object(['JSON.DEL', 'mission', '\$[?(@.team_id == "$teamId")]']);

      // Delete associated goals from Redis
      var goalsResult = await _command!.send_object(['JSON.DEL', 'goal', '\$[?(@.team_id == "$teamId")]']);

      if (missionResult != null) {
        debugPrint("RedisClient: Successfully deleted mission for team $teamId");

        if (goalsResult != null && goalsResult > 0) {
          debugPrint(
              "RedisClient: Successfully deleted $goalsResult goal(s) for team $teamId");
        } else {
          debugPrint(
              "RedisClient: No goals found for team $teamId or goals already deleted");
        }

        if (areaResult > 0) {
          debugPrint(
              "RedisClient: Successfully deleted $areaResult area(s) for team $teamId");
        } else {
          debugPrint(
              "RedisClient: No areas found for team $teamId or areas already deleted");
        }

        // Remove from local storage
        _missions.remove(teamId);

        // Refresh mission data and emit updated list
        await fetchGeneralData();
        return true;
      } else {
        debugPrint("RedisClient: Failed to delete mission for team $teamId");
        return false;
      }
    } catch (e) {
      debugPrint("RedisClient: Error deleting mission for team $teamId: $e");
      return false;
    }
  }

  /// Gets a specific mission by team_id
  Future<Map<String, dynamic>?> getMission(String teamId) async {
    if (!_isConnected || _command == null) {
      debugPrint("RedisClient: Cannot get mission - not connected to Redis");
      return null;
    }

    try {
      var result = await _command!.send_object(
          ['JSON.GET', 'mission', '\$[?(@.team_id == "$teamId")]']);

      if (result != null) {
        final missions = jsonDecode(result) as List<dynamic>;
        if (missions.isNotEmpty) {
          return missions.first as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      debugPrint("RedisClient: Error getting mission for team $teamId: $e");
      return null;
    }
  }

  /// Updates multiple fields of a specific mission
  Future<bool> updateMission(
      String teamId, Map<String, dynamic> updates) async {
    if (!_isConnected || _command == null) {
      debugPrint("RedisClient: Cannot update mission - not connected to Redis");
      return false;
    }

    try {
      bool success = true;

      // Update each field individually
      for (String field in updates.keys) {
        var value = updates[field];
        String valueJson;

        if (value is String) {
          valueJson = '"$value"';
        } else if (value is List || value is Map) {
          valueJson = jsonEncode(value);
        } else {
          valueJson = value.toString();
        }

        var result = await _command!.send_object([
          'JSON.SET',
          'mission',
          '\$[?(@.team_id == "$teamId")].$field',
          valueJson
        ]);

        if (result == null) {
          debugPrint(
              "RedisClient: Failed to update field $field for mission $teamId");
          success = false;
        } else {
          debugPrint(
              "RedisClient: Successfully updated field $field for mission $teamId");
        }
      }

      if (success) {
        // Add a small delay to ensure Redis has processed all updates
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchGeneralData();
      }

      return success;
    } catch (e) {
      debugPrint("RedisClient: Error updating mission $teamId: $e");
      return false;
    }
  }

  /// Updates the confidence of a specific detected object to 100%
  Future<bool> confirmDetectedObject(String objectId) async {
    if (!_isConnected || _command == null) {
      debugPrint("RedisClient: Cannot confirm detected object - not connected to Redis");
      return false;
    }

    try {
      // Use JSON.SET with JSONPath to update the confidence of the specific object
      var result = await _command!.send_object([
        'JSON.SET',
        'object',
        '\$[?(@.id == "$objectId")].confidence',
        '"1.0"'
      ]);

      if (result != null) {
        debugPrint("RedisClient: Successfully confirmed detected object with ID: $objectId");
        // Force refresh of detected objects data
        await fetchDetectedObjects();
        return true;
      } else {
        debugPrint("RedisClient: Detected object with ID $objectId not found");
        return false;
      }
    } catch (e) {
      debugPrint("RedisClient: Error confirming detected object $objectId: $e");
      return false;
    }
  }

  /// Deletes a detected object from the Redis 'object' collection by id
  Future<bool> deleteDetectedObject(String objectId) async {
    if (!_isConnected || _command == null) {
      debugPrint("RedisClient: Cannot delete detected object - not connected to Redis");
      return false;
    }

    try {
      // Use JSON.DEL with JSONPath to delete the specific object by id
      var result = await _command!
          .send_object(['JSON.DEL', 'object', '\$[?(@.id == "$objectId")]']);

      if (result != null && result > 0) {
        debugPrint("RedisClient: Successfully deleted detected object with ID: $objectId");
        // Force refresh of detected objects data  
        await fetchDetectedObjects();
        return true;
      } else {
        debugPrint("RedisClient: Detected object with ID $objectId not found or already deleted");
        return false;
      }
    } catch (e) {
      debugPrint("RedisClient: Error deleting detected object $objectId: $e");
      return false;
    }
  }

  /// Gets a specific detected object by id
  Future<Map<String, dynamic>?> getDetectedObject(String objectId) async {
    if (!_isConnected || _command == null) {
      debugPrint("RedisClient: Cannot get detected object - not connected to Redis");
      return null;
    }

    try {
      var result = await _command!
          .send_object(['JSON.GET', 'object', '\$[?(@.id == "$objectId")]']);

      if (result != null) {
        final objects = jsonDecode(result) as List<dynamic>;
        if (objects.isNotEmpty) {
          return objects.first as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint("RedisClient: Error getting detected object $objectId: $e");
      return null;
    }
  }

  Future<void> disconnect() async {
    if (!_isConnected) return;

    _isConnected = false;
    _timer50ms?.cancel();
    _timer1000ms?.cancel();
    _timer5000ms?.cancel();

    await _connection?.close();
    _command = null;
    _connection = null;

    debugPrint("RedisClient: Disconnected from Redis.");
  }

  Future<void> reconnect() async {
    debugPrint("RedisClient: Connection lost, attempting to reconnect...");
    await disconnect();

    // Notify UI that connection is lost
    debugPrint("RedisClient: Calling onConnectionLost callback");
    onConnectionLost?.call();

    // Don't attempt automatic reconnection here - let the UI handle it
    // This prevents infinite reconnection loops and gives user control
  }

  Future<void> _closeStreams() async {
    _platformStreamController.close();
    _trajectoryStreamController.close();
    _planStreamController.close();
    _missionsStreamController.close();
    _detectedObjectsStreamController.close();
    _teamIdsStreamController.close();
    debugPrint("RedisClient: Streams have been closed.");
  }

  Future<void> dispose() async {
    await _closeStreams();
    await disconnect();
  }
}
