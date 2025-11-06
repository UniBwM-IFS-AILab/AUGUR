import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Represents a detected object from the ObjectKnowledge message.
/// This class encapsulates all data from the ObjectKnowledge ROS message and provides
/// a centralized way to manage detected object information.
class DetectedObject {
  // Core identification
  final String id;

  // Detection information
  final String detectionClass;
  final int priority;
  final DateTime timeStamp;

  // Position and movement
  final LatLng position;
  final Map<String, dynamic> velocity; // x, y, z components

  // Confidence and state
  final double confidence;
  final String state;

  // Visual properties
  final Color color;
  final DateTime lastUpdated;

  DetectedObject({
    required this.id,
    required this.detectionClass,
    required this.priority,
    required this.timeStamp,
    required this.position,
    required this.velocity,
    required this.confidence,
    required this.state,
    required this.color,
  }) : lastUpdated = DateTime.now();

  /// Creates a DetectedObject instance from a Redis database map
  /// Note: All values from database are stringified, so we need to cast them
  factory DetectedObject.fromMessage(
    Map<String, dynamic> message,
    Color assignedColor,
  ) {
    // Parse position from geometry_msgs/Point
    final position = message['position'];
    final double lat = double.tryParse(position['x']?.toString() ?? '0.0') ?? 0.0;
    final double lng = double.tryParse(position['y']?.toString() ?? '0.0') ?? 0.0;
    
    // Parse velocity from geometry_msgs/Vector3
    final velocity = message['velocity'] ?? {};
    
    // Parse timestamp from builtin_interfaces/Time
    final timeStampMsg = message['time_stamp'];
    DateTime parsedTimeStamp = DateTime.now();
    
    if (timeStampMsg != null) {
      try {
        final int sec = int.tryParse(timeStampMsg['sec']?.toString() ?? '0') ?? 0;
        final int nanosec = int.tryParse(timeStampMsg['nanosec']?.toString() ?? '0') ?? 0;
        // Convert ROS time to DateTime (sec since epoch + nanoseconds)
        parsedTimeStamp = DateTime.fromMillisecondsSinceEpoch(
          sec * 1000 + (nanosec ~/ 1000000)
        );
      } catch (e) {
        debugPrint('DetectedObject: Error parsing timestamp: $e');
        parsedTimeStamp = DateTime.now();
      }
    }

    return DetectedObject(
      id: message['id']?.toString() ?? '',
      detectionClass: message['detection_class']?.toString() ?? 'unknown',
      priority: int.tryParse(message['priority']?.toString() ?? '0') ?? 0,
      timeStamp: parsedTimeStamp,
      position: LatLng(lat, lng),
      velocity: {
        'x': double.tryParse(velocity['x']?.toString() ?? '0.0') ?? 0.0,
        'y': double.tryParse(velocity['y']?.toString() ?? '0.0') ?? 0.0,
        'z': double.tryParse(velocity['z']?.toString() ?? '0.0') ?? 0.0,
      },
      confidence: double.tryParse(message['confidence']?.toString() ?? '0.0') ?? 0.0,
      state: message['state']?.toString() ?? 'unknown',
      color: assignedColor,
    );
  }

  /// Updates this DetectedObject with new data from a message
  DetectedObject updateWith(Map<String, dynamic> message) {
    // Parse position from geometry_msgs/Point
    final position = message['position'];
    final double lat = double.tryParse(position['x']?.toString() ?? '0.0') ?? 0.0;
    final double lng = double.tryParse(position['y']?.toString() ?? '0.0') ?? 0.0;
    
    // Parse velocity from geometry_msgs/Vector3
    final velocity = message['velocity'] ?? {};
    
    // Parse timestamp from builtin_interfaces/Time
    final timeStampMsg = message['time_stamp'];
    DateTime parsedTimeStamp = timeStamp;
    
    if (timeStampMsg != null) {
      try {
        final int sec = int.tryParse(timeStampMsg['sec']?.toString() ?? '0') ?? 0;
        final int nanosec = int.tryParse(timeStampMsg['nanosec']?.toString() ?? '0') ?? 0;
        parsedTimeStamp = DateTime.fromMillisecondsSinceEpoch(
          sec * 1000 + (nanosec ~/ 1000000)
        );
      } catch (e) {
        debugPrint('DetectedObject: Error parsing timestamp during update: $e');
      }
    }

    return DetectedObject(
      id: id, // ID shouldn't change
      detectionClass: message['detection_class']?.toString() ?? detectionClass,
      priority: int.tryParse(message['priority']?.toString() ?? '0') ?? priority,
      timeStamp: parsedTimeStamp,
      position: LatLng(lat, lng),
      velocity: {
        'x': double.tryParse(velocity['x']?.toString() ?? '0.0') ?? 0.0,
        'y': double.tryParse(velocity['y']?.toString() ?? '0.0') ?? 0.0,
        'z': double.tryParse(velocity['z']?.toString() ?? '0.0') ?? 0.0,
      },
      confidence: double.tryParse(message['confidence']?.toString() ?? '0.0') ?? confidence,
      state: message['state']?.toString() ?? state,
      color: color, // Keep existing color
    );
  }

