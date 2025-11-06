import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/ui/pages/map_tab_page.dart';
import 'package:augur/ui/pages/waypoints_tab_page.dart';
import 'package:augur/ui/pages/status_tab_page.dart';
import 'package:augur/ui/pages/settings_tab_page.dart';
import 'package:augur/ui/pages/mission_tab_page.dart';
import 'package:augur/ui/widgets/utility_widgets/connection_lost_dialog.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/state/ros_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  final String ipAddress;

  const AppShell({super.key, required this.ipAddress});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _ipController;
  bool isOffline = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _ipController = TextEditingController(text: widget.ipAddress);

    // Initialize providers with connection lost callback
    Future.microtask(() async {
      debugPrint("AppShell: Initializing providers with IP: ${widget.ipAddress}");

      // Initialize Redis provider
      ref.read(redisClientProvider.notifier).initialize(
            widget.ipAddress,
            showConnectionLostDialog,
          );

      // Initialize ROS provider
      ref.read(rosClientProvider.notifier).initialize(
            'ws://${widget.ipAddress}:9090',
            showConnectionLostDialog,
          );

      // Connect to both providers
      try {
        debugPrint("AppShell: Attempting to connect to Redis and ROS...");
        await ref.read(redisClientProvider.notifier).connect();
        await ref.read(rosClientProvider.notifier).connect();
        debugPrint("AppShell: Successfully connected to both Redis and ROS");
      } catch (e) {
        // Connection failed, show dialog
        debugPrint("AppShell: Connection failed during initialization: $e");
        showConnectionLostDialog();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  void showConnectionLostDialog() async {
    debugPrint("AppShell: showConnectionLostDialog called");
    if (!mounted) {
      debugPrint("AppShell: Widget not mounted, skipping dialog");
      return;
    }

    // Disconnect from providers
    await ref.read(redisClientProvider.notifier).disconnect();
    await ref.read(rosClientProvider.notifier).disconnect();

    debugPrint("AppShell: Showing connection lost dialog");
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ConnectionLostDialog(
          ipController: _ipController,
          onReconnect: () async {
            try {
              final newIp = _ipController.text.trim();

              // Re-initialize providers with new IP if changed
              if (newIp != widget.ipAddress) {
                // Dispose old providers
                await ref.read(redisClientProvider.notifier).disconnect();
                await ref.read(rosClientProvider.notifier).disconnect();

                // Initialize with new IP
                ref.read(redisClientProvider.notifier).initialize(
                      newIp,
                      showConnectionLostDialog,
                    );
                ref.read(rosClientProvider.notifier).initialize(
                      'ws://$newIp:9090',
                      showConnectionLostDialog,
                    );
              }

              // Attempt to connect
              await ref.read(redisClientProvider.notifier).connect();
              await ref.read(rosClientProvider.notifier).connect();

              // If we get here, connection was successful
              setState(() => isOffline = false);
              return true;
            } catch (e) {
              // Connection failed
              return false;
            }
          },
          onOffline: () {
            setState(() => isOffline = true);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withAlpha(190), AppColors.primary.withAlpha(190)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(38),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Modern Tab Bar
                Container(
                  height: 50,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(4),
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white.withAlpha(204),
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerHeight: 0,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.map_outlined, size: 18),
                        text: 'Map',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                      Tab(
                        icon: Icon(Icons.route_outlined, size: 18),
                        text: 'Waypoints',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                      Tab(
                        icon: Icon(Icons.search_outlined, size: 18),
                        text: 'Plan Mission',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                      Tab(
                        icon: Icon(Icons.analytics_outlined, size: 18),
                        text: 'Status',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                      Tab(
                        icon: Icon(Icons.settings_outlined, size: 18),
                        text: 'Settings',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[50]!, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                MapTabPage(),
                WaypointsTabPage(),
                MissionTabPage(),
                StatusTabPage(),
                SettingsTabPage(),
              ],
            ),
          ),
          // Offline status button in bottom left corner
          if (isOffline)
            Positioned(
              bottom: 20,
              left: 20,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary,
                        AppColors.secondary.withAlpha(204)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withAlpha(77),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => isOffline = false);
                      showConnectionLostDialog();
                    },
                    icon: const Icon(Icons.wifi_off,
                        color: Colors.white, size: 20),
                    label: const Text(
                      'Offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
