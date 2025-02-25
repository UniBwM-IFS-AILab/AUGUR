import 'dart:async';
import 'dart:convert';
import 'package:redis/redis.dart';
import 'package:augur/utils/waypoint_utils.dart';

class DataBaseClient {
  final String redisIp;
  RedisConnection? _connection;
  Command? _command;
  bool isTrajectoryOn = false;

  Function(List<Map<String, dynamic>>, List<String>)? onPlatformUpdate;
  Function(List<Map<String, dynamic>>)? onPlatformTrajectoriesUpdate;
  Function(Map<String, dynamic>, List<Map<String, dynamic>>)? onPlatformGeneralUpdate;
  Function()? onRetryConnection;

  DataBaseClient({required this.redisIp});
  
  Timer? _timer_50ms; 
  Timer? _timer_1000ms;
  Timer? _timer_5000ms; 

  // Store last known states for comparison
  List<Map<String, dynamic>>? _lastPlatformState;
  List<Map<String, dynamic>>? _lastTrajectoryState;
  Map<String, dynamic>? _lastMissionState;
  List<Map<String, dynamic>>? _lastWaypointState;

  Future<void> connect() async {
    _connection = RedisConnection();

    try {
      _command = await _connection?.connect(redisIp, 6379);
      print("Connected to DataBase at $redisIp:6379");

      _timer_50ms = Timer.periodic(Duration(milliseconds: 50), (timer) async {
        await fetchPlatformData();
      });

      _timer_1000ms = Timer.periodic(Duration(milliseconds: 1000), (timer) async {
        await fetchPlatformTrajectories();
      });

      _timer_5000ms = Timer.periodic(Duration(milliseconds: 5000), (timer) async {
        await fetchGeneralData();
      });

    } catch (e) {
      retryConnection();
      print("DataBase Connection Error: $e");
    }
  }

  Future<void> fetchPlatformData() async {
    try {
      var values = await _command!.send_object(['JSON.GET', 'platform', "\$"]);
      if (values != null) {
        final outerList = jsonDecode(values) as List<dynamic>;
        List<Map<String, dynamic>> platformStates = List<Map<String, dynamic>>.from(outerList.first);
        List<String> platformIds = platformStates.map((e) => e['platform_id'] as String).toList();

        // **Optimization: Only update if state has changed**
        if (_lastPlatformState == null || jsonEncode(_lastPlatformState) != jsonEncode(platformStates)) {
          _lastPlatformState = platformStates;
          onPlatformUpdate?.call(platformStates, platformIds);
        }
      }
    } catch (e) {
      retryConnection();
      print("Error fetching platform data: $e. Disconnecting.");
    }
  }

  Future<void> fetchPlatformTrajectories() async {
    try {
      if (isTrajectoryOn) {
        var values = await _command!.send_object(['JSON.GET', 'history', "\$"]);
        if (values != null) {
          final outerList = jsonDecode(values) as List<dynamic>;
          List<Map<String, dynamic>> platformTrajectories = List<Map<String, dynamic>>.from(outerList.first);

          // **Optimization: Only update if new trajectory data is different**
          if (_lastTrajectoryState == null || jsonEncode(_lastTrajectoryState) != jsonEncode(platformTrajectories)) {
            _lastTrajectoryState = platformTrajectories;
            onPlatformTrajectoriesUpdate?.call(platformTrajectories);
          }
        }
      }
    } catch (e) {
      print("Error fetching trajectory data: $e.");
    }
  }

  Future<void> fetchGeneralData() async {
    try {
      var valuesSearchMission = await _command!.send_object(['JSON.GET', 'mission', "\$"]);
      var valuesWaypoints = await _command!.send_object(['JSON.GET', 'plan', "\$"]);

      List<Map<String, dynamic>> returnSearchMission = [];
      List<Map<String, dynamic>> returnWaypoint = [];

      if (valuesSearchMission != null) {
        final outerList = jsonDecode(valuesSearchMission) as List<dynamic>;
        if (outerList.isNotEmpty && outerList.first.isNotEmpty) {
          returnSearchMission = List<Map<String, dynamic>>.from(outerList.first);
        }
      }

      if (valuesWaypoints != null) {
        final outerList = jsonDecode(valuesWaypoints) as List<dynamic>;
        if (outerList.isNotEmpty && outerList.first.isNotEmpty) {
          returnWaypoint = List<Map<String, dynamic>>.from(outerList.first);
          returnWaypoint = await addWaypointsToActions(_command, returnWaypoint);
        }
      }

      Map<String, dynamic> newMissionState = returnSearchMission.isNotEmpty ? returnSearchMission.first : {};

      if ((_lastMissionState == null || jsonEncode(_lastMissionState) != jsonEncode(newMissionState)) ||
          (_lastWaypointState == null || jsonEncode(_lastWaypointState) != jsonEncode(returnWaypoint))) {
        _lastMissionState = newMissionState;
        _lastWaypointState = returnWaypoint;

        onPlatformGeneralUpdate?.call(_lastMissionState!, _lastWaypointState!);
      }
    } catch (e) {
      print("Error in fetchGeneralData: $e");
    }
  }


  Future<void> disconnect() async {
    try {
      _timer_50ms?.cancel();
      _timer_1000ms?.cancel();
      _timer_5000ms?.cancel();

      if (_command != null) {
        var currentConnection = _command?.get_connection();
        if (currentConnection != null) {
          await currentConnection.close();
        }
        _command = null;
      }

      print("Disconnected from DataBase");
    } catch (e) {
      print("Error while disconnecting: $e");
    }
  }

  Future<void> retryConnection() async {
    disconnect();
    onRetryConnection?.call();
  }
}
