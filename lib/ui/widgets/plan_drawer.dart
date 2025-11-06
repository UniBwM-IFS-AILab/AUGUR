import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:rational/rational.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/state/ros_provider.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/core/classes/waypoint.dart';
import 'package:augur/core/classes/plan.dart';
import 'package:augur/ui/widgets/plan_drawer_height_selection.dart';

class PlanDrawer extends ConsumerStatefulWidget {
  final bool isVisible;
  final Plan? plan;
  final VoidCallback onClose;
  final VoidCallback? onPlanExecuted;
  final VoidCallback? onPlanDeleted;
  final VoidCallback? onPlanEdited; // New callback for edit mode
  final VoidCallback? onEditModeEntered; // New callback when edit mode starts
  final VoidCallback? onEditModeExited; // New callback when edit mode ends
  final Function(
          List<WaypointWithAltitude> waypoints,
          List<Polyline> polylines,
          bool editMode,
          Function(int)? onEditableWaypointTapped,
          int? selectedWaypointIndex)?
      onWaypointsChanged; // Callback to update map with edit waypoints
  final int?
      selectedOriginalWaypointIndex; // Index of the selected original waypoint

  const PlanDrawer({
    super.key,
    required this.isVisible,
    required this.plan,
    required this.onClose,
    this.onPlanExecuted,
    this.onPlanDeleted,
    this.onPlanEdited,
    this.onEditModeEntered,
    this.onEditModeExited,
    this.onWaypointsChanged,
    this.selectedOriginalWaypointIndex,
  });

  @override
  ConsumerState<PlanDrawer> createState() => PlanDrawerState();
}

