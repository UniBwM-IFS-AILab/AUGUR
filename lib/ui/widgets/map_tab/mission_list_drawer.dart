import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/core/classes/mission.dart';

class MissionListDrawer extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final Function(Mission) onMissionSelected;
  final bool shouldClose;

  const MissionListDrawer({
    super.key,
    required this.onClose,
    required this.onMissionSelected,
    required this.shouldClose,
  });

  @override
  ConsumerState<MissionListDrawer> createState() => _MissionListDrawerState();
}

class _MissionListDrawerState extends ConsumerState<MissionListDrawer>
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
  void didUpdateWidget(MissionListDrawer oldWidget) {
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
    final missionDataAsync = ref.watch(missionsStreamProvider);

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
                          'Mission List',
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
                  child: missionDataAsync.when(
                    data: (missions) {
                      if (missions.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No Missions Available',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Missions will appear here when created',
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
                        itemCount: missions.length,
                        itemBuilder: (context, index) {
                          final mission = missions[index];
                          return _buildMissionCard(mission);
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
                            'Error Loading Missions',
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

  Widget _buildMissionCard(Mission mission) {
    final teamId = mission.teamId;
    final platformClass = mission.platformClass.name;
    final sensorMode = mission.sensorMode.name;
    final missionGoal =
        mission.missionGoal.isNotEmpty ? mission.missionGoal : 'Not specified';
    final searchAreasText = mission.searchAreas.isEmpty
        ? 'No search areas'
        : (mission.searchAreas.length == 1
            ? mission.searchAreas.first.type.name
            : '${mission.searchAreas.length} search areas');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => widget.onMissionSelected(mission),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Team ID (main identifier)
              Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      teamId,
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
                      color: mission.searchAreas.isNotEmpty
                          ? mission.searchAreas.first.type.color
                              .withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: mission.searchAreas.isNotEmpty
                            ? mission.searchAreas.first.type.borderColor
                            : Colors.grey,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      searchAreasText.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: mission.searchAreas.isNotEmpty
                            ? mission.searchAreas.first.type.borderColor
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Mission Goal
              if (missionGoal != 'Not specified')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    missionGoal,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(
                        Icons.smart_toy, 'Platform', platformClass),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailRow(Icons.sensors, 'Sensor', sensorMode),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(Icons.height, 'Alt Range',
                        '${mission.minHeight}-${mission.maxHeight}m'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailRow(Icons.location_on, 'Areas',
                        '${mission.allAreas.length}'),
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
}
