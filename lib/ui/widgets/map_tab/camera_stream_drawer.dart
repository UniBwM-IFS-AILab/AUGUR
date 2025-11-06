import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/widgets/map_tab/camera_stream_widget.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/core/classes/platform.dart';
import 'package:latlong2/latlong.dart';

class CameraStreamDrawer extends ConsumerStatefulWidget {
  final String platformId;
  final bool isFullscreen;
  final VoidCallback onClose;
  final SharedCameraStreamController? cameraController;

  const CameraStreamDrawer({
    super.key,
    required this.platformId,
    required this.isFullscreen,
    required this.onClose,
    this.cameraController,
  });

  @override
  ConsumerState<CameraStreamDrawer> createState() => _CameraStreamDrawerState();
}

class _CameraStreamDrawerState extends ConsumerState<CameraStreamDrawer> {
  void _handleClose() {
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isFullscreen) return const SizedBox.shrink();

    // Get platform data to access the IP address
    final platformsAsync = ref.watch(platformDataProvider);

    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Fullscreen camera stream with black padding if needed
            Positioned.fill(
              child: platformsAsync.when(
                data: (platforms) {
                  // Find the platform by ID
                  final platform = platforms.firstWhere(
                    (p) => p.platformId == widget.platformId,
                    orElse: () => Platform(
                      platformId: widget.platformId,
                      platformIp: '',
                      teamId: '',
                      gpsPosition: const LatLng(0, 0),
                      pose: {},
                      yaw: 0,
                      status: 'unknown',
                      color: Colors.grey,
                    ),
                  );

                  if (platform.platformIp.isEmpty) {
                    return const Center(
                      child: Text(
                        'Platform IP not available',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  // Use shared controller if provided, otherwise create fallback
                  if (widget.cameraController != null) {
                    return SharedCameraStreamWidget(
                      controller: widget.cameraController!,
                      isFullscreen: true,
                    );
                  } else {
                    return const Center(
                      child: Text(
                        'No camera controller available',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (error, stack) => Center(
                  child: Text(
                    'Error loading platform data: $error',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),

            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(179),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      onPressed: _handleClose,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                      tooltip: 'Close Fullscreen',
                      splashRadius: 22,
                    ),
                  ),
                ),
              ),
            ),

            // Platform info overlay
            Positioned(
              top: 40,
              left: 20,
              child: SafeArea(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(179),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flight, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        widget.platformId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
