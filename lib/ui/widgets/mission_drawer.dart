import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/state/ros_provider.dart';
import 'package:augur/core/classes/mission.dart';

class MissionDrawer extends ConsumerStatefulWidget {
  final bool isVisible;
  final Mission? missionData;
  final VoidCallback onClose;
  final VoidCallback? onMissionDeleted;

  const MissionDrawer({
    super.key,
    required this.isVisible,
    required this.missionData,
    required this.onClose,
    this.onMissionDeleted,
  });

  @override
  ConsumerState<MissionDrawer> createState() => MissionDrawerState();
}

class MissionDrawerState extends ConsumerState<MissionDrawer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.isVisible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(MissionDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Stack(
      children: [
        // Drawer content
        SlideTransition(
          position: _slideAnimation,
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                // Prevent tap events from propagating to the map
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.3,
                height: MediaQuery.of(context).size.height,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(-5, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildContent()),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.assignment,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mission Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.missionData != null)
                  Text(
                    'Team: ${widget.missionData!.teamId}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.missionData == null) {
      return const Center(
        child: Text(
          'No mission data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildInfoSection(widget.missionData!),
    );
  }

  Widget _buildInfoSection(Mission mission) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Information
        _buildSectionTitle('Basic Information'),
        _buildInfoRow(
          label: 'Team ID',
          value: mission.teamId,
          valueColor: AppColors.primary,
        ),
        _buildInfoRow(
          label: 'Platform Class',
          value: mission.platformClass.name,
        ),
        _buildInfoRow(
          label: 'Mission Goal',
          value: mission.missionGoal.isNotEmpty
              ? mission.missionGoal
              : 'Not specified',
        ),
        _buildInfoRow(
          label: 'Sensor Mode',
          value: mission.sensorMode.name,
        ),

        const SizedBox(height: 20),

        // Flight Parameters
        _buildSectionTitle('Flight Parameters'),
        _buildInfoRow(
          label: 'Max Height',
          value: '${mission.maxHeight} m AGL',
        ),
        _buildInfoRow(
          label: 'Min Height',
          value: '${mission.minHeight} m AGL',
        ),
        _buildInfoRow(
          label: 'Ground Distance',
          value: '${mission.desiredGroundDistance} m',
        ),
        _buildInfoRow(
          label: 'Starting Point',
          value:
              '${mission.startingPoint.latitude.toStringAsFixed(6)}, ${mission.startingPoint.longitude.toStringAsFixed(6)}',
        ),

        const SizedBox(height: 20),

        // Target Objects
        if (mission.targetObjects.isNotEmpty) ...[
          _buildSectionTitle('Target Objects'),
          ...mission.targetObjects.map((obj) => _buildInfoRow(
                label: '•',
                value: obj,
              )),
          const SizedBox(height: 20),
        ],

        // Areas Information
        _buildSectionTitle('Areas'),
        if (mission.searchAreas.isNotEmpty) ...[
          _buildInfoRow(
            label: 'Search Areas',
            value: mission.searchAreas.length == 1
                ? (mission.searchAreas.first.description.isNotEmpty
                    ? mission.searchAreas.first.description
                    : 'Main search area')
                : '${mission.searchAreas.length} search area(s)',
            valueColor: mission.searchAreas.first.type.borderColor,
          ),
        ],
        if (mission.noFlyZones.isNotEmpty) ...[
          _buildInfoRow(
            label: 'No-Fly Zones',
            value: '${mission.noFlyZones.length} zone(s)',
            valueColor: Colors.red,
          ),
        ],
        if (mission.priorityAreas.isNotEmpty) ...[
          _buildInfoRow(
            label: 'Priority Areas',
            value: '${mission.priorityAreas.length} area(s)',
            valueColor: Colors.green,
          ),
        ],
        if (mission.dangerZones.isNotEmpty) ...[
          _buildInfoRow(
            label: 'Danger Zones',
            value: '${mission.dangerZones.length} zone(s)',
            valueColor: Colors.orange,
          ),
        ],

        const SizedBox(height: 20),

        // Points of Interest
        if (mission.pois.isNotEmpty) ...[
          _buildSectionTitle('Points of Interest'),
          ...mission.pois.asMap().entries.map((entry) => _buildInfoRow(
                label: 'POI ${entry.key + 1}',
                value:
                    '${entry.value.latitude.toStringAsFixed(6)}, ${entry.value.longitude.toStringAsFixed(6)}',
              )),
          const SizedBox(height: 20),
        ],

        // Action Buttons
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        const Divider(height: 40),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Plan',
                icon: Icons.route,
                color: Colors.blue,
                onPressed: _planMission,
                enabled: _isPlanButtonEnabled(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                label: 'Execute',
                icon: Icons.play_arrow,
                color: Colors.green,
                onPressed: _executeMission,
                enabled: _isExecuteButtonEnabled(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: 'Delete Mission',
          icon: Icons.delete,
          color: Colors.red,
          onPressed: _deleteMission,
          enabled: _isDeleteButtonEnabled(),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey,
          foregroundColor: Colors.white,
          elevation: enabled ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mission areas are displayed on the map with different colors',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isDeleteButtonEnabled() {
    return widget.missionData != null;
  }

  bool _isPlanButtonEnabled() {
    return widget.missionData != null;
  }

  bool _isExecuteButtonEnabled() {
    return widget.missionData != null;
  }

  void _planMission() async {
    if (widget.missionData == null) return;

    final rosClient = ref.read(rosClientProvider);
    if (rosClient == null || !rosClient.isConnected()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ROS client not connected'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      String teamId = widget.missionData!.teamId;

      // Create UserCommand message for planning
      Map<String, dynamic> userCommand = {
        'user_command': 7, // USER_PLAN_TEAM
        'team_id': teamId,
        'platform_id': '',
      };

      // Publish to planner_command topic
      rosClient.publish(
        topicName: '/planner_command',
        messageType: 'auspex_msgs/UserCommand',
        message: userCommand,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan command sent for team $teamId'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending plan command: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _executeMission() async {
    if (widget.missionData == null) return;

    final rosClient = ref.read(rosClientProvider);
    if (rosClient == null || !rosClient.isConnected()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ROS client not connected'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      String teamId = widget.missionData!.teamId;

      Map<String, dynamic> userCommand = {
        'user_command': 5, // USER_ACCEPT_TEAM
        'team_id': teamId,
        'platform_id': '',
      };

      // Publish to planner_command topic
      rosClient.publish(
        topicName: '/planner_command',
        messageType: 'auspex_msgs/UserCommand',
        message: userCommand,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Execute command sent for team $teamId'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending execute command: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteMission() async {
    if (widget.missionData == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mission'),
        content: Text(
          'Are you sure you want to delete the mission for team "${widget.missionData!.teamId}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final redisProvider = ref.read(redisClientProvider.notifier);
        final success =
            await redisProvider.deleteMission(widget.missionData!.teamId);

        if (success && mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Mission for team "${widget.missionData!.teamId}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Close drawer and notify parent
          widget.onClose();
          widget.onMissionDeleted?.call();
        } else if (mounted) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete mission. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting mission: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
