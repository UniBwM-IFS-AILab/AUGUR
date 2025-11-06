import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/core/classes/platform.dart';

class PlatformListDrawer extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final Function(String) onPlatformSelected;
  final bool shouldClose; // New parameter to trigger close from parent

  const PlatformListDrawer({
    super.key,
    required this.onClose,
    required this.onPlatformSelected,
    this.shouldClose = false,
  });

  @override
  ConsumerState<PlatformListDrawer> createState() => _PlatformListDrawerState();
}

class _PlatformListDrawerState extends ConsumerState<PlatformListDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _scrollController = ScrollController();

    _animationController.forward();
  }

  @override
  void didUpdateWidget(PlatformListDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle external close request
    if (widget.shouldClose && !oldWidget.shouldClose) {
      _handleClose();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      widget.onClose();
    });
  }

  void _handlePlatformSelected(String platformId) {
    _animationController.reverse().then((_) {
      widget.onPlatformSelected(platformId);
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final platformsAsync = ref.watch(platformDataProvider);
    final redisClient = ref.watch(redisClientProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.22;

    return platformsAsync.when(
      data: (platforms) => Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: drawerWidth,
        child: SlideTransition(
          position: _slideAnimation,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Material(
              elevation: 16,
              shadowColor: Colors.black.withAlpha(77),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 10,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(26),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.flight,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Platforms',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _handleClose,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            splashRadius: 20,
                            tooltip: 'Close',
                            padding: const EdgeInsets.all(8),
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Platform List
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (redisClient == null) {
                            return _buildOfflineMessage();
                          }

                          if (platforms.isEmpty) {
                            return _buildEmptyState();
                          }

                          // Simple ListView without explicit Scrollbar to avoid controller issues
                          return ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: platforms.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final platform = platforms[index];
                              return _buildPlatformButton(platform);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ), // Container closing
            ), // Material closing
          ), // ClipRRect closing
        ), // SlideTransition closing
      ), // Positioned closing
      loading: () => Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: drawerWidth,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: drawerWidth,
        child: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildPlatformButton(Platform platform) {
    // Determine status color based on platform status and battery
    Color statusColor = Colors.green;
    String statusText = 'Online';

    if (platform.batteryState != null) {
      if (platform.batteryState!.isCriticallyLow) {
        statusColor = Colors.red;
        statusText = 'Critical Battery';
      } else if (platform.batteryState!.isLow) {
        statusColor = Colors.orange;
        statusText = 'Low Battery';
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handlePlatformSelected(platform.platformId),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: platform.color.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.flight,
                  color: platform.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform.platformId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Team: ${platform.teamId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (platform.batteryState != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${platform.batteryState!.batteryLevelPercent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: platform.batteryState!.batteryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineMessage() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Offline Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Platform list is not available in offline mode',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No Platforms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No platforms are currently connected',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
