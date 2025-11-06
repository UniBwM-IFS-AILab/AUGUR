/// Map configuration for tile servers and map settings
class MapConfig {
  /// User-Agent string that complies with OSM tile usage policy
  /// Replace the contact email with your actual contact information
  static const String userAgent =
      'AUGUR Flutter App/0.9.0 (contact: bjoern.doeschl@unibw.de)';

  /// Package name for user agent
  static const String userAgentPackageName = 'augur.flutter.app';

  /// Alternative OSM-compatible tile servers
  /// Using alternative servers reduces load on main OSM infrastructure
  static const List<String> osmTileServers = [
    'https://tile.openstreetmap.de/{z}/{x}/{y}.png', // German OSM server
    'https://tiles.wmflabs.org/osm/{z}/{x}/{y}.png', // Wikimedia OSM tiles
    'https://tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png', // French OSM server
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // Main OSM server (fallback)
  ];

  /// Default tile server index
  static const int defaultTileServerIndex = 0;

  /// Maximum zoom level to respect server limits
  static const double maxZoom = 19.0;

  /// Default zoom level
  static const double defaultZoom = 17.0;

  /// Default map center (Munich, Germany area)
  static const double defaultLatitude = 48.079994;
  static const double defaultLongitude = 11.634511;

  /// Get the default tile server URL
  static String get defaultTileUrl => osmTileServers[defaultTileServerIndex];

  /// Get a specific tile server URL by index
  static String getTileUrl(int index) {
    if (index >= 0 && index < osmTileServers.length) {
      return osmTileServers[index];
    }
    return defaultTileUrl;
  }

  /// Instructions for compliance with OSM tile usage policy
  static const String complianceNotes = '''
  IMPORTANT: To comply with OpenStreetMap tile usage policy:
  
  1. Update the contact email in the userAgent string above with your actual contact information
  2. Consider implementing:
     - Tile caching to reduce server requests
     - Rate limiting for tile requests
     - Fallback to alternative tile providers
  3. For production use, consider:
     - Using commercial tile providers for high-volume applications
     - Setting up your own tile server
     - Using vector tiles instead of raster tiles
  
  For more information, see: https://operations.osmfoundation.org/policies/tiles/
  ''';
}
