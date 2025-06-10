import 'dart:async';
import 'dart:math';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:augur/msg/area_type.dart';
import '../../../../state/redis_provider.dart';

class MapWidget extends ConsumerStatefulWidget {
  final bool isSatelliteSwitchOn;
  final Function(TapPosition, LatLng) showCircularMenuCallback;
  final Function() removeCircularMenuCallback;

  const MapWidget({ super.key,
                    required this.isSatelliteSwitchOn,
                    required this.showCircularMenuCallback,
                    required this.removeCircularMenuCallback
                    });

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget> {

  final List<Color> _colors = [
    AppColors.primary,
    AppColors.secondary,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
  ];
  final Map<String, Color> _platformColorMap = {};

  final MapController _mapController = MapController();
  final List<Marker> _persistentMarkers = [];
  final List<Marker> _platformMarkers = [];
  final List<Marker> _waypointMarkers = [];

  final List<Polyline> _routeLines = [];
  final List<Polyline> _trajectories = [];
  final List<Polygon> _areas = [];

  bool _isHomeSet = false;
  final String _satelliteUrlTemplate = ''; //'https://api.mapbox.com/styles/v1/USERNAME/clxiwfe7v009x01qr76hhekeo/tiles/256/{z}/{x}/{y}@2x?access_token=ACCESS_TOKEN';
  String _currentUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  final String _openstreetsUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  bool _isPlatformBoxVisible = false;
  String _focusedPlatformId = '';
  String _focusedPlatformStatus = '';

  bool _isWaypointBoxVisible = false;
  LatLng _waypointBoxLatLng = const LatLng(0.0, 0.0);
  String _routeId= '';
  int _waypointIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final platformData = ref.watch(platformDataProvider);
    final trajectoryData = ref.watch(trajectoryDataProvider);
    final missionData = ref.watch(missionDataProvider);
    final waypointData = ref.watch(waypointDataProvider);

    platformData.when(
      data: (data) => _onNewPlatformState(data),
      loading: () => {},
      error: (err, _) => print("Error loading platform data: $err"),
    );

    trajectoryData.when(
      data: (data) => _onNewPlatformTrajectories(data),
      loading: () => {},
      error: (err, _) => print("Error loading trajectory data: $err"),
    );

    missionData.when(
      data: (data) => _onNewSearchMission(data),
      loading: () => {},
      error: (err, _) => print("Error loading mission data: $err"),
    );

    waypointData.when(
      data: (data) => _onNewWaypoints(data),
      loading: () => {},
      error: (err, _) => print("Error loading mission data: $err"),
    );

    if(widget.isSatelliteSwitchOn) {
      if(_satelliteUrlTemplate == ''){
        _currentUrlTemplate = _openstreetsUrlTemplate;
        print("Satellite URL Empty, please insert API Key.");
      }else{
        _currentUrlTemplate = _satelliteUrlTemplate;
      }
    }
    else{
      _currentUrlTemplate = _openstreetsUrlTemplate;
    }

    Offset platformBox = Offset(0, 0);
    LatLng focusedPlatformPosition = getPlatformMarkerById(_focusedPlatformId, _platformMarkers)?.point ?? LatLng(0.0, 0.0);
    if(_isPlatformBoxVisible){
      if (focusedPlatformPosition.latitude != 0.0 && focusedPlatformPosition.longitude != 0.0) {
        _mapController.move(focusedPlatformPosition, 17.0);
      }
      platformBox = _getMarkerScreenPosition(focusedPlatformPosition);
    }

    return Scaffold(
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(48.079994, 11.634511),
          initialZoom: 17.0,
          onTap: (tapPosition, point) {
            widget.removeCircularMenuCallback();
            // hide the info box when the map is tapped
            setState(() {
              _isPlatformBoxVisible = false;
              _isWaypointBoxVisible = false;
            });
          },
          onPositionChanged: (camera, hasGesture){
            widget.removeCircularMenuCallback();
            setState(() {
            });
          },
          onLongPress: (tapPosition, point) => {
            widget.removeCircularMenuCallback(),
            widget.showCircularMenuCallback(tapPosition, point)
          },
        ),
        children: [
          TileLayer(
            urlTemplate: _currentUrlTemplate,
            userAgentPackageName: 'com.example.app',
          ),
          PolylineLayer(polylines: _routeLines),
          PolylineLayer(polylines: _trajectories),
          PolygonLayer(polygons: _areas),
          MarkerLayer(markers: _persistentMarkers),
          MarkerLayer(markers: _waypointMarkers),
          MarkerLayer(markers: _platformMarkers),
          if(_isPlatformBoxVisible)
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
                      BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [Text('Platform ID: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_focusedPlatformId),],
                      ),
                      Row(
                        children: [
                          Text('State: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(_focusedPlatformStatus),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          if(_isWaypointBoxVisible)
            Positioned(
              left: _getMarkerScreenPosition(_waypointBoxLatLng).dx,
              top: _getMarkerScreenPosition(_waypointBoxLatLng).dy,
              child: GestureDetector(
                onTap: () {
                  // Prevent closing when tapping inside the info box
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Route Id: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(_routeId),
                        ],
                      ),
                      Row(
                        children: [
                          Text('No.: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text("$_waypointIndex"),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Future<void> _onNewPlatformState(List<Map<String, dynamic>> msgs) async {
    for (final msg in msgs) {
      if (msg.containsKey("platform_status")) {
        String platformId = msg['platform_id'].toString();
        LatLng newPos = LatLng(msg['platform_gps_position']['latitude'], msg['platform_gps_position']['longitude']);

        Marker? existingMarker = getPlatformMarkerById(platformId, _platformMarkers);
        if (existingMarker != null && existingMarker.point == newPos) {
          continue;
        }

        _onUpdatePlatformPose(
          platformId,
          msg['platform_gps_position'],
          msg['platform_pose']['orientation'],
          msg['platform_status'],
        );
      }
    }
  }

  Future<void> _onNewPlatformTrajectories(List<Map<String, dynamic>> msgs) async {
    if(msgs.isNotEmpty){
      _trajectories.clear();
      for (Map<String, dynamic> msg in msgs){
        Marker? marker = getPlatformMarkerById(msg['platform_id'], _platformMarkers);
        if (marker != null) {
          _onUpdateTrajectories(msg['platform_id'], marker.point, msg['trajectory']);
        }else{
          _onUpdateTrajectories(msg['platform_id'], LatLng(0.0, 0.0), msg['trajectory']);
        }
      }
    }else{
      _trajectories.clear();
    }
  }

  Future<void> _onNewSearchMission(Map<String, dynamic> msg) async {
    if(msg.isNotEmpty){
      _onUpdateArea(msg['search_area']);
      for (var noflyzone in msg['no_fly_zones']) {
        _onUpdateArea(noflyzone);
      }
      for (var prioarea in msg['prio_areas']) {
        _onUpdateArea(prioarea);
      }
      for (var dangerzone in msg['danger_zones']) {
        _onUpdateArea(dangerzone);
      }
    }
  }

  Future<void> _onNewWaypoints(List<Map<String, dynamic>> waypoints) async {
    if(waypoints.isNotEmpty){
      _routeLines.clear();
      _waypointMarkers.clear();
      if(waypoints.isNotEmpty){
        for (Map<String, dynamic> msg in waypoints){
          _onUpdateWaypoints(msg['platform_id'], msg['waypoints']);
        }
      }
    }
  }

  void _onUpdateTrajectories(String id, LatLng currentPosition, List<dynamic> points){
    Color trajectoryColor = _getColorFromString(id);
    List<LatLng> latlngs = [];

    for (var point in points) {
      LatLng latlng = LatLng(double.parse(point['lat']), double.parse(point['lon']));
      latlngs.add(latlng);
    }

    if(currentPosition.latitude != 0.0 || currentPosition.longitude != 0.0){
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
    _trajectories.add(route);
    setState(() {});
  }

  void _onUpdatePlatformPose(String id, Map<String, dynamic> position, Map<String, dynamic> orientation, String status) {
    double lat = position['latitude'];
    double lng = position['longitude'];
    LatLng latlng = LatLng(lat, lng);

    double qx = orientation['x'];
    double qy = orientation['y'];
    double qz = orientation['z'];
    double qw = orientation['w'];
    Quaternion q = Quaternion(qx,qy,qz,qw);

    double yaw = _getYawFromQuaternion(q);

    if(!_platformMarkerExists(id)) {
      _addMarker(id, latlng, yaw, status);
    }
    else {
      _updatePlatformMarkerPosition(id, latlng, yaw, status);
    }
  }

  void _onUpdateArea(Map<String, dynamic> area) {
    AreaType areaType = AreaType.values[int.parse(area['type'].toString())];

    List<LatLng> latlngs = [];
    for (var point in area['points']) {
      LatLng latlng = LatLng(double.parse(point['latitude']), double.parse(point['longitude']));
      latlngs.add(latlng);
    }

    Color color = const Color.fromARGB(255, 0, 255, 255);
    switch (areaType) {
      case AreaType.NO_FLY:
      color = const Color.fromARGB(255, 255, 0, 0);
      case AreaType.SEARCH:
      color = const Color.fromARGB(255, 154, 210, 235);
      case AreaType.DANGER:
      color = const Color.fromARGB(255, 255, 255, 0);
      case AreaType.H_PRIO:
      color = const Color.fromARGB(255, 0, 140, 255);
    }

    Polygon areaPolygon = Polygon(
      points: latlngs,
      pattern: const StrokePattern.dotted(),
      holePointsList: [],
      borderStrokeWidth: 4,
      borderColor: color,
      color: color.withOpacity(0.5),
      label: area['description'],
      rotateLabel: true,
      labelPlacement: PolygonLabelPlacement.centroid,
      labelStyle: const TextStyle(color: Colors.black)
    );

    if(_areas.any((existArea) => existArea.label == area['description'])) {
      _areas.removeWhere((existArea) => existArea.label == area['description']);
    }

    _areas.add(areaPolygon);
    setState(() {});
  }

  void _onUpdateWaypoints(String id, List<dynamic> points) {
    List<LatLng> latlngs = [];
    int index = 0;

    for (var point in points) {
      LatLng latlng = LatLng( point['waypoint']['latitude'], point['waypoint']['longitude']);
      latlngs.add(latlng);
      Color color = const Color.fromARGB(255, 0, 0, 0);
      if(index == points.length - 1){
        color = const Color.fromARGB(255, 255, 0, 0);
      }else if(index == 0){
        color = const Color.fromARGB(255, 0, 255, 0);
      }
      int waypointIndex = index+1;
      final Marker newMarker = Marker(
        width: 20.0,
        height: 20.0,
        point: latlng,
        child: GestureDetector(
          onTap: () {
            _isWaypointBoxVisible = true;
            _waypointBoxLatLng = latlng;
            _waypointIndex = waypointIndex;
            _routeId = id;
            setState(() {
              }
            );
          },
          child:
            Icon(
              Icons.gps_fixed,
              size: 20.0,
              color: color,
            )
        )
      );
      _waypointMarkers.add(newMarker);
      index++;
    }

    if(latlngs.isEmpty) return;

    Polyline route = Polyline(
      points: latlngs,
      strokeWidth: 3,
      color: _getColorFromString(id),
      pattern: const StrokePattern.solid(),
      borderStrokeWidth: 1
    );
    _routeLines.add(route);
    setState(() {});
   }

  Color _getColorFromString(String platformId) {
    // If the platform already has a color, return it
    if (_platformColorMap.containsKey(platformId)) {
      return _platformColorMap[platformId]!;
    }

    // Assign a new color based on the current size of the map
    int index = _platformColorMap.length % _colors.length;
    Color assignedColor = _colors[index];

    // Store the assigned color for future reference
    _platformColorMap[platformId] = assignedColor;

    return assignedColor;
  }

  void resetColors() {
    _platformColorMap.clear();
  }

  Offset _getMarkerScreenPosition(LatLng latlng) {
    // Use the latLngToScreenOffset method to get the screen position
    return _mapController.camera.latLngToScreenOffset(latlng);
  }

  void _addMarker(String id, LatLng latlng, double yaw, String status) {
    if(!_platformMarkerExists(id)) {
      final Marker newMarker = Marker(
          key: Key(id),
          width: 30.0,
          height: 30.0,
          point: latlng,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isPlatformBoxVisible = true;
                _focusedPlatformId = id;
                _focusedPlatformStatus = status;
              });
            },
            child: Transform.rotate(
              angle: yaw,
              child: Icon(
                Icons.navigation,
                size: 30.0,
                color: _getColorFromString(id),
              ),
            )
          ),
        );

      if(!_isHomeSet){
        _isHomeSet = true;
        _mapController.move(latlng, 17);
        final Marker newHomeMarker = Marker(
          width: 20.0,
          height: 20.0,
          point: latlng,
          child: const Icon(
            Icons.home,
            size: 20.0,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        );
        _persistentMarkers.add(newHomeMarker);
      }

      setState(() {
        _platformMarkers.add(newMarker);
      });
    }
  }

  // void _removePlatformMarker(String id) {
  //   setState(() {
  //     _platformMarkers.removeWhere((marker) => marker.key == ValueKey(id));
  //   });
  // }

  Marker? getPlatformMarkerById(String id, List<Marker> markerList) {
    try {
      return markerList.firstWhere((marker) => marker.key == Key(id));
    } catch (e) {
      return null;
    }
  }

  bool _platformMarkerExists(String id) {
    return _platformMarkers.any((marker) => marker.key == ValueKey(id));
  }

  void _updatePlatformMarkerPosition(String id, LatLng latlng, double yaw, String status) {
    if(_platformMarkerExists(id)) {
      int index = _platformMarkers.indexWhere((marker) => marker.key == ValueKey(id));
      setState(() {
        _platformMarkers[index] = Marker(
          key: Key(id),
          width: 30.0,
          height: 30.0,
          point: latlng,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isPlatformBoxVisible = true;
                _focusedPlatformId = id;
                _focusedPlatformStatus = status;
              });
            },
            child: Transform.rotate(
              angle: yaw,
              child: Icon(
                Icons.navigation,
                size: 30.0,
                color: _getColorFromString(id),
                ),
            )
          ),
        );
      });
    }
  }

  double _getYawFromQuaternion(Quaternion quat) {
    double yaw = atan2(2 * (quat.w * quat.z + quat.x * quat.y), 1 - 2 * (quat.y * quat.y + quat.z * quat.z));
    return yaw;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
