import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/state/ros_provider.dart';

class PlatformStatusCard extends ConsumerWidget {
  final String platformId;

  const PlatformStatusCard({
    super.key,
    required this.platformId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Watch actual platform status from providers
    final isConnected = ref.watch(rosConnectionStatusProvider);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.flight,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platformId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isConnected ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isConnected ? 'Connected' : 'Disconnected',
                            style: TextStyle(
                              fontSize: 12,
                              color: isConnected ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor('Active').withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor('Active'),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Status Details Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    'Battery',
                    '85%',
                    Icons.battery_std,
                    Colors.green,
                    customWidget: _buildBatteryIndicator(85),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatusItem(
                    'Altitude',
                    '120m',
                    Icons.height,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    'Speed',
                    '12 m/s',
                    Icons.speed,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatusItem(
                    'Signal',
                    'Strong',
                    Icons.signal_cellular_alt,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Location
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Position',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Lat: 34.0522°  Lon: -118.2437°',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Current Mission
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(13),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withAlpha(51)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Current Mission',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Patrol Route A - Waypoint 3/7',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    Widget? customWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              if (customWidget != null)
                customWidget
              else
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIndicator(int percentage) {
    Color batteryColor;
    if (percentage > 50) {
      batteryColor = Colors.green;
    } else if (percentage > 25) {
      batteryColor = Colors.orange;
    } else {
      batteryColor = Colors.red;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 8,
          child: Stack(
            children: [
              // Battery outline
              Container(
                width: 14,
                height: 8,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[600]!, width: 0.8),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              // Battery positive terminal
              Positioned(
                right: -0.8,
                top: 2,
                child: Container(
                  width: 1.6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(0.5),
                      bottomRight: Radius.circular(0.5),
                    ),
                  ),
                ),
              ),
              // Battery fill
              Positioned(
                left: 0.8,
                top: 0.8,
                child: Container(
                  width: (12.4 * percentage / 100).clamp(0.0, 12.4),
                  height: 6.4,
                  decoration: BoxDecoration(
                    color: batteryColor,
                    borderRadius: BorderRadius.circular(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: batteryColor,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'online':
        return Colors.green;
      case 'idle':
      case 'standby':
        return Colors.orange;
      case 'offline':
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
