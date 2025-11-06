import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

/// Represents a physical platform (drone, robot, etc.) with all its state information.
/// This class encapsulates all data from the PlatformState ROS message and provides
/// a centralized way to manage platform information.
class Platform {
  // Core identification
  final String platformId;
  final String platformIp;
  String teamId;

  // Position and orientation
  LatLng gpsPosition;
  Map<String, dynamic> pose;
  double yaw;

  // Status and sensor information
  String status;
  String? sensorId;
  Map<String, dynamic>? sensorPosition;
  int? fovHor;
  int? fovVert;
  int? zoomLevel;
  Map<String, dynamic>? gimbalOrientation;
  double? elevationAngle;
  double? azimuthAngle;
  Map<String, dynamic>? sensorMode;

  // Battery information
  BatteryState? batteryState;

  // Home position (if available)
  LatLng? homePosition;

  // Visual properties
  Color color;
  DateTime lastUpdated;

  Platform({
    required this.platformId,
    required this.platformIp,
    required this.teamId,
    required this.gpsPosition,
    required this.pose,
    required this.yaw,
    required this.status,
    required this.color,
    this.sensorId,
    this.sensorPosition,
    this.fovHor,
    this.fovVert,
    this.zoomLevel,
    this.gimbalOrientation,
    this.elevationAngle,
    this.azimuthAngle,
    this.sensorMode,
    this.batteryState,
    this.homePosition,
  }) : lastUpdated = DateTime.now();

  /// Creates a Platform instance from a ROS message map
  factory Platform.fromMessage(
    Map<String, dynamic> message,
    Color assignedColor,
  ) {
    final gpsPos = message['platform_gps_position'];
    final pose = message['platform_pose'];
    final orientation = pose['orientation'];

    // Calculate yaw from quaternion
    double qx = double.tryParse(orientation['x']?.toString() ?? '0.0') ?? 0.0;
    double qy = double.tryParse(orientation['y']?.toString() ?? '0.0') ?? 0.0;
    double qz = double.tryParse(orientation['z']?.toString() ?? '0.0') ?? 0.0;
    double qw = double.tryParse(orientation['w']?.toString() ?? '1.0') ?? 1.0;
    double yaw = _calculateYawFromQuaternion(qx, qy, qz, qw);

    BatteryState? batteryState;
    if (message.containsKey('battery_state')) {
      batteryState = BatteryState.fromMessage(message['battery_state']);
    }

    LatLng? homePos;
    if (message.containsKey('home_position')) {
      final home = message['home_position'];
      homePos = LatLng(
          double.tryParse(home['latitude']?.toString() ?? '0.0') ?? 0.0,
          double.tryParse(home['longitude']?.toString() ?? '0.0') ?? 0.0);
    }

    return Platform(
      platformId: message['platform_id'].toString(),
      platformIp: message['platform_ip'].toString(),
      teamId: message['team_id'].toString(),
      gpsPosition: LatLng(
          double.tryParse(gpsPos['latitude']?.toString() ?? '0.0') ?? 0.0,
          double.tryParse(gpsPos['longitude']?.toString() ?? '0.0') ?? 0.0),
      pose: pose,
      yaw: yaw,
      status: message['platform_status'].toString(),
      color: assignedColor,
      sensorId: message['sensor_id']?.toString(),
      sensorPosition: message['sensor_position'],
      fovHor: int.tryParse(message['fov_hor']?.toString() ?? '0') ?? 0,
      fovVert: int.tryParse(message['fov_vert']?.toString() ?? '0') ?? 0,
      zoomLevel: int.tryParse(message['zoom_level']?.toString() ?? '0') ?? 0,
      gimbalOrientation: message['gimbal_orientation'],
      elevationAngle:
          double.tryParse(message['elevation_angle']?.toString() ?? '0.0') ??
              0.0,
      azimuthAngle:
          double.tryParse(message['azimuth_angle']?.toString() ?? '0.0') ?? 0.0,
      sensorMode: message['sensor_mode'],
      batteryState: batteryState,
      homePosition: homePos,
    );
  }

