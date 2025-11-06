# OpenStreetMap Tile Configuration

This document explains the changes made to fix the OpenStreetMap tile access issue and ensure compliance with OSM's tile usage policy.

## What was the problem?

The app was being blocked by OpenStreetMap's tile servers due to not following their tile usage policy. The error "access blocked" indicates that the app was not properly identifying itself or was making too many requests to the volunteer-run OSM servers.

## What was fixed?

### 1. Alternative Tile Servers
- **Before**: Used only the main OSM server (`tile.openstreetmap.org`)
- **After**: Uses alternative OSM-compatible servers to distribute load:
  - German OSM server (`tile.openstreetmap.de`) - Primary
  - Wikimedia OSM tiles (`tiles.wmflabs.org`)
  - French OSM server (`tile.openstreetmap.fr`)
  - Main OSM server as fallback

### 2. Proper User-Agent
- **Before**: Generic `com.example.app`
- **After**: Proper identification with `augur.flutter.app`

### 3. Centralized Configuration
- Created `lib/config/map_config.dart` for easy management
- All tile server settings are now in one place
- Easy to update contact information and tile sources

### 4. Error Handling
- Added tile loading error detection
- Option to automatically switch tile servers on errors
- Better debugging information

## Important: Update Contact Information

**You MUST update the contact email in `lib/config/map_config.dart`:**

```dart
static const String userAgent = 'AUGUR Flutter App/0.9.0 (contact: your-actual-email@domain.com)';
```

Replace `your-email@domain.com` with your actual contact email address. This is required by OSM's tile usage policy.

## How to test

1. Update the contact email in `map_config.dart`
2. Run the app: `flutter run`
3. Check if map tiles load properly
4. Monitor the console for any tile loading errors

## For production use

Consider these additional improvements:

1. **Use commercial tile providers** for high-volume applications:
   - Mapbox (already configured for satellite view)
   - MapTiler
   - Stamen

2. **Implement tile caching** to reduce server requests

3. **Set up your own tile server** for complete control

4. **Use vector tiles** instead of raster tiles for better performance

## Fallback mechanism

If one tile server is down or blocking requests, you can manually switch to another by uncommenting the automatic server switching in the error handler:

```dart
errorTileCallback: (tile, error, stackTrace) {
  print('Tile loading error: $error');
  _switchToNextTileServer(); // Uncomment this line
},
```

## Resources

- [OSM Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/)
- [Alternative Tile Servers](https://wiki.openstreetmap.org/wiki/Tile_servers)
- [Flutter Map Documentation](https://docs.fleaflet.dev/)
