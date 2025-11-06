import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/ui/widgets/status_tab/platform_status_card.dart';
import 'package:augur/ui/widgets/status_tab/system_status_card.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/state/ros_provider.dart';

class StatusTabPage extends ConsumerStatefulWidget {
  const StatusTabPage({super.key});

  @override
  ConsumerState<StatusTabPage> createState() => _StatusTabPageState();
}

class _StatusTabPageState extends ConsumerState<StatusTabPage> {
  @override
  Widget build(BuildContext context) {
    final platformsData = ref.watch(platformDataProvider);
    final rosConnectionStatus = ref.watch(rosConnectionStatusProvider);
    final redisConnectionStatus = ref.watch(redisClientProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System Status Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings_system_daydream,
                            color: AppColors.primary, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'System Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SystemStatusCard(
                      rosConnected: rosConnectionStatus,
                      redisConnected: redisConnectionStatus != null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Platforms Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flight, color: AppColors.primary, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Connected Platforms',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    platformsData.when(
                      data: (platforms) {
                        if (platforms.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.flight_takeoff,
                                      size: 48, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No platforms connected',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: platforms.map((platform) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PlatformStatusCard(
                                platformId: platform.platformId,
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, stackTrace) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(Icons.error,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading platforms: $error',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