  /// Updates platform data from a new ROS message
  void updateFromMessage(Map<String, dynamic> message) {
    final gpsPos = message['platform_gps_position'];
    final pose = message['platform_pose'];
    final orientation = pose['orientation'];

    // Always update position
    final newPosition = LatLng(
        double.tryParse(gpsPos['latitude']?.toString() ?? '0.0') ?? 0.0,
        double.tryParse(gpsPos['longitude']?.toString() ?? '0.0') ?? 0.0);
    gpsPosition = newPosition;
    this.pose = pose;

    // Calculate new yaw and always update it
    double qx = double.tryParse(orientation['x']?.toString() ?? '0.0') ?? 0.0;
    double qy = double.tryParse(orientation['y']?.toString() ?? '0.0') ?? 0.0;
    double qz = double.tryParse(orientation['z']?.toString() ?? '0.0') ?? 0.0;
    double qw = double.tryParse(orientation['w']?.toString() ?? '1.0') ?? 1.0;
    final newYaw = _calculateYawFromQuaternion(qx, qy, qz, qw);
    yaw = newYaw; // Always update yaw

    // Update status and other properties
    status = message['platform_status'].toString();
    teamId = message['team_id'].toString();
    sensorId = message['sensor_id']?.toString();
    sensorPosition = message['sensor_position'];
    fovHor = int.tryParse(message['fov_hor']?.toString() ?? '0') ?? 0;
    fovVert = int.tryParse(message['fov_vert']?.toString() ?? '0') ?? 0;
    zoomLevel = int.tryParse(message['zoom_level']?.toString() ?? '0') ?? 0;
    gimbalOrientation = message['gimbal_orientation'];
    elevationAngle =
        double.tryParse(message['elevation_angle']?.toString() ?? '0.0') ?? 0.0;
    azimuthAngle =
        double.tryParse(message['azimuth_angle']?.toString() ?? '0.0') ?? 0.0;
    sensorMode = message['sensor_mode'];

    // Update battery state
    if (message.containsKey('battery_state')) {
      batteryState = BatteryState.fromMessage(message['battery_state']);
    }

    // Handle home position based on platform status
    if (status == 'DISCONNECTED') {
      // Remove home position for disconnected platforms
      homePosition = null;
    } else if (message.containsKey('home_position')) {
      // Update home position for connected platforms
      final home = message['home_position'];
      final newHomePos = LatLng(
          double.tryParse(home['latitude']?.toString() ?? '0.0') ?? 0.0,
          double.tryParse(home['longitude']?.toString() ?? '0.0') ?? 0.0);
      // Only update if it's a valid position (not 0,0)
      if (newHomePos.latitude != 0.0 || newHomePos.longitude != 0.0) {
        homePosition = newHomePos;
      }
    }

    // Always update timestamp - this ensures UI gets the latest data
    lastUpdated = DateTime.now();
  }

  /// Checks if the platform has moved significantly from the given position
  bool hasMovedFrom(LatLng previousPosition, {double threshold = 0.0001}) {
    double latDiff = (gpsPosition.latitude - previousPosition.latitude).abs();
    double lngDiff = (gpsPosition.longitude - previousPosition.longitude).abs();
    return latDiff > threshold || lngDiff > threshold;
  }

  /// Checks if the platform status has changed
  bool hasStatusChanged(String previousStatus) {
    return status != previousStatus;
  }

  /// Returns a formatted string representation of the platform's current state
  String getStatusSummary() {
    StringBuffer summary = StringBuffer();
    summary.writeln('Platform: $platformId');
    summary.writeln('Platform IP: $platformIp');
    summary.writeln('Team: $teamId');
    summary.writeln('Status: $status');
    summary.writeln(
        'Position: ${gpsPosition.latitude.toStringAsFixed(6)}, ${gpsPosition.longitude.toStringAsFixed(6)}');

    if (batteryState != null) {
      summary.writeln(
          'Battery: ${(batteryState!.percentage * 100).toStringAsFixed(1)}%');
    }

    if (sensorId != null) {
      summary.writeln('Sensor: $sensorId');
    }

    return summary.toString();
  }

