import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:redis/redis.dart';
import 'package:augur/ui/utils/waypoint_utils.dart';

/// Represents a plan status according to PlanStatus.msg
enum PlanStatus {
  inactive(1),
  active(2),
  paused(3),
  completed(4),
  aborted(5),
  canceled(6);

  const PlanStatus(this.value);
  final int value;

  String get name {
    switch (this) {
      case PlanStatus.inactive:
        return 'inactive';
      case PlanStatus.active:
        return 'active';
      case PlanStatus.paused:
        return 'paused';
      case PlanStatus.completed:
        return 'completed';
      case PlanStatus.aborted:
        return 'aborted';
      case PlanStatus.canceled:
        return 'canceled';
    }
  }

  static PlanStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'INACTIVE':
        return PlanStatus.inactive;
      case 'ACTIVE':
        return PlanStatus.active;
      case 'PAUSED':
        return PlanStatus.paused;
      case 'COMPLETED':
        return PlanStatus.completed;
      case 'ABORTED':
        return PlanStatus.aborted;
      case 'CANCELED':
        return PlanStatus.canceled;
      default:
        return PlanStatus.inactive;
    }
  }
}

/// Represents an Atom from upf_msgs/Atom.msg
class Atom {
  final String? symbolAtom;
  final int? intAtom;
  final Real? realAtom;
  final bool? booleanAtom;

  Atom({
    this.symbolAtom,
    this.intAtom,
    this.realAtom,
    this.booleanAtom,
  });

  factory Atom.fromMessage(Map<String, dynamic> message) {
    String? symbol;
    int? intValue;
    Real? realValue;
    bool? boolValue;
    if (message.containsKey('symbol_atom') &&
        message['symbol_atom'] is List &&
        message['symbol_atom'].isNotEmpty) {
      symbol = message['symbol_atom'][0]?.toString();
    }

    if (message.containsKey('int_atom') &&
        message['int_atom'] is List &&
        message['int_atom'].isNotEmpty) {
      intValue = int.tryParse(message['int_atom'][0]?.toString() ?? '0') ?? 0;
    }

    if (message.containsKey('real_atom') &&
        message['real_atom'] is List &&
        message['real_atom'].isNotEmpty) {
      realValue = Real.fromMessage(message['real_atom'][0]);
    }

    if (message.containsKey('boolean_atom') &&
        message['boolean_atom'] is List &&
        message['boolean_atom'].isNotEmpty) {
      // Handle stringified boolean values
      final boolString = message['boolean_atom'][0]?.toString().toLowerCase();
      boolValue = boolString == 'true' || boolString == '1';
    }

    return Atom(
      symbolAtom: symbol,
      intAtom: intValue,
      realAtom: realValue,
      booleanAtom: boolValue,
    );
  }

  double? get asDouble {
    if (realAtom != null) {
      return realAtom!.value;
    }
    if (intAtom != null) {
      return intAtom!.toDouble();
    }
    return null;
  }

  String? get asString {
    return symbolAtom;
  }

  Map<String, dynamic> toMessage() {
    Map<String, dynamic> message = {};

    if (symbolAtom != null) {
      message['symbol_atom'] = [symbolAtom];
    } else {
      message['symbol_atom'] = [];
    }

    if (intAtom != null) {
      message['int_atom'] = [intAtom];
    } else {
      message['int_atom'] = [];
    }

    if (realAtom != null) {
      message['real_atom'] = [realAtom!.toMessage()];
    } else {
      message['real_atom'] = [];
    }

    if (booleanAtom != null) {
      message['boolean_atom'] = [booleanAtom];
    } else {
      message['boolean_atom'] = [];
    }

    return message;
  }
}

/// Represents a Real number from upf_msgs/Real.msg
class Real {
  final int numerator;
  final int denominator;

  Real({required this.numerator, required this.denominator});

  factory Real.fromMessage(Map<String, dynamic> message) {
    return Real(
      numerator: int.tryParse(message['numerator']?.toString() ?? '0') ?? 0,
      denominator: int.tryParse(message['denominator']?.toString() ?? '1') ?? 1,
    );
  }

  factory Real.fromDouble(double value) {
    // Convert double to fraction with reasonable precision
    const int precision = 1000000;
    int num = (value * precision).round();
    return Real(numerator: num, denominator: precision);
  }

  double get value => denominator != 0 ? numerator / denominator : 0.0;

