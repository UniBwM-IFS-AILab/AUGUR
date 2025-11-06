import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/app_colors.dart';
import 'camera_stream_widget.dart';
import 'package:augur/state/ros_provider.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/core/classes/platform.dart';

class PlatformInfoDrawer extends ConsumerStatefulWidget {
  final Platform
      platform; // Changed to accept Platform object instead of separate parameters
  final VoidCallback onClose;
  final Function(SharedCameraStreamController?, bool) onToggleFullscreen;
  final Function(SharedCameraStreamController) onCameraControllerCreated;
  final bool isFullscreen;

  const PlatformInfoDrawer({
    super.key,
    required this.platform,
    required this.onClose,
    required this.onToggleFullscreen,
    required this.onCameraControllerCreated,
    required this.isFullscreen,
  });

  @override
  ConsumerState<PlatformInfoDrawer> createState() => _PlatformInfoDrawerState();
}

class _PlatformInfoDrawerState extends ConsumerState<PlatformInfoDrawer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late SharedCameraStreamController _cameraController;
  bool _ownershipTransferred = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    // Initialize camera controller
    _cameraController = SharedCameraStreamController(
      platformId: widget.platform.platformId,
      platformIp: widget.platform.platformIp,
    );

    // Transfer ownership to parent immediately
    widget.onCameraControllerCreated(_cameraController);
    _ownershipTransferred = true;

    _animationController.forward();
    
    // Auto-connect when drawer opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cameraController.connect();
      }
    });
  }

  @override
  void dispose() {
    // Only dispose camera controller if ownership wasn't transferred to fullscreen
    if (!_ownershipTransferred) {
      // Add a small delay to allow GL context to properly clean up
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          _cameraController.dispose();
        } catch (e) {
          debugPrint('⚠️ Error disposing camera controller: $e');
        }
      });
    }
    _animationController.dispose();
    super.dispose();
  }

  void _handleClose() async {
    await _animationController.reverse();
    widget.onClose();
  }
  void _executeCommand(String command) {
    final rosClient = ref.read(rosClientProvider);

    if (rosClient != null && rosClient.isConnected()) {
      try {
        int commandType;
        switch (command) {
          case 'Cancel':
            commandType = 11;
            break;
          case 'RTH+Land':
            commandType = 18;
            break;
          case 'Kill':
            commandType = 20;
            break;
          default:
            throw Exception('Unknown command: $command');
        }

        Map<String, dynamic> userCommand = {
          'user_command': commandType,
          'team_id': widget.platform.teamId,
          'platform_id': widget.platform.platformId,
        };

        rosClient.publish(
          topicName: 'planner_command',
          messageType: 'auspex_msgs/UserCommand',
          message: userCommand,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('$command command sent to ${widget.platform.platformId}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending command: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ROS connection not available'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth =
        screenWidth * 0.4; // Increased to 40% for better usability

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: drawerWidth,
      child: IgnorePointer(
        ignoring: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              elevation: 20,
              shadowColor: Colors.black.withAlpha(77), // 0.3 * 255 = 77
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51), // 0.2 * 255 = 51
                      blurRadius: 12,
                      offset: const Offset(-4, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Modern Header - only rebuild when platform ID changes
                    _buildHeader(),

                    // Camera Stream Section with Modern Design
                    _buildCameraSection(),

                    // Platform Information and Commands Section - with targeted updates
                    _buildInfoAndCommandsSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withAlpha(204) // 0.8 * 255 = 204
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26), // 0.1 * 255 = 26
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51), // 0.2 * 255 = 51
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flight, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.platform.platformId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Active Platform',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleClose,
            icon: const Icon(Icons.close, color: Colors.white),
            iconSize: 22,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(51), // 0.2 * 255 = 51
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Expanded(
      flex: 3,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26), // 0.1 * 255 = 26
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Camera stream
              Positioned.fill(
                child: SharedCameraStreamWidget(
                  controller: _cameraController,
                  isFullscreen: false,
                ),
              ),

              // Modern Control Overlay
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(179), // 0.7 * 255 = 179
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          _ownershipTransferred = true;
                          widget.onToggleFullscreen(_cameraController, true);
                        },
                        icon: Icon(
                          widget.isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: widget.isFullscreen
                            ? 'Exit Fullscreen'
                            : 'Fullscreen',
                      ),
                    ],
                  ),
                ),
              ),

              // Stream Status Indicator
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(230), // 0.9 * 255 = 230
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoAndCommandsSection() {
    return Expanded(
      flex: 2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform Information - each section will handle its own updates
            _buildInfoSection('Status', Icons.info_outline),
            const SizedBox(height: 16),
            _buildInfoSection('Battery', Icons.battery_std),
            const SizedBox(height: 16),
            _buildInfoSection('Position', Icons.location_on),
            const SizedBox(height: 16),
            _buildInfoSection('Mission', Icons.assignment),
            const SizedBox(height: 24),

            // Platform Commands Section
            _buildCommandsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.control_camera, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Platform Commands',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Standard Commands Row
        Row(
          children: [
            Expanded(
              child: _buildCommandButton(
                'Cancel',
                Icons.cancel,
                Colors.orange,
                () => _confirmCancelPlatform(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCommandButton(
                'RTH+Land',
                Icons.home,
                Colors.blue,
                () => _confirmRthPlatform(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildCommandButton(
                'Kill',
                Icons.power_settings_new,
                Colors.red,
                () => _confirmKillPlatform(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmKillPlatform() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm KILL Command'),
        content: Text(
          'Do you really want to KILL drone ${widget.platform.platformId}? This may lead to fatal damage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[800], // Text color
              backgroundColor: Colors.grey[200], // Button background
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.black87, // Text color
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('YES, KILL'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeCommand('Kill');
    }
  }

  Future<void> _confirmCancelPlatform() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Cancel Command'),
        content: Text(
          'Do you want to cancel the current mission for drone ${widget.platform.platformId}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[800],
              backgroundColor: Colors.grey[200],
            ),
            child: const Text(
              'No',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('YES, CANCEL'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeCommand('Cancel');
    }
  }

  Future<void> _confirmRthPlatform() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Return Home Command'),
        content: Text(
          'Do you want drone ${widget.platform.platformId} to return home and land?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[800],
              backgroundColor: Colors.grey[200],
            ),
            child: const Text(
              'No',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('YES, RTH+LAND'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeCommand('RTH+Land');
    }
  }

  Widget _buildCommandButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: color,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _buildInfoContent(title),
        ),
      ],
    );
  }

  Widget _buildInfoContent(String section) {
    switch (section) {
      case 'Status':
        return _PlatformStatusWidget(
            platformId: widget.platform.platformId,
            fallbackPlatform: widget.platform);
      case 'Battery':
        return _PlatformBatteryWidget(
            platformId: widget.platform.platformId,
            fallbackPlatform: widget.platform);
      case 'Position':
        return _PlatformPositionWidget(
            platformId: widget.platform.platformId,
            fallbackPlatform: widget.platform);
      case 'Mission':
        return _PlatformMissionWidget(platformId: widget.platform.platformId);
      default:
        return const Text('N/A', style: TextStyle(fontSize: 12));
    }
  }
}

// Individual widget classes for each section to prevent full drawer rebuilds
class _PlatformStatusWidget extends StatefulWidget {
  final String platformId;
  final Platform fallbackPlatform;

  const _PlatformStatusWidget(
      {required this.platformId, required this.fallbackPlatform});

  @override
  State<_PlatformStatusWidget> createState() => _PlatformStatusWidgetState();
}

class _PlatformStatusWidgetState extends State<_PlatformStatusWidget> {
  Platform? _currentPlatform;

  @override
  void initState() {
    super.initState();
    _currentPlatform = widget.fallbackPlatform;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final platformsAsync = ref.watch(platformDataProvider);

        platformsAsync.whenData((platforms) {
          final updatedPlatform = platforms.firstWhere(
            (p) => p.platformId == widget.platformId,
            orElse: () => widget.fallbackPlatform,
          );

          // Only setState if the status actually changed
          if (_currentPlatform?.status != updatedPlatform.status) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentPlatform = updatedPlatform;
                });
              }
            });
          }
        });

        final platform = _currentPlatform ?? widget.fallbackPlatform;

        return Row(
          children: [
            Icon(
              platform.status.toUpperCase() == 'ACTIVE' ||
                      platform.status.toUpperCase() == 'FLYING' ||
                      platform.status.toUpperCase() == 'RUNNING'
                  ? Icons.check_circle
                  : platform.status.toUpperCase() == 'DISCONNECTED'
                      ? Icons.error
                      : Icons.radio_button_unchecked,
              color: platform.status.toUpperCase() == 'ACTIVE' ||
                      platform.status.toUpperCase() == 'FLYING' ||
                      platform.status.toUpperCase() == 'RUNNING'
                  ? Colors.green
                  : platform.status.toUpperCase() == 'DISCONNECTED'
                      ? Colors.red
                      : Colors.orange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              platform.status,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}

class _PlatformBatteryWidget extends StatefulWidget {
  final String platformId;
  final Platform fallbackPlatform;

  const _PlatformBatteryWidget(
      {required this.platformId, required this.fallbackPlatform});

  @override
  State<_PlatformBatteryWidget> createState() => _PlatformBatteryWidgetState();
}

class _PlatformBatteryWidgetState extends State<_PlatformBatteryWidget> {
  Platform? _currentPlatform;

  @override
  void initState() {
    super.initState();
    _currentPlatform = widget.fallbackPlatform;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final platformsAsync = ref.watch(platformDataProvider);

        platformsAsync.whenData((platforms) {
          final updatedPlatform = platforms.firstWhere(
            (p) => p.platformId == widget.platformId,
            orElse: () => widget.fallbackPlatform,
          );

          // Only setState if the battery data actually changed
          if (_currentPlatform?.batteryState?.percentage !=
                  updatedPlatform.batteryState?.percentage ||
              _currentPlatform?.batteryState?.voltage !=
                  updatedPlatform.batteryState?.voltage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentPlatform = updatedPlatform;
                });
              }
            });
          }
        });

        final platform = _currentPlatform ?? widget.fallbackPlatform;

        if (platform.batteryState != null) {
          final battery = platform.batteryState!;
          return Row(
            children: [
              _buildBatteryIcon((battery.percentage * 100).round()),
              const SizedBox(width: 8),
              Text(
                '${battery.batteryLevelPercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: battery.batteryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${battery.voltage.toStringAsFixed(1)}V)',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          );
        } else {
          return const Row(
            children: [
              Icon(Icons.battery_unknown, color: Colors.grey, size: 16),
              SizedBox(width: 8),
              Text('No data',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          );
        }
      },
    );
  }

  Widget _buildBatteryIcon(int percentage) {
    Color batteryColor;
    if (percentage > 50) {
      batteryColor = Colors.green;
    } else if (percentage > 25) {
      batteryColor = Colors.orange;
    } else {
      batteryColor = Colors.red;
    }

    return SizedBox(
      width: 20,
      height: 12,
      child: Stack(
        children: [
          // Battery outline
          Container(
            width: 18,
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[600]!, width: 1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Battery positive terminal
          Positioned(
            right: -1,
            top: 3,
            child: Container(
              width: 2,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(1),
                  bottomRight: Radius.circular(1),
                ),
              ),
            ),
          ),
          // Battery fill
          Positioned(
            left: 1,
            top: 1,
            child: Container(
              width: (16 * percentage / 100).clamp(0.0, 16.0),
              height: 10,
              decoration: BoxDecoration(
                color: batteryColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformPositionWidget extends StatefulWidget {
  final String platformId;
  final Platform fallbackPlatform;

  const _PlatformPositionWidget(
      {required this.platformId, required this.fallbackPlatform});

  @override
  State<_PlatformPositionWidget> createState() =>
      _PlatformPositionWidgetState();
}

class _PlatformPositionWidgetState extends State<_PlatformPositionWidget> {
  Platform? _currentPlatform;

  @override
  void initState() {
    super.initState();
    _currentPlatform = widget.fallbackPlatform;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final platformsAsync = ref.watch(platformDataProvider);

        platformsAsync.whenData((platforms) {
          final updatedPlatform = platforms.firstWhere(
            (p) => p.platformId == widget.platformId,
            orElse: () => widget.fallbackPlatform,
          );

          // Only setState if the position actually changed (with some tolerance for GPS drift)
          const tolerance = 0.000001; // About 10cm at the equator
          if (_currentPlatform?.gpsPosition.latitude == null ||
              (_currentPlatform!.gpsPosition.latitude -
                          updatedPlatform.gpsPosition.latitude)
                      .abs() >
                  tolerance ||
              (_currentPlatform!.gpsPosition.longitude -
                          updatedPlatform.gpsPosition.longitude)
                      .abs() >
                  tolerance) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentPlatform = updatedPlatform;
                });
              }
            });
          }
        });

        final platform = _currentPlatform ?? widget.fallbackPlatform;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lat: ${platform.gpsPosition.latitude.toStringAsFixed(6)}°',
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              'Lon: ${platform.gpsPosition.longitude.toStringAsFixed(6)}°',
              style: const TextStyle(fontSize: 11),
            ),
            if (platform.pose['position'] != null)
              Text(
                'Alt: ${_getAltitudeString(platform.pose['position']['z'])}m',
                style: const TextStyle(fontSize: 11),
              ),
          ],
        );
      },
    );
  }

  String _getAltitudeString(dynamic altitudeValue) {
    if (altitudeValue == null) return '0.0';
    double altitude = double.tryParse(altitudeValue) ?? 0.0;
    // Negate the altitude (z-axis is typically negative for height above ground)
    return (-altitude).toStringAsFixed(1);
  }
}