  /// Calculate yaw angle from quaternion
  static double _calculateYawFromQuaternion(
      double qx, double qy, double qz, double qw) {
    return atan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy * qy + qz * qz));
  }

  @override
  String toString() {
    return 'Platform(id: $platformId, team: $teamId, status: $status, position: $gpsPosition)';
  }

  /// Converts Platform object back to a Map format similar to ROS message
  Map<String, dynamic> toMap() {
    return {
      'platform_id': platformId,
      'platform_ip': platformIp,
      'team_id': teamId,
      'platform_gps_position': {
        'latitude': gpsPosition.latitude,
        'longitude': gpsPosition.longitude,
      },
      'platform_pose': pose,
      'platform_status': status,
      'sensor_id': sensorId,
      'sensor_position': sensorPosition,
      'fov_hor': fovHor,
      'fov_vert': fovVert,
      'zoom_level': zoomLevel,
      'gimbal_orientation': gimbalOrientation,
      'elevation_angle': elevationAngle,
      'azimuth_angle': azimuthAngle,
      'sensor_mode': sensorMode,
      if (batteryState != null)
        'battery_state': {
          'voltage': batteryState!.voltage,
          'current': batteryState!.current,
          'charge': batteryState!.charge,
          'capacity': batteryState!.capacity,
          'design_capacity': batteryState!.designCapacity,
          'percentage': batteryState!.percentage,
          'cell_voltage': batteryState!.cellVoltages,
        },
      if (homePosition != null)
        'home_position': {
          'latitude': homePosition!.latitude,
          'longitude': homePosition!.longitude,
        },
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Platform && other.platformId == platformId;
  }

  @override
  int get hashCode => platformId.hashCode;
}

/// Represents the battery state information from ROS message
class BatteryState {
  final double voltage;
  final double current;
  final double charge;
  final double capacity;
  final double designCapacity;
  final double percentage;
  final List<double> cellVoltages;

  BatteryState({
    required this.voltage,
    required this.current,
    required this.charge,
    required this.capacity,
    required this.designCapacity,
    required this.percentage,
    required this.cellVoltages,
  });

  factory BatteryState.fromMessage(Map<String, dynamic> message) {
    List<double> cellVoltages = [];
    if (message['cell_voltage'] != null) {
      cellVoltages = (message['cell_voltage'] as List<dynamic>)
          .map<double>((v) => double.tryParse(v?.toString() ?? '0.0') ?? 0.0)
          .toList();
    }

    return BatteryState(
      voltage: double.tryParse(message['voltage']?.toString() ?? '0.0') ?? 0.0,
      current: double.tryParse(message['current']?.toString() ?? '0.0') ?? 0.0,
      charge: double.tryParse(message['charge']?.toString() ?? '0.0') ?? 0.0,
      capacity:
          double.tryParse(message['capacity']?.toString() ?? '0.0') ?? 0.0,
      designCapacity:
          double.tryParse(message['design_capacity']?.toString() ?? '0.0') ??
              0.0,
      percentage:
          double.tryParse(message['percentage']?.toString() ?? '0.0') ?? 0.0,
      cellVoltages: cellVoltages,
    );
  }

  /// Returns battery level as a percentage (0-1)
  double get batteryLevel => percentage;

  /// Returns battery level as a percentage (0-100)
  double get batteryLevelPercent => percentage * 1;

  /// Returns true if battery is critically low (below 20%)
  bool get isCriticallyLow => percentage < 0.2;

  /// Returns true if battery is low (below 30%)
  bool get isLow => percentage < 0.3;

  /// Returns appropriate color for battery level
  Color get batteryColor {
    if (isCriticallyLow) return Colors.red;
    if (isLow) return Colors.orange;
    return Colors.green;
  }

  @override
  String toString() {
    return 'BatteryState(${batteryLevelPercent.toStringAsFixed(1)}%, ${voltage.toStringAsFixed(1)}V)';
  }
}
