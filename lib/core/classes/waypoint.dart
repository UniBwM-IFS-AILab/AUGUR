import 'package:latlong2/latlong.dart';

class WaypointWithAltitude {
  final LatLng position;
  final double altitudeMeters;

  const WaypointWithAltitude({
    required this.position,
    this.altitudeMeters = 5.0, // Default to 5 meters
  });

  WaypointWithAltitude copyWith({
    LatLng? position,
    double? altitudeMeters,
  }) {
    return WaypointWithAltitude(
      position: position ?? this.position,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WaypointWithAltitude &&
        other.position == position &&
        other.altitudeMeters == altitudeMeters;
  }

  @override
  int get hashCode => position.hashCode ^ altitudeMeters.hashCode;

  @override
  String toString() {
    return 'WaypointWithAltitude(position: $position, altitudeMeters: ${altitudeMeters}m)';
  }
}
