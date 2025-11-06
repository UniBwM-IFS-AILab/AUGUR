import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class SharedCameraStreamController extends ChangeNotifier {
  final String platformId;
  final String platformIp;
  
  late final Player _player;
  late final VideoController _videoController;
  
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _errorMessage;
  bool _disposed = false;
  
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;
  VideoController get videoController => _videoController;
  
  SharedCameraStreamController({
    required this.platformId,
    required this.platformIp,
  }) {
    _player = Player();
    _videoController = VideoController(_player);
  }
  
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }
  
  String _buildRtspUrl() {
    String serverIp = platformIp;
    int port = 8554; // Default RTSP port
    
    if (serverIp == '0.0.0.0' || serverIp.isEmpty) {
      serverIp = '127.0.0.1';
    }
    
    // For localhost IPs, add platform number as port offset
    if (platformId.contains('simulation')) {
      final match = RegExp(r'(\d+)').firstMatch(platformId);
      if (match != null) {
        final platformNumber = int.tryParse(match.group(1)!) ?? 0;
        port = 8554 + platformNumber;
      }
    }
    
    return 'rtsp://$serverIp:$port/$platformId/stream/color';
  }
  
  Future<void> connect() async {
    if (_disposed || _isConnecting || _isConnected) return;
    
    _isConnecting = true;
    _errorMessage = null;
    _safeNotifyListeners();
    
    try {
      final rtspUrl = _buildRtspUrl();
      debugPrint('Connecting to RTSP: $rtspUrl');
      
      await _player.open(Media(rtspUrl));
      await _player.setVolume(0.0); // Mute surveillance stream
      
      if (!_disposed) {
        _isConnected = true;
        _isConnecting = false;
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to connect to RTSP stream: $e');
      if (!_disposed) {
        _isConnecting = false;
        _errorMessage = e.toString();
        _safeNotifyListeners();
      }
    }
  }
  
  Future<void> disconnect() async {
    if (_disposed || (!_isConnected && !_isConnecting)) return;
    
    debugPrint('Disconnecting from RTSP stream');
    
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Error stopping player: $e');
    }
    
    if (!_disposed) {
      _isConnected = false;
      _isConnecting = false;
      _errorMessage = null;
      _safeNotifyListeners();
    }
  }
  
  Future<void> retry() async {
    if (_disposed) return;
    
    await disconnect();
    if (!_disposed) {
      await Future.delayed(const Duration(milliseconds: 500));
      await connect();
    }
  }
  
  @override
  void dispose() {
    if (_disposed) return;
    
    _disposed = true;
    
    // First disconnect gracefully
    try {
      _isConnected = false;
      _isConnecting = false;
      _errorMessage = null;
      
      // Stop the player asynchronously but don't wait
      _player.stop().catchError((e) {
        debugPrint('⚠️ Error stopping player during dispose: $e');
      });
    } catch (e) {
      debugPrint('⚠️ Error during player stop: $e');
    }
    
    // Dispose the player with a small delay to allow GL context cleanup
    Future.delayed(const Duration(milliseconds: 50), () {
      try {
        _player.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing player: $e');
      }
    });
    
    super.dispose();
  }
}

class SharedCameraStreamWidget extends StatelessWidget {
  final SharedCameraStreamController controller;
  final bool isFullscreen;
  
  const SharedCameraStreamWidget({
    super.key,
    required this.controller,
    this.isFullscreen = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        // No platform info
        if (controller.platformId.isEmpty || controller.platformIp.isEmpty) {
          return const Center(
            child: Text(
              "No platform selected",
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        // Error state
        if (controller.errorMessage != null && !controller.isConnecting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    controller.errorMessage!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: controller.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // Connecting state
        if (controller.isConnecting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Connecting to stream...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        // Disconnected state
        if (!controller.isConnected) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, color: Colors.white70, size: 48),
                SizedBox(height: 16),
                Text(
                  'Camera stream disconnected',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        // Connected state - show video
        return Container(
          color: Colors.black,
          child: Video(
            controller: controller.videoController,
            fit: isFullscreen ? BoxFit.contain : BoxFit.contain, // Always use contain to show black padding
            controls: NoVideoControls,
          ),
        );
      },
    );
  }
}