class PlanDrawerState extends ConsumerState<PlanDrawer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Height drawer animation
  late AnimationController _heightDrawerAnimationController;
  late Animation<Offset> _heightDrawerSlideAnimation;

  // Edit mode state
  bool _isEditMode = false;
  List<WaypointWithAltitude> _editableWaypoints = [];
  late TextEditingController _priorityController;
  int _editablePriority = 0;
  String _selectedPlatformId = '';
  int _selectedWaypointIndex = 0; // -1 for no selection, 0+ for waypoint index

  // Takeoff and landing options for edit mode
  bool _addTakeoff = false;
  bool _addLanding = false;
  String _landingType = 'Simple Land';
  final List<String> _landingOptions = ['Simple Land', 'RTH and Land'];

  @override
  void initState() {
    super.initState();

    _priorityController = TextEditingController();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right side
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

    // Height drawer animation controller
    _heightDrawerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _heightDrawerSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0), // Start from left side
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heightDrawerAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(PlanDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        // Instantly close the drawer by resetting the animation
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _heightDrawerAnimationController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible && !_animationController.isAnimating) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Main plan drawer
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(-5, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _buildContent(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Height selection drawer (slides in from left when visible)
        if (_isEditMode &&
            _editableWaypoints.isNotEmpty &&
            _selectedWaypointIndex >= 0 &&
            _selectedWaypointIndex < _editableWaypoints.length)
          Positioned(
            left: 10,
            top: 100,
            child: SlideTransition(
              position: _heightDrawerSlideAnimation,
              child: Container(
                width: 220,
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 10,
                      offset: const Offset(-2, 2),
                    ),
                  ],
                ),
                child: PlanDrawerHeightSelection(
                  waypointIndex: _selectedWaypointIndex,
                  currentHeight:
                      _editableWaypoints[_selectedWaypointIndex].altitudeMeters,
                  onHeightChanged: _onHeightChanged,
                  onClose: _closeHeightDrawer,
                  onDelete: () => _deleteWaypoint(_selectedWaypointIndex),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isEditMode ? Colors.brown : AppColors.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isEditMode ? Icons.edit_note : Icons.assignment,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _isEditMode ? 'Edit Plan' : 'Plan Details',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _isEditMode ? _discardChanges : widget.onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(51),
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
              overlayColor: WidgetStateProperty.all(Colors.white.withAlpha(26)),
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

  Widget _buildContent() {
    if (widget.plan == null) {
      return const Center(
        child: Text(
          'No plan data available',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    final plan = widget.plan!;

    // Show edit mode content if in edit mode
    if (_isEditMode) {
      return _buildEditContent(plan);
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection(plan),
            const SizedBox(height: 32),
            _buildActionButtons(),
            const SizedBox(height: 32),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(Plan plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withAlpha(51),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.tag,
            label: 'Plan ID:',
            value: plan.planId.toString(),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.devices,
            label: 'Platform ID:',
            value: plan.platformId,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.group,
            label: 'Team ID:',
            value: plan.teamId,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.priority_high,
            label: 'Priority:',
            value: _getPriorityText(plan.priority),
            valueColor: _getPriorityColor(plan.priority),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.info,
            label: 'Status:',
            value: plan.status.name.toUpperCase(),
            valueColor: _getStatusColor(plan.status.name),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? Colors.black87,
              fontWeight:
                  valueColor != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final plan = widget.plan!;

    return Column(
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.play_arrow,
                label: 'Execute Plan',
                color: Colors.green,
                onTap: _isExecuteButtonEnabled(plan) ? _executePlan : null,
                enabled: _isExecuteButtonEnabled(plan),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.delete,
                label: 'Delete Plan',
                color: Colors.red,
                onTap: _isDeleteButtonEnabled(plan) ? _deletePlan : null,
                enabled: _isDeleteButtonEnabled(plan),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.edit_note,
                label: 'Edit Plan',
                color: Colors.brown,
                onTap: _isEditButtonEnabled(plan) ? _editPlan : null,
                enabled: _isEditButtonEnabled(plan),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : Colors.grey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: enabled ? color.withAlpha(26) : null,
        highlightColor: enabled ? color.withAlpha(13) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: effectiveColor.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: effectiveColor.withAlpha(77),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: effectiveColor,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
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
        color: Colors.grey.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Click outside or press close to dismiss',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPriorityText(dynamic priority) {
    if (priority == null) return 'N/A';

    final priorityValue = int.tryParse(priority.toString()) ?? 0;

    if (priorityValue < 5 && priorityValue > 0) {
      return 'Low ($priorityValue)';
    } else if (priorityValue < 10 && priorityValue >= 5) {
      return 'Medium ($priorityValue)';
    } else if (priorityValue < 15 && priorityValue >= 10) {
      return 'High ($priorityValue)';
    } else if (priorityValue >= 15) {
      return 'Critical ($priorityValue)';
    } else {
      return priorityValue.toString();
    }
  }

  Color _getPriorityColor(dynamic priority) {
    if (priority == null) return Colors.grey;

    final priorityValue = int.tryParse(priority.toString()) ?? 0;

    if (priorityValue < 5 && priorityValue > 0) {
      return Colors.green;
    } else if (priorityValue < 10 && priorityValue >= 5) {
      return Colors.orange;
    } else if (priorityValue < 15 && priorityValue >= 10) {
      return Colors.red;
    } else if (priorityValue >= 15) {
      return Colors.purple;
    } else {
      return Colors.grey;
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;

    switch (status.toUpperCase()) {
      case 'INACTIVE':
        return Colors.grey;
      case 'RUNNING':
      case 'ACTIVE':
        return Colors.green;
      case 'PENDING':
      case 'WAITING':
        return Colors.orange;
      case 'FAILED':
      case 'ERROR':
      case 'ABORTED':
        return Colors.red;
      case 'COMPLETED':
        return Colors.blue;
      case 'PAUSED':
        return Colors.purple;
      case 'CANCELED':
      case 'CANCELLED':
        return Colors.orange.shade700;
      default:
        return Colors.grey;
    }
  }

  bool _isEditButtonEnabled(Plan plan) {
    String status = plan.status.name;
    return status.toUpperCase() == 'INACTIVE';
  }

  bool _isExecuteButtonEnabled(Plan plan) {
    String status = plan.status.name;
    return status.toUpperCase() == 'INACTIVE';
  }

  bool _isDeleteButtonEnabled(Plan plan) {
    String status = plan.status.name;
    return status.toUpperCase() != 'ACTIVE' &&
        status.toUpperCase() != 'RUNNING';
  }

  void _executePlan() async {
    if (widget.plan == null) return;

    final rosClient = ref.read(rosClientProvider);
    if (rosClient == null || !rosClient.isConnected()) {
      debugPrint('ROS client not connected, cannot execute plan');
      _showSnackBar('ROS client not connected', Colors.red);
      return;
    }

    try {
      String platformId = widget.plan!.platformId;
      String teamId = widget.plan!.teamId;
      String planId = widget.plan!.planId.toString();

      if (planId.isEmpty || platformId.isEmpty) {
        _showSnackBar('Invalid plan data', Colors.red);
        return;
      }

      // First, update the plan priority to be highest for this platform
      await _updatePlanPriorityToHighest(planId, platformId);

      // Create UserCommand message according to UserCommand.msg
      Map<String, dynamic> userCommand = {
        'user_command': 15, // USER_ACCEPT_PLATFORM
        'team_id': teamId,
        'platform_id': platformId,
      };

      // Publish to planner_command topic
      rosClient.publish(
        topicName: 'planner_command',
        messageType: 'auspex_msgs/UserCommand',
        message: userCommand,
      );

      debugPrint('Executing plan for Platform: $platformId, Team: $teamId');
      _showSnackBar('Plan execution command sent', Colors.green);

      // Notify parent and close drawer
      widget.onPlanExecuted?.call();
      widget.onClose();
    } catch (e) {
      debugPrint('Error executing plan: $e');
      _showSnackBar('Error executing plan', Colors.red);
    }
  }

  /// Updates the plan priority to be the highest among all plans for the same platform
  Future<void> _updatePlanPriorityToHighest(
      String planId, String platformId) async {
    try {
      final redisClient = ref.read(redisClientProvider);
      if (redisClient == null) {
        debugPrint('Redis client not available');
        return;
      }

      // Get all plans to find the highest priority for this platform
      final planData = ref.read(planStreamProvider).value ?? [];

      // Count active plans for this platform and find highest priority
      // Exclude plans with CANCELED or COMPLETED status
      int activePlanCount = 0;
      int highestPriority = 0;
      for (final plan in planData) {
        if (plan.platformId == platformId) {
          // Skip plans with CANCELED or COMPLETED status
          String status = plan.status.name.toUpperCase();
          if (status == 'CANCELED' || status == 'COMPLETED') {
            continue;
          }

          activePlanCount++;
          if (plan.priority > highestPriority) {
            highestPriority = plan.priority;
          }
        }
      }

      // Only update priority if there are multiple active plans for this platform
      if (activePlanCount <= 1) {
        return;
      }

      // Set the priority to be 1 higher than the current highest
      int newPriority = highestPriority + 1;

      // Update the priority in Redis
      bool success = await redisClient.updatePlanPriority(planId, newPriority);
      if (success) {
        debugPrint('Successfully updated plan priority to $newPriority');
      } else {
        debugPrint('Failed to update plan priority');
      }
    } catch (e) {
      debugPrint('Error updating plan priority: $e');
      // Don't throw error - we still want to execute the plan even if priority update fails
    }
  }

  // Edit Plan functionality
  void _editPlan() {
    if (widget.plan == null) return;

    // Initialize edit mode with current plan data
    setState(() {
      _isEditMode = true;
      _editablePriority = widget.plan!.priority;
      _priorityController.text = _editablePriority.toString();
      _selectedPlatformId = widget.plan!.platformId;

      // Extract waypoints from actions
      _editableWaypoints = _extractWaypointsFromPlan(widget.plan!);

      // Set selected waypoint based on original selection or default to first
      if (widget.selectedOriginalWaypointIndex != null &&
          widget.selectedOriginalWaypointIndex! >= 0 &&
          widget.selectedOriginalWaypointIndex! < _editableWaypoints.length) {
        _selectedWaypointIndex = widget.selectedOriginalWaypointIndex!;
      } else {
        _selectedWaypointIndex = _editableWaypoints.isNotEmpty ? 0 : 0;
      }

      // Show height drawer if there are waypoints to edit
      if (_editableWaypoints.isNotEmpty) {
        _heightDrawerAnimationController.forward();
      } else {
        _heightDrawerAnimationController.reverse();
      }

      // Determine takeoff and landing defaults from actions
      _initializeTakeoffLandingDefaults(
          widget.plan!.actions.map((a) => a.toMessage()).toList());
    });

    // Immediately update the map with edit waypoints so user can see and edit them
    _updateMapWaypoints();

    // Notify parent that we're entering edit mode
    widget.onPlanEdited?.call();
    widget.onEditModeEntered?.call();
  }

  void _initializeTakeoffLandingDefaults(List<dynamic> actions) {
    _addTakeoff = false;
    _addLanding = false;
    _landingType = 'Simple Land';

    // Check if second-to-last action is fly action with home_platform_id
    bool hasHomePosition = _checkForHomePosition(actions);
    if (hasHomePosition) {
      _landingType = 'RTH and Land';
    }

    for (var action in actions) {
      if (action is Map<String, dynamic>) {
        String? actionName = action['action_name']?.toString();

        if (actionName == 'take_off') {
          _addTakeoff = true;
        } else if (actionName == 'land') {
          _addLanding = true;
        }
      }
    }
  }

  bool _checkForHomePosition(List<dynamic> actions) {
    if (actions.length < 2) return false;

    // Get the current plan's platform ID
    String currentPlatformId = widget.plan!.platformId;
    if (currentPlatformId.isEmpty) return false;

    // Construct the expected home symbol
    String expectedHomeSymbol = 'home_$currentPlatformId';

    // Get the second-to-last action
    var secondLastAction = actions[actions.length - 2];

    if (secondLastAction is! Map<String, dynamic>) return false;

    String? actionName = secondLastAction['action_name']?.toString();

    // Check if it's a fly action
    if (actionName == null || !actionName.toLowerCase().contains('fly')) {
      return false;
    }

    // Check if it has parameters and the second parameter contains home_$platformId
    var parameters = secondLastAction['parameters'];
    if (parameters is! List || parameters.length < 2) {
      return false;
    }

    // Check the second parameter (index 1)
    var secondParam = parameters[1];
    if (secondParam is Map<String, dynamic>) {
      var symbolAtoms = secondParam['symbol_atom'];
      if (symbolAtoms is List && symbolAtoms.isNotEmpty) {
        String symbolAtom = symbolAtoms[0].toString();
        return symbolAtom == expectedHomeSymbol;
      }
    }

    return false;
  }

  Widget _buildEditContent(Plan plan) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditHeader(),
          const SizedBox(height: 20),

          // Platform and Priority Section
          _buildPlatformSelector(),
          const SizedBox(height: 16),
          _buildPrioritySlider(),
          const SizedBox(height: 20),

          // Takeoff and Landing Options
          _buildTakeoffLandingOptions(),
          const SizedBox(height: 20),

          // Waypoint Editor
          _buildWaypointEditor(),
          const SizedBox(height: 20),

          // Action Buttons
          _buildEditActionButtons(),
        ],
      ),
    );
  }

  Widget _buildPlatformSelector() {
    final platformsAsync = ref.watch(platformDataProvider);

    return platformsAsync.when(
      data: (platforms) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(13),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withAlpha(51)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: platforms.any((p) => p.platformId == _selectedPlatformId)
                  ? _selectedPlatformId
                  : platforms.isNotEmpty
                      ? platforms.first.platformId
                      : null,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
              isExpanded: true,
              items: platforms.map((platform) {
                return DropdownMenuItem<String>(
                  value: platform.platformId,
                  child: Text(
                    platform.platformId,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPlatformId = value ?? '';
                });
              },
            ),
          ],
        ),
      ),
      loading: () => Container(
        padding: const EdgeInsets.all(12),
        child: const CircularProgressIndicator(),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.all(12),
        child: Text('Error loading platforms: $error'),
      ),
    );
  }

  Widget _buildPrioritySlider() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Priority: ${_getPriorityText(_editablePriority)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _getPriorityColor(_editablePriority),
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _editablePriority.toDouble(),
            min: 0,
            max: 20,
            divisions: 20,
            activeColor: _getPriorityColor(_editablePriority),
            onChanged: (value) {
              setState(() {
                _editablePriority = value.round();
                _priorityController.text = _editablePriority.toString();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTakeoffLandingOptions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Flight Options',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),

          // Takeoff option
          Row(
            children: [
              Transform.scale(
                scale: 0.8,
                child: Checkbox(
                  value: _addTakeoff,
                  onChanged: (val) {
                    setState(() {
                      _addTakeoff = val ?? false;
                    });
                  },
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Text('Add Takeoff', style: TextStyle(fontSize: 12)),
            ],
          ),

          // Landing option
          Row(
            children: [
              Transform.scale(
                scale: 0.8,
                child: Checkbox(
                  value: _addLanding,
                  onChanged: (val) {
                    setState(() {
                      _addLanding = val ?? false;
                    });
                  },
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Text('Add Land:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Expanded(
                child: IgnorePointer(
                  ignoring: !_addLanding,
                  child: Opacity(
                    opacity: _addLanding ? 1.0 : 0.5,
                    child: DropdownButton<String>(
                      value: _landingType,
                      isDense: true,
                      underline: Container(),
                      style: const TextStyle(fontSize: 11, color: Colors.black),
                      items: _landingOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: _addLanding
                          ? (String? newValue) {
                              setState(() {
                                _landingType = newValue!;
                              });
                            }
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.brown.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.brown.withAlpha(77),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note,
            color: Colors.brown,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Plan Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
                Text(
                  'Plan ID: ${widget.plan!.planId}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.brown.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withAlpha(51),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Waypoints',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _addWaypoint,
                    icon: const Icon(Icons.add_location, color: Colors.green),
                    tooltip: 'Add Waypoint',
                  ),
                  IconButton(
                    onPressed: _clearAllWaypoints,
                    icon: const Icon(Icons.clear_all, color: Colors.orange),
                    tooltip: 'Clear All',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(26),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.withAlpha(77), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap on the map to add waypoints',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_editableWaypoints.isEmpty)
            const Center(
              child: Text(
                'No waypoints in this plan.\nClick + to add waypoints or tap on the map.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            )
          else
            Column(
              children: [
                for (int index = 0; index < _editableWaypoints.length; index++)
                  _buildEditableWaypointCard(index),
              ],
            ),
        ],
      ),
    );
  }

  void _clearAllWaypoints() {
    setState(() {
      _editableWaypoints.clear();
      _selectedWaypointIndex = 0;
    });
    _heightDrawerAnimationController
        .reverse(); // Close height drawer when clearing all waypoints
    _updateMapWaypoints();
  }

  // Method to be called when the map is tapped during edit mode
  void addWaypointFromMap(LatLng position) {
    if (!_isEditMode) return;

    // Use default altitude or inherit from last waypoint
    double defaultAltitude = _editableWaypoints.isNotEmpty
        ? _editableWaypoints.last.altitudeMeters
        : 50.0;

    setState(() {
      // Insert after the currently selected waypoint
      int insertIndex = _selectedWaypointIndex >= 0 &&
              _selectedWaypointIndex < _editableWaypoints.length
          ? _selectedWaypointIndex + 1
          : _editableWaypoints.length;

      _editableWaypoints.insert(
          insertIndex,
          WaypointWithAltitude(
            position: position,
            altitudeMeters: defaultAltitude,
          ));
      // Select the newly added waypoint
      _selectedWaypointIndex = insertIndex;
    });
    // Show height drawer for the new waypoint
    _heightDrawerAnimationController.forward();
    _updateMapWaypoints();
  }

  // Getter to check if in edit mode
  bool get isInEditMode => _isEditMode;

  // Method to select a waypoint from external sources (like map clicks)
  void selectWaypoint(int index) {
    if (!_isEditMode || index < 0 || index >= _editableWaypoints.length) return;

    setState(() {
      _selectedWaypointIndex = index;
    });

    // Show height drawer for the selected waypoint
    _heightDrawerAnimationController.forward();

    // Update the map to reflect the new selection
    _updateMapWaypoints();
  }

  // Getter for selected waypoint index
  int get selectedWaypointIndex => _selectedWaypointIndex;

  Widget _buildEditableWaypointCard(int index) {
    final waypoint = _editableWaypoints[index];
    final isSelected = _selectedWaypointIndex == index;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.brown.withAlpha(26) : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedWaypointIndex = index;
          });
          _heightDrawerAnimationController.forward();
          // Update the map to reflect the new selection
          _updateMapWaypoints();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border:
                isSelected ? Border.all(color: Colors.brown, width: 2) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Waypoint ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected ? Colors.brown : null,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Move up button
                        IconButton(
                          onPressed:
                              index > 0 ? () => _moveWaypointUp(index) : null,
                          icon: Icon(
                            Icons.keyboard_arrow_up,
                            color: index > 0 ? Colors.blue : Colors.grey,
                            size: 20,
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          tooltip: 'Move Up',
                        ),
                        // Move down button
                        IconButton(
                          onPressed: index < _editableWaypoints.length - 1
                              ? () => _moveWaypointDown(index)
                              : null,
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: index < _editableWaypoints.length - 1
                                ? Colors.blue
                                : Colors.grey,
                            size: 20,
                          ),
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          tooltip: 'Move Down',
                        ),
                        // Delete button
                        IconButton(
                          onPressed: () => _deleteWaypoint(index),
                          icon: const Icon(Icons.delete,
                              color: Colors.red, size: 20),
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          tooltip: 'Delete Waypoint',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lat: ${waypoint.position.latitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Lng: ${waypoint.position.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Height: ', style: TextStyle(fontSize: 12)),
                    Text(
                      '${waypoint.altitudeMeters.toInt()}m',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _discardChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Discard'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _updatePlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Update'),
          ),
        ),
      ],
    );
  }

  List<WaypointWithAltitude> _extractWaypointsFromPlan(Plan plan) {
    List<WaypointWithAltitude> waypoints = [];

    // Use the waypoints from the Plan object
    for (var waypoint in plan.waypoints) {
      waypoints.add(WaypointWithAltitude(
        position: waypoint.position,
        altitudeMeters: waypoint.altitude,
      ));
    }

    return waypoints;
  }

  void _addWaypoint() {
    setState(() {
      // Insert after the currently selected waypoint
      int insertIndex = _selectedWaypointIndex >= 0 &&
              _selectedWaypointIndex < _editableWaypoints.length
          ? _selectedWaypointIndex + 1
          : _editableWaypoints.length;

      _editableWaypoints.insert(
          insertIndex,
          WaypointWithAltitude(
            position: const LatLng(0.0, 0.0),
            altitudeMeters: 10.0,
          ));
      // Select the newly added waypoint
      _selectedWaypointIndex = insertIndex;
    });
    // Show height drawer for the new waypoint
    _heightDrawerAnimationController.forward();
    _updateMapWaypoints();
  }

  void _moveWaypointUp(int index) {
    if (index <= 0 || index >= _editableWaypoints.length) return;

    setState(() {
      // Swap with previous waypoint
      final waypoint = _editableWaypoints.removeAt(index);
      _editableWaypoints.insert(index - 1, waypoint);

      // Update selected index if it was the moved waypoint
      if (_selectedWaypointIndex == index) {
        _selectedWaypointIndex = index - 1;
      } else if (_selectedWaypointIndex == index - 1) {
        _selectedWaypointIndex = index;
      }
    });
    _updateMapWaypoints();
  }

  void _moveWaypointDown(int index) {
    if (index < 0 || index >= _editableWaypoints.length - 1) return;

    setState(() {
      // Swap with next waypoint
      final waypoint = _editableWaypoints.removeAt(index);
      _editableWaypoints.insert(index + 1, waypoint);

      // Update selected index if it was the moved waypoint
      if (_selectedWaypointIndex == index) {
        _selectedWaypointIndex = index + 1;
      } else if (_selectedWaypointIndex == index + 1) {
        _selectedWaypointIndex = index;
      }
    });
    _updateMapWaypoints();
  }

  void _deleteWaypoint(int index) {
    setState(() {
      _editableWaypoints.removeAt(index);

      // Adjust selected waypoint index
      if (_selectedWaypointIndex >= _editableWaypoints.length) {
        _selectedWaypointIndex =
            _editableWaypoints.isNotEmpty ? _editableWaypoints.length - 1 : 0;
      } else if (_selectedWaypointIndex > index) {
        _selectedWaypointIndex--;
      }

      // Close height drawer if no waypoints left
      if (_editableWaypoints.isEmpty) {
        _heightDrawerAnimationController.reverse();
      }
    });
    _updateMapWaypoints();
  }

  void _updateMapWaypoints() {
    if (_isEditMode && widget.onWaypointsChanged != null) {
      // Create polylines connecting the waypoints
      List<Polyline> polylines = [];
      if (_editableWaypoints.length > 1) {
        List<LatLng> points =
            _editableWaypoints.map((wp) => wp.position).toList();

        polylines.add(Polyline(
          points: points,
          strokeWidth: 3,
          color: Colors.brown,
          pattern: const StrokePattern.solid(),
          borderStrokeWidth: 1,
          borderColor: Colors.brown.shade700,
        ));
      }

      widget.onWaypointsChanged!(_editableWaypoints, polylines, _isEditMode,
          _onEditableWaypointTapped, _selectedWaypointIndex);
    }
  }

  void _onEditableWaypointTapped(int index) {
    setState(() {
      _selectedWaypointIndex = index;
    });
    // Show height drawer when a waypoint is selected
    _heightDrawerAnimationController.forward();
    // Update the map with the new selection
    _updateMapWaypoints();
  }

  void _onHeightChanged(double newHeight) {
    if (_selectedWaypointIndex >= 0 &&
        _selectedWaypointIndex < _editableWaypoints.length) {
      setState(() {
        _editableWaypoints[_selectedWaypointIndex] = WaypointWithAltitude(
          position: _editableWaypoints[_selectedWaypointIndex].position,
          altitudeMeters: newHeight,
        );
      });
      // Update the map to reflect the height change
      _updateMapWaypoints();
    }
  }

  void _closeHeightDrawer() {
    _heightDrawerAnimationController.reverse();
  }

  void _discardChanges() {
    setState(() {
      _isEditMode = false;
      _editableWaypoints.clear();
      _selectedWaypointIndex = 0;
    });
    _heightDrawerAnimationController
        .reverse(); // Close height drawer when discarding changes

    // Clear map waypoints
    if (widget.onWaypointsChanged != null) {
      widget.onWaypointsChanged!([], [], false, null, null);
    }

    // Notify parent that we're exiting edit mode
    widget.onEditModeExited?.call();
  }

  // Helper function to convert double to proper fraction representation
  Map<String, int> _doubleToFraction(double value) {
    final rational = Rational.parse(value.toString());
    return {
      'numerator': rational.numerator.toInt(),
      'denominator': rational.denominator.toInt(),
    };
  }

  void _updatePlan() async {
    if (widget.plan == null) return;

    String planId = widget.plan!.planId.toString();
    if (planId.isEmpty) {
      _showSnackBar('Invalid plan ID', Colors.red);
      return;
    }

    try {
      _showSnackBar('Updating plan...', Colors.orange);

      // Create new actions from waypoints following the ActionInstance structure
      List<Map<String, dynamic>> newActions = [];
      int actionId = 0;
      String platformId = _selectedPlatformId.isNotEmpty
          ? _selectedPlatformId
          : widget.plan!.platformId;

      // Add takeoff action if selected
      if (_addTakeoff) {
        newActions.add({
          'id': actionId,
          'action_name': 'take_off',
          'task_id': actionId,
          'parameters': [
            {
              'symbol_atom': [platformId],
              'int_atom': [],
              'real_atom': [],
              'boolean_atom': [],
            },
            {
              'symbol_atom': [],
              'int_atom': [],
              'real_atom': [
                {
                  ..._doubleToFraction(10.0),
                }
              ],
              'boolean_atom': [],
            },
          ],
          'status': 'INACTIVE',
        });
        actionId++;
      }

      // Add fly_step_3D action for each waypoint
      for (final waypoint in _editableWaypoints) {
        newActions.add({
          'id': actionId,
          'action_name': 'fly_step_3D',
          'task_id': actionId,
          'parameters': [
            {
              'symbol_atom': [platformId],
              'int_atom': [],
              'real_atom': [],
              'boolean_atom': [],
            },
            {
              'symbol_atom': [],
              'int_atom': [],
              'real_atom': [
                {
                  ..._doubleToFraction(waypoint.position.latitude),
                }
              ],
              'boolean_atom': [],
            },
            {
              'symbol_atom': [],
              'int_atom': [],
              'real_atom': [
                {
                  ..._doubleToFraction(waypoint.position.longitude),
                }
              ],
              'boolean_atom': [],
            },
            {
              'symbol_atom': [],
              'int_atom': [],
              'real_atom': [
                {
                  ..._doubleToFraction(waypoint.altitudeMeters),
                }
              ],
              'boolean_atom': [],
            },
          ],
          'status': 'INACTIVE',
        });
        actionId++;
      }

      // Add landing action if selected
      if (_addLanding) {
        if (_landingType == 'RTH and Land') {
          // Add fly_step_3D to home position
          newActions.add({
            'id': actionId,
            'action_name': 'fly_step_3D',
            'task_id': actionId,
            'parameters': [
              {
                'symbol_atom': [platformId],
                'int_atom': [],
                'real_atom': [],
                'boolean_atom': [],
              },
              {
                'symbol_atom': ["home_$platformId"],
                'int_atom': [],
                'real_atom': [],
                'boolean_atom': [],
              }
            ],
            'status': 'INACTIVE',
          });
          actionId++;
        }

        // Add land action
        newActions.add({
          'id': actionId,
          'action_name': 'land',
          'task_id': actionId,
          'parameters': [
            {
              'symbol_atom': [platformId],
              'int_atom': [],
              'real_atom': [],
              'boolean_atom': [],
            },
          ],
          'status': 'INACTIVE',
        });
      }

      // Prepare update data
      Map<String, dynamic> updates = {
        'priority': _editablePriority,
        'platform_id': platformId,
        'actions': newActions,
      };

      final redisProvider = ref.read(redisClientProvider.notifier);
      bool success = await redisProvider.updatePlan(planId, updates);

      if (success) {
        debugPrint('Successfully updated plan $planId');
        _showSnackBar('Plan updated successfully', Colors.green);

        // Exit edit mode and clear map waypoints
        setState(() {
          _isEditMode = false;
          _editableWaypoints.clear();
          _selectedWaypointIndex = 0;
        });
        _heightDrawerAnimationController
            .reverse(); // Close height drawer when updating

        // Clear map waypoints
        if (widget.onWaypointsChanged != null) {
          widget.onWaypointsChanged!([], [], false, null, null);
        }

        // Notify parent that we're exiting edit mode
        widget.onEditModeExited?.call();

        // Close the drawer to allow the normal plan update mechanism to handle the refresh
        widget.onClose();
      } else {
        debugPrint('Failed to update plan $planId');
        _showSnackBar('Failed to update plan', Colors.red);
      }
    } catch (e) {
      debugPrint('Error updating plan: $e');
      _showSnackBar('Error updating plan: ${e.toString()}', Colors.red);
    }
  }

  /// Updates plan actions/tasks
  Future<void> updatePlanActions(
      String planId, List<Map<String, dynamic>> newActions) async {
    try {
      _showSnackBar('Updating plan actions...', Colors.orange);

      final redisProvider = ref.read(redisClientProvider.notifier);
      bool success = await redisProvider.updatePlanActions(planId, newActions);

      if (success) {
        debugPrint('Successfully updated actions for plan $planId');
        _showSnackBar('Plan actions updated successfully', Colors.green);
      } else {
        debugPrint('Failed to update actions for plan $planId');
        _showSnackBar('Failed to update plan actions', Colors.red);
      }
    } catch (e) {
      debugPrint('Error updating plan actions: $e');
      _showSnackBar('Error updating actions: ${e.toString()}', Colors.red);
    }
  }

  /// Generic method to update multiple plan fields
  Future<void> updatePlan(String planId, Map<String, dynamic> updates) async {
    try {
      _showSnackBar('Updating plan...', Colors.orange);

      final redisProvider = ref.read(redisClientProvider.notifier);
      bool success = await redisProvider.updatePlan(planId, updates);

      if (success) {
        debugPrint('Successfully updated plan $planId');
        _showSnackBar('Plan updated successfully', Colors.green);
      } else {
        debugPrint('Failed to update plan $planId');
        _showSnackBar('Failed to update plan', Colors.red);
      }
    } catch (e) {
      debugPrint('Error updating plan: $e');
      _showSnackBar('Error updating plan: ${e.toString()}', Colors.red);
    }
  }

  void _deletePlan() async {
    if (widget.plan == null) return;

    String planId = widget.plan!.planId.toString();
    String platformId = widget.plan!.platformId;

    if (planId.isEmpty) {
      _showSnackBar('Invalid plan ID', Colors.red);
      return;
    }

    // Show confirmation dialog
    bool? confirm = await _showDeleteConfirmationDialog(planId, platformId);
    if (confirm != true) return;

    try {
      // Show loading indicator
      _showSnackBar('Deleting plan...', Colors.orange);

      // Get Redis client to delete the plan
      final redisProvider = ref.read(redisClientProvider.notifier);

      // Delete the plan from Redis
      bool success = await redisProvider.deletePlan(planId);

      if (success) {
        debugPrint(
            'Successfully deleted plan - Plan ID: $planId, Platform: $platformId');
        _showSnackBar('Plan deleted successfully', Colors.green);

        // Notify parent about successful deletion
        widget.onPlanDeleted?.call();

        // Close the drawer
        widget.onClose();
      } else {
        debugPrint('Failed to delete plan - Plan ID: $planId');
        _showSnackBar('Failed to delete plan', Colors.red);
      }
    } catch (e) {
      debugPrint('Error deleting plan: $e');
      _showSnackBar('Error deleting plan: ${e.toString()}', Colors.red);
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(
      String planId, String platformId) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete Plan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this plan?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan ID: $planId',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Platform: $platformId',
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
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
        );
      },
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (mounted) {
      final scaffold = ScaffoldMessenger.of(context);
      scaffold.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
