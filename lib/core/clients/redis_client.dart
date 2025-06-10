import 'dart:async';
import 'dart:convert';
import 'package:augur/ui/utils/waypoint_utils.dart';
import 'package:redis/redis.dart';

class RedisClient {
  final String redisIp;
  RedisConnection? _connection;
  Command? _command;
  bool _isConnected = false;
  bool isTrajectoryOn = false;
  Function()? onConnectionLost;

  final StreamController<List<Map<String, dynamic>>> _platformStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _trajectoryStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<Map<String, dynamic>> _missionStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _waypointStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<String>> _platformNamesStreamController = StreamController<List<String>>.broadcast();

  Stream<List<Map<String, dynamic>>> get platformStream => _platformStreamController.stream;
  Stream<List<Map<String, dynamic>>> get trajectoryStream => _trajectoryStreamController.stream;
  Stream<Map<String, dynamic>> get missionStream => _missionStreamController.stream;
  Stream<List<Map<String, dynamic>>> get waypointStream => _waypointStreamController.stream;
  Stream<List<String>> get platformNamesStream => _platformNamesStreamController.stream;

  Timer? _timer50ms;
  Timer? _timer1000ms;
  Timer? _timer5000ms;

  List<Map<String, dynamic>>? _lastPlatformState;
  List<Map<String, dynamic>>? _lastTrajectoryState;
  Map<String, dynamic>? _lastMissionState;
  List<Map<String, dynamic>>? _lastWaypointState;
  List<String>? _lastPlatformIDs;

  RedisClient({required this.redisIp, required this.onConnectionLost});

  Future<void> connect() async {
    if (_isConnected) {
      print("RedisClient: Already connected.");
      return;
    }

    _connection = RedisConnection();

    try {
      _command = await _connection?.connect(redisIp, 6379);
      await _command!.send_object(["AUTH", "default", "auspex_db"]);
      print("RedisClient: Connected to Redis at $redisIp:6379");

      _isConnected = true;

      _timer50ms = Timer.periodic(Duration(milliseconds: 50), (_) => fetchPlatformData());
      _timer1000ms = Timer.periodic(Duration(milliseconds: 1000), (_) => fetchPlatformTrajectories());
      _timer5000ms = Timer.periodic(Duration(milliseconds: 5000), (_) => fetchGeneralData());

    } catch (e) {
      print("RedisClient: Connection Error: $e");
      reconnect();
    }
  }

  Future<void> fetchPlatformData() async {
    try {
      var values = await _command!.send_object(['JSON.GET', 'platform', "\$"]);
      if (values != null) {
        final outerList = jsonDecode(values) as List<dynamic>;
        List<Map<String, dynamic>> platformStates = List<Map<String, dynamic>>.from(outerList.first);
        List<String> platformIds = platformStates.map((e) => e['platform_id'] as String).toList();

        if (_lastPlatformIDs == null || jsonEncode(_lastPlatformIDs) != jsonEncode(_lastPlatformIDs)){
          _platformNamesStreamController.add(platformIds);
        }else{
          _platformNamesStreamController.add([]);
        }

        if (_lastPlatformState == null || jsonEncode(_lastPlatformState) != jsonEncode(platformStates)) {
          _lastPlatformState = platformStates;
          _platformStreamController.add(platformStates);
        }else{
          _platformStreamController.add([]);
        }
      }

    } catch (e) {
      print("RedisClient: Error fetching platform data: $e");
      reconnect();
    }
  }

  Future<void> fetchPlatformTrajectories() async {
    try {
      if (isTrajectoryOn) {
        var values = await _command!.send_object(['JSON.GET', 'history', "\$"]);
        if (values != null) {
          final outerList = jsonDecode(values) as List<dynamic>;
          List<Map<String, dynamic>> platformTrajectories = List<Map<String, dynamic>>.from(outerList.first);

          if (_lastTrajectoryState == null || jsonEncode(_lastTrajectoryState) != jsonEncode(platformTrajectories)) {
              _lastTrajectoryState = platformTrajectories;
              _trajectoryStreamController.add(platformTrajectories);
          }
        }
      }else{
        _trajectoryStreamController.add([]);
      }
    } catch (e) {
      print("RedisClient: Error fetching trajectory data: $e");
    }
  }

  Future<void> fetchGeneralData() async {
    try {
      var missionValues = await _command!.send_object(['JSON.GET', 'mission', "\$"]);
      var waypointsValues = await _command!.send_object(['JSON.GET', 'plan', "\$"]);

      List<Map<String, dynamic>> returnSearchMission = [];
      List<Map<String, dynamic>> returnWaypoint = [];

      if (missionValues != null) {
        final outerList = jsonDecode(missionValues) as List<dynamic>;
        if (outerList.isNotEmpty && outerList.first.isNotEmpty) returnSearchMission = List<Map<String, dynamic>>.from(outerList.first);
      }

      if (waypointsValues != null) {
        final outerList = jsonDecode(waypointsValues) as List<dynamic>;
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

          _missionStreamController.add(newMissionState);
          _waypointStreamController.add(returnWaypoint);
      }else{
        _missionStreamController.add({});
        _waypointStreamController.add([]);
      }
    } catch (e) {
      print("RedisClient: Error fetching mission data: $e");

    }
  }

  void setTrajectoryMode(bool value) {
    isTrajectoryOn = value;
    print("RedisClient: isTrajectoryOn set to $isTrajectoryOn");
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

    print("RedisClient: Disconnected from Redis.");
  }

  Future<void> reconnect() async {
    await disconnect();
    onConnectionLost?.call();
  }

  Future<void> _closeStreams() async{
    _platformStreamController.close();
    _trajectoryStreamController.close();
    _missionStreamController.close();
    _waypointStreamController.close();
    print("RedisClient: Streams have been closed.");
  }

  Future<void> dispose() async{
    await _closeStreams();
    await disconnect();
  }
}
