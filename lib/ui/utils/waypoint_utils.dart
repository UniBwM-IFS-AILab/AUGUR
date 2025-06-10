import 'dart:async';
import 'package:redis/redis.dart';
import 'dart:convert';

// Function to process actions and add waypoints
Future<List<Map<String, dynamic>>> addWaypointsToActions(Command? command,   List<Map<String, dynamic>> actionsList) async {

  for (var actionItem in actionsList) {
    List<Map<String, dynamic>> waypoints = [];

    if (actionItem.containsKey('actions')) {
      for (var action in actionItem['actions']) {
        String actionName = action['action_name'];

        // Check if action name contains "fly"
        if (actionName.toLowerCase().contains("fly")) {
          var parameters = action['parameters'];

          if (parameters.length > 1) {
            var waypointData = parameters[1]; // Second parameter contains waypoints

            if (waypointData['symbol_atom'].isNotEmpty) {

              String locationName = waypointData['symbol_atom'][0];

              var resolvedLocation = await resolveStringWP(command!, locationName);

              waypoints.add({
                "action_name": actionName,
                "waypoint": resolvedLocation,
              });
            }
            // If waypointData contains real lat/lon values, use them directly
            else if (waypointData['real_atom'].isNotEmpty) {

              var lat = double.parse(waypointData['real_atom'][0]['numerator'].toString()) /
                  double.parse(waypointData['real_atom'][0]['denominator'].toString());

              var lon = double.parse(parameters[2]['real_atom'][0]['numerator'].toString()) /
                  double.parse(parameters[2]['real_atom'][0]['denominator'].toString());
              waypoints.add({
                "action_name": actionName,
                "waypoint": {"latitude": lat, "longitude": lon},
              });
            }
          }
        }
      }
    }

    // Add waypoints to the actionItem
    actionItem['waypoints'] = waypoints;
  }

  return actionsList;
}

// Function to resolve a string-based waypoint into latitude and longitude
Future<Map<String, double>> resolveStringWP(Command command, String location) async {
  var resolvedWP = await command.send_object(['JSON.GET', 'geographic', "\$.areas[?(@.name=='$location')]"]);
  // Simulated database of locations
  if(resolvedWP != null){
    try{
      final outerList = jsonDecode(resolvedWP) as List<dynamic>;

      if (outerList.isNotEmpty && outerList.first.containsKey('centre')) {
        Map<String, double> location = {
          "latitude": double.parse(outerList.first['centre'][0].toString()),
          "longitude": double.parse(outerList.first['centre'][1].toString())
        };
        return location;
      }
    } catch (e) {
      print("Error fetching location data: $e.");
    }
    return {"latitude": 0.0, "longitude": 0.0};
  }
  return {"latitude": 0.0, "longitude": 0.0};
}
