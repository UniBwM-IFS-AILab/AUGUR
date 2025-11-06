import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/widgets/map_tab/map_widget.dart';
import 'package:augur/ui/widgets/map_tab/platform_info_drawer.dart';
import 'package:augur/ui/widgets/map_tab/camera_stream_drawer.dart';
import 'package:augur/ui/widgets/map_tab/platform_list_drawer.dart';
import 'package:augur/ui/widgets/map_tab/team_commands_drawer.dart';
import 'package:augur/ui/widgets/map_tab/plan_list_drawer.dart';
import 'package:augur/ui/widgets/map_tab/mission_list_drawer.dart';
import 'package:augur/ui/widgets/map_tab/camera_stream_widget.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/core/classes/platform.dart';
import 'package:augur/core/classes/plan.dart';
import 'package:augur/core/classes/mission.dart';

class MapTabPage extends ConsumerStatefulWidget {
  const MapTabPage({super.key});

  @override
  ConsumerState<MapTabPage> createState() => _MapTabPageState();
}

class _MapTabPageState extends ConsumerState<MapTabPage> {
  Platform? _selectedPlatform; // Changed from String to Platform object
  bool _isDrawerOpen = false;
  bool _isStreamFullscreen = false;
  bool _isPlatformListDrawerOpen = false;
  bool _shouldClosePlatformListDrawer =
      false; // New state for triggering close animation
  String? _focusPlatformId; // Platform ID to focus on
  SharedCameraStreamController? _currentCameraController; // Shared camera controller

  // Team commands state
  bool _isTeamCommandsOpen = false;

  // Plan list state
  bool _isPlanListDrawerOpen = false;
  bool _shouldClosePlanListDrawer = false;

  // Mission list state
  bool _isMissionListDrawerOpen = false;
  bool _shouldCloseMissionListDrawer = false;

  // UI hiding state for plan edit mode
  bool _shouldHideUIElements = false;

  // Selected plan to pass to map widget
  Plan? _selectedPlan;

  // Mission focus state
  Mission? _focusMission;

  // Plan focus state
  Plan? _focusPlan;
  bool _followPlatform = false;

  @override
  void initState() {
    super.initState();
  }