  Map<String, dynamic> toMessage() {
    return {
      'numerator': numerator,
      'denominator': denominator,
    };
  }
}

/// Represents an ActionInstance from auspex_msgs/ActionInstance.msg
class ActionInstance {
  final int id;
  final String actionName;
  final int taskId;
  final List<Atom> parameters;
  final String status;

  ActionInstance({
    required this.id,
    required this.actionName,
    required this.taskId,
    required this.parameters,
    required this.status,
  });

  factory ActionInstance.fromMessage(Map<String, dynamic> message) {
    List<Atom> params = [];
    if (message.containsKey('parameters') && message['parameters'] is List) {
      params = (message['parameters'] as List)
          .map((param) => Atom.fromMessage(param))
          .toList();
    }

    return ActionInstance(
      id: int.tryParse(message['id']?.toString() ?? '0') ?? 0,
      actionName: message['action_name']?.toString() ?? '',
      taskId: int.tryParse(message['task_id']?.toString() ?? '0') ?? 0,
      parameters: params,
      status: message['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMessage() {
    return {
      'id': id,
      'action_name': actionName,
      'task_id': taskId,
      'parameters': parameters.map((param) => param.toMessage()).toList(),
      'status': status,
    };
  }

  /// Check if this action is a fly action (contains "fly" in the name)
  bool get isFlyAction => actionName.toLowerCase().contains('fly');

  /// Extract waypoint from fly action parameters
  /// Expected format: fly(param1, lat, lon, alt)
  LatLng? get waypoint {
    if (!isFlyAction || parameters.length < 3) return null;

    try {
      // Second parameter (index 1) should be latitude
      double? lat = parameters[1].asDouble;
      // Third parameter (index 2) should be longitude
      double? lon = parameters[2].asDouble;

      if (lat != null && lon != null) {
        return LatLng(lat, lon);
      }
    } catch (e) {
      debugPrint('Error extracting waypoint from action $actionName: $e');
    }

    return null;
  }

  /// Get altitude from fly action parameters
  double? get altitude {
    if (!isFlyAction || parameters.length < 4) return null;

    try {
      // Fourth parameter (index 3) should be altitude
      return parameters[3].asDouble;
    } catch (e) {
      debugPrint('Error extracting altitude from action $actionName: $e');
    }

    return null;
  }

  /// Get location name from symbolic parameter
  String? get locationName {
    if (!isFlyAction || parameters.length < 2) return null;

    try {
      // Second parameter might be a symbolic location
      return parameters[1].asString;
    } catch (e) {
      debugPrint('Error extracting location name from action $actionName: $e');
    }

    return null;
  }
}

/// Represents a waypoint derived from an action
class Waypoint {
  final String actionName;
  final LatLng position;
  final double altitude;

  Waypoint({
    required this.actionName,
    required this.position,
    required this.altitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'action_name': actionName,
      'waypoint': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'altitude': altitude,
      },
    };
  }
}

/// Represents a Plan from auspex_msgs/Plan.msg
class Plan {
  String platformId; // Made mutable to allow updates
  String teamId; // Made mutable to allow updates
  int priority; // Made mutable to allow updates
  final int planId;
  PlanStatus status; // Made mutable to allow updates
  final List<ActionInstance> tasks;
  final List<ActionInstance> actions;

  // Generated waypoints from actions
  List<Waypoint> waypoints = [];

  // Visual properties
  Color color;
  DateTime lastUpdated;

  Plan({
    required this.platformId,
    required this.teamId,
    required this.priority,
    required this.planId,
    required this.status,
    required this.tasks,
    required this.actions,
    required this.color,
  }) : lastUpdated = DateTime.now() {
    // Generate waypoints immediately after creation
    _generateWaypoints();
  }

  /// Get the display color for this plan based on its status
  /// For completed and canceled plans, returns the original color with reduced opacity
  /// This method should be used with platform colors from the platform provider
  Color getDisplayColor(Color platformColor) {
    switch (status) {
      case PlanStatus.completed:
      case PlanStatus.canceled:
        // Use the platform's color with 20% opacity (80% transparency) for completed/canceled plans
        return platformColor.withValues(alpha: 0.1);
      default:
        // Use the platform's original color for active plans
        return platformColor;
    }
  }

