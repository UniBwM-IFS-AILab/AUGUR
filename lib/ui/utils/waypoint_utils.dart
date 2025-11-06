import 'dart:async';
import 'package:flutter/material.dart';
import 'package:redis/redis.dart';
import 'dart:convert';

// Function to process actions and add waypoints - DEPRECATED
// This functionality has been moved to the Plan class
// Kept for backward compatibility during migration
Future<List<Map<String, dynamic>>> addWaypointsToActions(
    Command? command, List<Map<String, dynamic>> planList) async {
  debugPrint("WARNING: addWaypointsToActions is deprecated. Use Plan class instead.");

  for (var plan in planList) {
    List<Map<String, dynamic>> waypoints = [];

    if (plan.containsKey('actions')) {
      for (var action in plan['actions']) {
        String actionName = action['action_name'];

        // Check if action name contains "fly"
        if (actionName.toLowerCase().contains("fly")) {
          var parameters = action['parameters'];

          if (parameters.length > 1) {
            var waypointData =
                parameters[1]; // Second parameter contains waypoints

            if (waypointData['symbol_atom'].isNotEmpty) {
              String locationName = waypointData['symbol_atom'][0];

              if (locationName.toLowerCase() == "home") {
                debugPrint("Got a home location without platform assignment. Skipping for now.");
                continue;
              }

              var resolvedLocation =
                  await resolveStringWP(command!, locationName);

              if (resolvedLocation['latitude'] == 0.0 &&
                  resolvedLocation['longitude'] == 0.0) {
                continue;
              }

              waypoints.add({
                "action_name": actionName,
                "waypoint": resolvedLocation,
              });
            }
            // If waypointData contains real lat/lon values, use them directly
            else if (waypointData['real_atom'].isNotEmpty) {
              var lat = double.parse(
                      waypointData['real_atom'][0]['numerator'].toString()) /
                  double.parse(
                      waypointData['real_atom'][0]['denominator'].toString());

              var lon = double.parse(
                      parameters[2]['real_atom'][0]['numerator'].toString()) /
                  double.parse(
                      parameters[2]['real_atom'][0]['denominator'].toString());
              waypoints.add({
                "action_name": actionName,
                "waypoint": {"latitude": lat, "longitude": lon},
              });
            }
          }
        }
      }
    }

    // Add waypoints to the plan
    plan['waypoints'] = waypoints;
  }

  return planList;
}

// Function to resolve a string-based waypoint into latitude and longitude
Future<Map<String, double>> resolveStringWP(
    Command command, String location) async {
  var resolvedWP = await command
      .send_object(['JSON.GET', 'area', "\$[?(@.name=='$location')]"]);

  // Simulated database of locations
  if (resolvedWP != null) {
    try {
      final outerList = jsonDecode(resolvedWP) as List<dynamic>;

      if (outerList.isNotEmpty && outerList.first.containsKey('points')) {
        var points = outerList.first['points'] as List<dynamic>;
        if (points.isNotEmpty &&
            points.first is List &&
            points.first.length >= 2) {
          Map<String, double> location = {
            "latitude": double.parse(points.first[0].toString()),
            "longitude": double.parse(points.first[1].toString())
          };
          return location;
        }
      }
    } catch (e) {
      debugPrint("Error fetching location data: $e.");
    }
    return {"latitude": 0.0, "longitude": 0.0};
  }
  return {"latitude": 0.0, "longitude": 0.0};
}