  /// Checks if this object has significant changes compared to another DetectedObject
  bool hasSignificantChanges(DetectedObject other) {
    // Check basic properties
    if (detectionClass != other.detectionClass ||
        priority != other.priority ||
        state != other.state) {
      return true;
    }

    // Check confidence change (significant if difference > 0.1)
    if ((confidence - other.confidence).abs() > 0.1) {
      return true;
    }

    // Check position change (significant if moved more than ~1 meter)
    const double significantDistance = 0.00001; // roughly 1 meter in degrees
    if ((position.latitude - other.position.latitude).abs() > significantDistance ||
        (position.longitude - other.position.longitude).abs() > significantDistance) {
      return true;
    }

    // Check velocity change (significant if any component changed by more than 0.5)
    if ((velocity['x'] - other.velocity['x']).abs() > 0.5 ||
        (velocity['y'] - other.velocity['y']).abs() > 0.5 ||
        (velocity['z'] - other.velocity['z']).abs() > 0.5) {
      return true;
    }

    // Check if timestamp is significantly different (more than 1 second)
    if (timeStamp.difference(other.timeStamp).abs().inSeconds > 1) {
      return true;
    }

    return false;
  }

  /// Gets the appropriate icon for the detection class
  IconData get classIcon {
    switch (detectionClass.toLowerCase()) {
      case 'car':
      case 'vehicle':
        return Icons.directions_car;
      case 'person':
      case 'pedestrian':
        return Icons.person;
      case 'bicycle':
      case 'bike':
        return Icons.directions_bike;
      default:
        return Icons.location_on; // Default icon for unknown classes
    }
  }

  /// Gets a color based on the detection class
  static Color getColorForClass(String detectionClass) {
    switch (detectionClass.toLowerCase()) {
      case 'car':
      case 'vehicle':
        return Colors.blue;
      case 'person':
      case 'pedestrian':
        return Colors.green;
      case 'bicycle':
      case 'bike':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Gets priority text representation
  String get priorityText {
    if (priority < 3) {
      return 'Low ($priority)';
    } else if (priority < 7) {
      return 'Medium ($priority)';
    } else {
      return 'High ($priority)';
    }
  }

  /// Gets priority color
  Color get priorityColor {
    if (priority < 3) {
      return Colors.green;
    } else if (priority < 7) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Gets confidence percentage text
  String get confidenceText {
    return '${(confidence * 100).toStringAsFixed(1)}%';
  }

  /// Gets confidence color based on value
  Color get confidenceColor {
    if (confidence >= 0.8) {
      return Colors.green;
    } else if (confidence >= 0.5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Returns a formatted string representation of the velocity
  String get velocityText {
    final vx = velocity['x']?.toStringAsFixed(2) ?? '0.00';
    final vy = velocity['y']?.toStringAsFixed(2) ?? '0.00';
    final vz = velocity['z']?.toStringAsFixed(2) ?? '0.00';
    return '($vx, $vy, $vz) m/s';
  }

  /// Returns the speed magnitude
  double get speed {
    final vx = velocity['x'] ?? 0.0;
    final vy = velocity['y'] ?? 0.0;
    final vz = velocity['z'] ?? 0.0;
    return sqrt(vx * vx + vy * vy + vz * vz);
  }

  @override
  String toString() {
    return 'DetectedObject(id: $id, class: $detectionClass, priority: $priority, '
           'confidence: $confidenceText, state: $state, '
           'position: (${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}))';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DetectedObject && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}