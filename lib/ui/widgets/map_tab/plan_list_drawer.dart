import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/core/classes/plan.dart';

class PlanListDrawer extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final Function(Plan) onPlanSelected;
  final Function(Plan)? onPlanFocused; // Add focus callback
  final bool shouldClose;

  const PlanListDrawer({
    super.key,
    required this.onClose,
    required this.onPlanSelected,
    this.onPlanFocused,
    required this.shouldClose,
  });

  @override
  ConsumerState<PlanListDrawer> createState() => _PlanListDrawerState();
}

class _PlanListDrawerState extends ConsumerState<PlanListDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

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

    _animationController.forward();
  }

  @override
  void didUpdateWidget(PlanListDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.shouldClose && !oldWidget.shouldClose) {
      _animationController.reverse().then((_) {
        widget.onClose();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planDataAsync = ref.watch(planStreamProvider);

    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          elevation: 16,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: Container(
            width: 320,
            height: MediaQuery.of(context).size.height,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.assignment,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Plan List',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            _animationController.reverse().then((_) {
                          widget.onClose();
                        }),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: planDataAsync.when(
                    data: (plans) {
                      if (plans.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No Plans Available',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Create plans in the Waypoints tab',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: plans.length,
                        itemBuilder: (context, index) {
                          final plan = plans[index];
                          return _buildPlanCard(plan);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error Loading Plans',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
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
      ),
    );
  }

  Widget _buildPlanCard(Plan plan) {
    final planId = plan.planId.toString();
    final platformId = plan.platformId;
    final teamId = plan.teamId;
    final priority = plan.priority.toString();
    final status = plan.status.name;
    final actions = plan.actions;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Focus on the plan first, then open the drawer
          widget.onPlanFocused?.call(plan);
          widget.onPlanSelected(plan);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan ID (main identifier)
              Row(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      planId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(
                        Icons.smart_toy, 'Platform', platformId),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailRow(Icons.group, 'Team', teamId),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(Icons.priority_high, 'Priority',
                        _getPriorityText(priority)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailRow(
                        Icons.list, 'Actions', '${actions.length}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _getPriorityText(String priority) {
    final priorityValue = int.tryParse(priority) ?? 0;

    if (priorityValue < 5 && priorityValue > 0) {
      return 'Low';
    } else if (priorityValue < 10 && priorityValue >= 5) {
      return 'Medium';
    } else if (priorityValue < 15 && priorityValue >= 10) {
      return 'High';
    } else if (priorityValue >= 15) {
      return 'Critical';
    } else {
      return priority;
    }
  }

  Color _getStatusColor(String status) {
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
}
