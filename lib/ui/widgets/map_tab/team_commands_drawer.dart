import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/state/ros_provider.dart';
import 'package:augur/state/redis_provider.dart';

class TeamCommandsDrawer extends ConsumerStatefulWidget {
  final bool isVisible;
  final VoidCallback onClose;

  const TeamCommandsDrawer({
    super.key,
    required this.isVisible,
    required this.onClose,
  });

  @override
  ConsumerState<TeamCommandsDrawer> createState() => _TeamCommandsDrawerState();
}

class _TeamCommandsDrawerState extends ConsumerState<TeamCommandsDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  String? _selectedTeamId;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0), // Start from left side
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start animation if initially visible
    if (widget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animationController.forward();
      });
    }
  }

  @override
  void didUpdateWidget(TeamCommandsDrawer oldWidget) {
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
    if (!widget.isVisible && !_animationController.isAnimating) {
      return const SizedBox.shrink();
    }

    // Compute responsive width: cap at 320, min 240 or 80% of screen width, whichever is smaller
    final screenWidth = MediaQuery.of(context).size.width;
    double targetWidth = 320;
    if (screenWidth < 360) {
      targetWidth = screenWidth * 0.8; // leave some margin
    } else if (screenWidth < 500) {
      targetWidth = 280;
    }
    targetWidth = targetWidth.clamp(240, 320);

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          // Close drawer when tapping outside
          widget.onClose();
        },
        child: Stack(
          children: [
            // Invisible overlay to capture taps outside the drawer
            Container(
              color: Colors.transparent,
            ),
            // The actual drawer
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: GestureDetector(
                    onTap: () {
                      // Prevent closing when tapping inside the drawer
                      // This stops the tap from bubbling up to the parent GestureDetector
                    },
                    child: Container(
                      width: targetWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(51), // 0.2 * 255 = 51
                            blurRadius: 20,
                            spreadRadius: 5,
                            offset: const Offset(5, 0),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildHeader(),
                          // Use Expanded with scroll view inside to avoid overflow when vertical space is tight
                          Expanded(
                            child: _buildScrollableContent(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(
                Icons.group,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Team Commands',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: widget.onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(51), // 0.2 * 255 = 51
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ).copyWith(
              overlayColor: WidgetStateProperty.all(
                  Colors.white.withAlpha(26)), // 0.1 * 255 = 26
            ),
            child: const Icon(
              Icons.close,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Remove explicit Scrollbar to avoid ScrollController attachment issues
        // Flutter will show platform-appropriate scrollbars automatically
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTeamInfo(),
                  const SizedBox(height: 24),
                  _buildCommandButtons(),
                  const SizedBox(height: 24),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeamInfo() {
    final teamIdsData = ref.watch(teamIdsDataProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(13), // 0.05 * 255 = 13
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withAlpha(51), // 0.2 * 255 = 51
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.group,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'Select Team:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          teamIdsData.when(
            data: (teamIds) {
              if (teamIds.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(26), // 0.1 * 255 = 26
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'No teams available',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return DropdownButtonFormField<String>(
                initialValue: _selectedTeamId,
                hint: const Text('Choose a team'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: Colors.blue.withAlpha(77)), // 0.3 * 255 = 77
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: Colors.blue.withAlpha(77)), // 0.3 * 255 = 77
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: teamIds.map((teamId) {
                  return DropdownMenuItem<String>(
                    value: teamId,
                    child: Text(teamId),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedTeamId = newValue;
                  });
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(26), // 0.1 * 255 = 26
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Error loading teams',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Team Commands',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const Text(
          'Send commands to all platforms in this team',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        _buildCommandButton(
          icon: Icons.play_arrow,
          label: 'Start TEAM',
          description: 'Start/Execute mission for team',
          color: Colors.green,
          onTap: () => _confirmStartTeam(), // USER_ACCEPT_TEAM
          enabled: _selectedTeamId != null,
        ),
        const SizedBox(height: 12),
        _buildCommandButton(
          icon: Icons.cancel,
          label: 'Cancel TEAM',
          description: 'Cancel current missions of team',
          color: Colors.orange,
          onTap: () =>
              _confirmCancelTeam(), // USER_CANCEL_TEAM with confirmation
          enabled: _selectedTeamId != null,
        ),
        const SizedBox(height: 12),
        _buildCommandButton(
          icon: Icons.home,
          label: 'RTH+Land TEAM',
          description: 'Return to home and land of team',
          color: Colors.blue,
          onTap: () => _confirmRthTeam(), // USER_RTH_TEAM with confirmation
          enabled: _selectedTeamId != null,
        ),
        const SizedBox(height: 12),
        _buildCommandButton(
          icon: Icons.power_settings_new,
          label: 'KILL TEAM',
          description: 'Emergency kill all platforms of team',
          color: Colors.red,
          onTap: () => _confirmKillTeam(), // USER_KILL_TEAM with confirmation
          enabled: _selectedTeamId != null,
        ),
      ],
    );
  }

  Widget _buildCommandButton({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final buttonColor = enabled ? color : Colors.grey;
    final effectiveOnTap = enabled ? onTap : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(12),
        splashColor:
            enabled ? buttonColor.withAlpha(26) : null, // 0.1 * 255 = 26
        highlightColor:
            enabled ? buttonColor.withAlpha(13) : null, // 0.05 * 255 = 13
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color:
                buttonColor.withAlpha(enabled ? 26 : 13), // 0.1 or 0.05 * 255
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  buttonColor.withAlpha(enabled ? 77 : 51), // 0.3 or 0.2 * 255
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: buttonColor
                    .withAlpha(enabled ? 255 : 128), // 1.0 or 0.5 * 255
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: buttonColor
                            .withAlpha(enabled ? 255 : 128), // 1.0 or 0.5 * 255
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: buttonColor
                            .withAlpha(enabled ? 179 : 102), // 0.7 or 0.4 * 255
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(13), // 0.05 * 255 = 13
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            size: 16,
            color: Colors.red.withAlpha(179), // 0.7 * 255 = 179
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedTeamId != null
                  ? 'These commands affect ALL platforms in the selected team'
                  : 'Select a team above to enable commands',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.withAlpha(179), // 0.7 * 255 = 179
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendTeamCommand(int commandType) {
    if (_selectedTeamId == null) {
      _showSnackBar('Please select a team first', Colors.orange);
      return;
    }

    final rosProvider = ref.read(rosClientProvider.notifier);
    final rosClient = ref.read(rosClientProvider);
    if (rosClient == null || !rosClient.isConnected()) {
      _showSnackBar('ROS client not connected', Colors.red);
      return;
    }

    try {
      Map<String, dynamic> userCommand = {
        'user_command': commandType,
        'team_id': _selectedTeamId!,
        'platform_id': '', // Empty for team-wide commands
      };

      rosProvider.publishToTopic(
        topicName: '/planner_command',
        messageType: 'auspex_msgs/UserCommand',
        message: userCommand,
      );

      String commandName = _getCommandName(commandType);
      debugPrint('Sent $commandName command to team: $_selectedTeamId');
      _showSnackBar(
          '$commandName command sent to team', _getCommandColor(commandType));
    } catch (e) {
      debugPrint('Error sending team command: $e');
      _showSnackBar('Error sending command', Colors.red);
    }
  }

  Future<void> _confirmStartTeam() async {
    if (_selectedTeamId == null) {
      _showSnackBar('Please select a team first', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Start Command'),
          content: Text(
            'Do you want to start/execute the mission for team "$_selectedTeamId"?',
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
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('YES, START'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _sendTeamCommand(5); // USER_ACCEPT_TEAM
    }
  }

  Future<void> _confirmKillTeam() async {
    if (_selectedTeamId == null) {
      _showSnackBar('Please select a team first', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm KILL Command'),
          content: const Text(
            'Do you really want to KILL all drones in this team? This leads to fatal damage.',
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
        );
      },
    );

    if (confirmed == true) {
      _sendTeamCommand(10);
    }
  }

  Future<void> _confirmCancelTeam() async {
    if (_selectedTeamId == null) {
      _showSnackBar('Please select a team first', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Cancel Command'),
          content: Text(
            'Do you want to cancel all current missions for team "$_selectedTeamId"?',
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
        );
      },
    );

    if (confirmed == true) {
      _sendTeamCommand(1);
    }
  }

  Future<void> _confirmRthTeam() async {
    if (_selectedTeamId == null) {
      _showSnackBar('Please select a team first', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Return Home Command'),
          content: Text(
            'Do you want all drones in team "$_selectedTeamId" to return home and land?',
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
        );
      },
    );

    if (confirmed == true) {
      _sendTeamCommand(8);
    }
  }

  String _getCommandName(int commandType) {
    switch (commandType) {
      case 1:
        return 'CANCEL';
      case 5:
        return 'START';
      case 8:
        return 'CANCEL + RTH';
      case 10:
        return 'KILL';
      default:
        return 'UNKNOWN';
    }
  }

  Color _getCommandColor(int commandType) {
    switch (commandType) {
      case 1:
        return Colors.orange;
      case 5:
        return Colors.green;
      case 8:
        return Colors.blue;
      case 10:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (mounted) {
      final scaffold = ScaffoldMessenger.of(context);
      scaffold.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