  void _onPlatformSelected(Platform platform) {
    // If a different platform is already selected, close the drawer first
    if (_isDrawerOpen && _selectedPlatform?.platformId != platform.platformId) {
      _onCloseDrawer();
      // Wait for drawer to close and camera controller to dispose before opening new one
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _selectedPlatform = platform;
            _isDrawerOpen = true;
            _isStreamFullscreen = false;
          });
        }
      });
    } else {
      // Same platform or no platform selected, open immediately
      setState(() {
        _selectedPlatform = platform;
        _isDrawerOpen = true;
        _isStreamFullscreen = false;
      });
    }
  }

  void _onCloseDrawer() {
    // Properly dispose the camera controller when drawer is closed
    _disposeCurrentCameraController();
    setState(() {
      _isDrawerOpen = false;
      _selectedPlatform = null;
      _isStreamFullscreen = false;
      _currentCameraController = null;
      _followPlatform = false;
    });
  }

  void _onToggleFullscreen(SharedCameraStreamController? cameraController, bool takeOwnership) {
    setState(() {
      // Take ownership of the camera controller when going fullscreen
      _currentCameraController = cameraController;
      _isStreamFullscreen = !_isStreamFullscreen;
    });
  }

  void _onCameraControllerCreated(SharedCameraStreamController controller) {
    // Take ownership of the camera controller as soon as it's created
    _currentCameraController = controller;
  }

  void _disposeCurrentCameraController() {
    if (_currentCameraController != null) {
      // Add delay to allow GL context cleanup
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          _currentCameraController?.dispose();
        } catch (e) {
          debugPrint('Error disposing camera controller in MapTabPage: $e');
        }
      });
    }
  }

  @override
  void dispose() {
    // Dispose camera controller when page is disposed (navigation away)
    _disposeCurrentCameraController();
    super.dispose();
  }

  void _onOpenPlatformListDrawer() {
    // Close platform info drawer when opening platform list
    if (_isDrawerOpen) {
      _onCloseDrawer();
    }
    
    setState(() {
      _isPlatformListDrawerOpen = true;
    });
  }

  void _onClosePlatformListDrawer() {
    setState(() {
      _isPlatformListDrawerOpen = false;
      _shouldClosePlatformListDrawer = false; // Reset the trigger
    });
  }

  void _onPlatformSelectedFromList(String platformId) {
    // Dispose any existing camera controller before selecting a new platform
    if (_currentCameraController != null) {
      _disposeCurrentCameraController();
      _currentCameraController = null;
    }
    
    // Focus on the platform, close the platform list drawer and open the platform info drawer
    setState(() {
      _focusPlatformId = platformId;
      _followPlatform =
          true; // Enable platform following when selected from list
      // We'll get the platform object when _onPlatformSelected is called by the map widget
      _isDrawerOpen = true;
      _isStreamFullscreen = false;
      _isPlatformListDrawerOpen = false;
    });

    // Reset focus platform ID after a short delay to allow for re-focusing
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _focusPlatformId = null;
        });
      }
    });
  }

  void _onMapTapped() {
    // Close platform info drawer when map is tapped
    if (_isDrawerOpen) {
      _onCloseDrawer();
    }
    
    // Disable platform following when map is tapped
    if (_followPlatform) {
      setState(() {
        _followPlatform = false;
      });
    }

    // Close platform list drawer when map is tapped
    if (_isPlatformListDrawerOpen) {
      // Trigger the close animation
      setState(() {
        _shouldClosePlatformListDrawer = true;
      });
    }

    // Close plan list drawer when map is tapped
    if (_isPlanListDrawerOpen) {
      setState(() {
        _shouldClosePlanListDrawer = true;
      });
    }

    // Close mission list drawer when map is tapped
    if (_isMissionListDrawerOpen) {
      setState(() {
        _shouldCloseMissionListDrawer = true;
      });
    }
  }

  void _onOpenTeamCommands() {
    // Close platform info drawer when opening team commands
    if (_isDrawerOpen) {
      _onCloseDrawer();
    }
    
    setState(() {
      _isTeamCommandsOpen = true;
    });
  }

  void _onCloseTeamCommands() {
    setState(() {
      _isTeamCommandsOpen = false;
    });
  }

  void _onOpenPlanListDrawer() {
    // Close platform info drawer when opening plan list
    if (_isDrawerOpen) {
      _onCloseDrawer();
    }
    
    setState(() {
      _isPlanListDrawerOpen = true;
    });
  }

  void _onClosePlanListDrawer() {
    setState(() {
      _isPlanListDrawerOpen = false;
      _shouldClosePlanListDrawer = false;
    });
  }

  void _onOpenMissionListDrawer() {
    // Close platform info drawer when opening mission list
    if (_isDrawerOpen) {
      _onCloseDrawer();
    }
    
    setState(() {
      _isMissionListDrawerOpen = true;
    });
  }

  void _onCloseMissionListDrawer() {
    setState(() {
      _isMissionListDrawerOpen = false;
      _shouldCloseMissionListDrawer = false;
    });
  }

  void _onMissionSelectedFromList(Mission selectedMission) {
    setState(() {
      _isMissionListDrawerOpen = false;
      _shouldCloseMissionListDrawer = false;
      _focusMission = selectedMission;
    });

    debugPrint("Selected mission: ${selectedMission.teamId}");
  }

  void _onPlanSelectedFromList(Plan selectedPlan) {
    setState(() {
      _isPlanListDrawerOpen = false;
      _shouldClosePlanListDrawer = false;
      // Set the selected plan to be passed to the map widget
      _selectedPlan = selectedPlan;
    });

    debugPrint("Selected plan: ${selectedPlan.planId}");
  }

  void _onPlanFocusedFromList(Plan selectedPlan) {
    setState(() {
      _focusPlan = selectedPlan;
    });

    // Reset focus plan after a short delay to allow for re-focusing
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _focusPlan = null;
        });
      }
    });
  }

  void _onEditModeEntered() {
    setState(() {
      _shouldHideUIElements = true;
    });
  }

  void _onEditModeExited() {
    setState(() {
      _shouldHideUIElements = false;
    });
  }

  void _onPlanDrawerOpened() {
    // Clear external plan data after it's been opened to prevent re-opening
    setState(() {
      _selectedPlan = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map view (no split screen)
          MapWidget(
              onMapTapped: (tapPosition, point) {
                _onMapTapped();
              },
              onPlatformSelected:
                  _onPlatformSelected, // Pass the platform selection callback
              focusPlatformId: _focusPlatformId, // Pass the focus platform ID
              onEditModeEntered: _onEditModeEntered,
              onEditModeExited: _onEditModeExited,
              externalPlanData: _selectedPlan, // Pass external plan data
              onExternalPlanOpened:
                  _onPlanDrawerOpened, // Clear external plan data after use
              focusMission: _focusMission, // Pass mission to focus on
              onMissionSelected: (mission) {
                // Clear the focus request after mission is processed
                setState(() {
                  _focusMission = null;
                });
              },
              focusPlan: _focusPlan, // Pass plan to focus on
              onPlanFocused: (plan) {
                // Clear the focus request after plan is processed
                setState(() {
                  _focusPlan = null;
                });
              }),

          // Platform list button
          if (!_shouldHideUIElements)
            Positioned(
              left: 16,
              top: 16,
              child: SizedBox(
                width: 40,
                height: 40,
                child: FloatingActionButton(
                  heroTag: "platform_list_btn",
                  onPressed: _onOpenPlatformListDrawer,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.list,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

          // Team commands button
          if (!_shouldHideUIElements)
            Positioned(
              left: 16,
              top: 70,
              child: SizedBox(
                width: 40,
                height: 40,
                child: FloatingActionButton(
                  heroTag: "team_commands_btn",
                  onPressed: _onOpenTeamCommands,
                  backgroundColor: AppColors.secondary,
                  child: const Icon(
                    Icons.group,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

          // Plan list button
          if (!_shouldHideUIElements)
            Positioned(
              left: 16,
              top: 124,
              child: SizedBox(
                width: 40,
                height: 40,
                child: FloatingActionButton(
                  heroTag: "plan_list_btn",
                  onPressed: _onOpenPlanListDrawer,
                  backgroundColor: AppColors.logo,
                  child: const Icon(
                    Icons.assignment,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

          // Mission list button
          if (!_shouldHideUIElements)
            Positioned(
              left: 16,
              top: 178,
              child: SizedBox(
                width: 40,
                height: 40,
                child: FloatingActionButton(
                  heroTag: "mission_list_btn",
                  onPressed: _onOpenMissionListDrawer,
                  backgroundColor: AppColors.secondary,
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

          // Platform list drawer (slides from left)
          if (_isPlatformListDrawerOpen)
            PlatformListDrawer(
              onClose: _onClosePlatformListDrawer,
              onPlatformSelected: _onPlatformSelectedFromList,
              shouldClose: _shouldClosePlatformListDrawer,
            ),

          // Plan list drawer (slides from left)
          if (_isPlanListDrawerOpen)
            PlanListDrawer(
              onClose: _onClosePlanListDrawer,
              onPlanSelected: _onPlanSelectedFromList,
              onPlanFocused: _onPlanFocusedFromList,
              shouldClose: _shouldClosePlanListDrawer,
            ),

          // Mission list drawer (slides from left)
          if (_isMissionListDrawerOpen)
            MissionListDrawer(
              onClose: _onCloseMissionListDrawer,
              onMissionSelected: _onMissionSelectedFromList,
              shouldClose: _shouldCloseMissionListDrawer,
            ),

          // Platform info drawer (slides from right when platform is selected)
          if (_isDrawerOpen && _selectedPlatform != null)
            PlatformInfoDrawer(
              platform: _selectedPlatform!, // Pass the entire Platform object
              onClose: _onCloseDrawer,
              onToggleFullscreen: _onToggleFullscreen,
              onCameraControllerCreated: _onCameraControllerCreated,
              isFullscreen: _isStreamFullscreen,
            ),

          // Team commands drawer (slides from left when opened)
          if (_isTeamCommandsOpen)
            TeamCommandsDrawer(
              isVisible: _isTeamCommandsOpen,
              onClose: _onCloseTeamCommands,
            ),

          // Fullscreen camera overlay
          if (_isStreamFullscreen && _selectedPlatform != null)
            CameraStreamDrawer(
              platformId: _selectedPlatform!.platformId,
              isFullscreen: true,
              onClose: () => setState(() {
                _isStreamFullscreen = false;
                // Keep the camera controller alive when exiting fullscreen
              }),
              cameraController: _currentCameraController,
            ),
        ],
      ),
    );
  }
}