  /// Creates a Plan instance from a ROS message map
  factory Plan.fromMessage(
    Map<String, dynamic> message,
    Color assignedColor,
  ) {
    List<ActionInstance> tasksList = [];
    List<ActionInstance> actionsList = [];

    if (message.containsKey('tasks') && message['tasks'] is List) {
      tasksList = (message['tasks'] as List)
          .map((task) => ActionInstance.fromMessage(task))
          .toList();
    }

    if (message.containsKey('actions') && message['actions'] is List) {
      actionsList = (message['actions'] as List)
          .map((action) => ActionInstance.fromMessage(action))
          .toList();
    }

    PlanStatus planStatus = PlanStatus.inactive;
    if (message.containsKey('status')) {
      planStatus =
          PlanStatus.fromString(message['status']?.toString() ?? 'inactive');
    }

    return Plan(
      platformId: message['platform_id']?.toString() ?? '',
      teamId: message['team_id']?.toString() ?? '',
      priority: int.tryParse(message['priority']?.toString() ?? '0') ?? 0,
      planId: int.tryParse(message['plan_id']?.toString() ?? '0') ?? 0,
      status: planStatus,
      tasks: tasksList,
      actions: actionsList,
      color: assignedColor,
    );
  }

  /// Updates the plan from a new message
  void updateFromMessage(Map<String, dynamic> message) {
    // Update platform_id if present
    if (message.containsKey('platform_id')) {
      platformId = message['platform_id']?.toString() ?? platformId;
    }

    // Update team_id if present
    if (message.containsKey('team_id')) {
      teamId = message['team_id']?.toString() ?? teamId;
    }

    // Update priority if present
    if (message.containsKey('priority')) {
      priority = int.tryParse(
              message['priority']?.toString() ?? priority.toString()) ??
          priority;
    }

    // Update status if present
    if (message.containsKey('status')) {
      status =
          PlanStatus.fromString(message['status']?.toString() ?? status.name);
    }

    // Update tasks and actions
    if (message.containsKey('tasks') && message['tasks'] is List) {
      tasks.clear();
      tasks.addAll((message['tasks'] as List)
          .map((task) => ActionInstance.fromMessage(task))
          .toList());
    }

    if (message.containsKey('actions') && message['actions'] is List) {
      actions.clear();
      actions.addAll((message['actions'] as List)
          .map((action) => ActionInstance.fromMessage(action))
          .toList());
    }

    lastUpdated = DateTime.now();

    // Regenerate waypoints after update
    _generateWaypoints();
  }

  /// Generate waypoints from actions using the waypoint utils logic
  void _generateWaypoints() {
    waypoints.clear();

    for (var action in actions) {
      if (action.isFlyAction) {
        LatLng? position = action.waypoint;
        double altitude = action.altitude ?? 10.0; // Default altitude

        if (position != null) {
          waypoints.add(Waypoint(
            actionName: action.actionName,
            position: position,
            altitude: altitude,
          ));
        }
      }
    }
  }

  /// Generate waypoints from actions with Redis lookup for symbolic locations
  Future<void> generateWaypointsWithRedis(Command? command) async {
    waypoints.clear();

    for (var action in actions) {
      if (action.isFlyAction) {
        // First try to get direct coordinates
        LatLng? position = action.waypoint;
        double altitude = action.altitude ?? 10.0;

        if (position != null) {
          waypoints.add(Waypoint(
            actionName: action.actionName,
            position: position,
            altitude: altitude,
          ));
        } else {
          // Try to resolve symbolic location
          String? locationName = action.locationName;
          if (locationName != null && command != null) {
            var resolvedLocation = await resolveStringWP(command, locationName);
            if (resolvedLocation['latitude'] != 0.0 ||
                resolvedLocation['longitude'] != 0.0) {
              waypoints.add(Waypoint(
                actionName: action.actionName,
                position: LatLng(resolvedLocation['latitude']!,
                    resolvedLocation['longitude']!),
                altitude: altitude,
              ));
            }
          }
        }
      }
    }
  }

  /// Convert plan back to message format for Redis storage
  Map<String, dynamic> toMessage() {
    return {
      'platform_id': platformId,
      'team_id': teamId,
      'priority': priority,
      'plan_id': planId,
      'status': status.name.toUpperCase(),
      'tasks': tasks.map((task) => task.toMessage()).toList(),
      'actions': actions.map((action) => action.toMessage()).toList(),
    };
  }

  /// Get waypoints in the format expected by the old system
  List<Map<String, dynamic>> get waypointsAsJson {
    return waypoints.map((wp) => wp.toJson()).toList();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Plan && other.planId == planId;
  }

  @override
  int get hashCode => planId.hashCode;
}