class _PlatformMissionWidget extends StatefulWidget {
  final String platformId;

  const _PlatformMissionWidget({required this.platformId});

  @override
  State<_PlatformMissionWidget> createState() => _PlatformMissionWidgetState();
}

class _PlatformMissionWidgetState extends State<_PlatformMissionWidget> {
  List<dynamic>? _currentPlans;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final plansAsync = ref.watch(planStreamProvider);

        plansAsync.whenData((plans) {
          // Filter plans for this platform
          final platformPlans = plans
              .where((plan) => plan.platformId == widget.platformId)
              .toList();

          // Only setState if the plans actually changed
          if (_plansChanged(_currentPlans, platformPlans)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentPlans = platformPlans;
                });
              }
            });
          }
        });

        final platformPlans = _currentPlans ?? [];

        if (platformPlans.isEmpty) {
          return const Text(
            'No missions assigned',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          );
        }

        // Show active plan first, then others
        final sortedPlans = List.from(platformPlans);
        sortedPlans.sort((a, b) {
          // Active/running plans first
          if (a.status.name.toUpperCase() == 'ACTIVE' &&
              b.status.name.toUpperCase() != 'ACTIVE'){
                return -1;
          }
          if (b.status.name.toUpperCase() == 'ACTIVE' &&
              a.status.name.toUpperCase() != 'ACTIVE'){
                return 1;
          }

          // Then by priority (higher first)
          return b.priority.compareTo(a.priority);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < sortedPlans.length && i < 3; i++) ...[
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getPlanStatusColor(sortedPlans[i].status.name),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Plan ${sortedPlans[i].planId} (${sortedPlans[i].status.name})',
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (i < sortedPlans.length - 1 && i < 2)
                const SizedBox(height: 2),
            ],
            if (sortedPlans.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+${sortedPlans.length - 3} more',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _plansChanged(List<dynamic>? oldPlans, List<dynamic> newPlans) {
    if (oldPlans == null) return true;
    if (oldPlans.length != newPlans.length) return true;

    for (int i = 0; i < oldPlans.length; i++) {
      if (oldPlans[i].planId != newPlans[i].planId ||
          oldPlans[i].status.name != newPlans[i].status.name ||
          oldPlans[i].priority != newPlans[i].priority) {
        return true;
      }
    }
    return false;
  }

  Color _getPlanStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'RUNNING':
        return Colors.green;
      case 'INACTIVE':
        return Colors.grey;
      case 'PENDING':
      case 'WAITING':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.blue;
      case 'FAILED':
      case 'ERROR':
      case 'ABORTED':
        return Colors.red;
      case 'CANCELED':
      case 'CANCELLED':
        return Colors.orange.shade700;
      case 'PAUSED':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
