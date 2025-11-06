import 'package:flutter/material.dart';
import 'package:augur/ui/widgets/utility_widgets/circle_fraction_painter.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'dart:math';

class PlatformSelectionWheel extends StatefulWidget {
  final List<String> platformIDs;
  final ValueChanged<String> onPlatformSelected;
  final VoidCallback onClose;

  const PlatformSelectionWheel({
    super.key,
    required this.platformIDs,
    required this.onPlatformSelected,
    required this.onClose,
  });

  @override
  PlatformSelectionWheelState createState() => PlatformSelectionWheelState();
}

class PlatformSelectionWheelState extends State<PlatformSelectionWheel> {
  final double containerSize = 250.0;
  final double buttonSize = 40.0;
  final double radius = 105.0;
  late int numberOfPlatforms = widget.platformIDs.length;
  late double angleCovered;
  late double buttonRadius;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    buttonRadius = (containerSize / 2) - (buttonSize / 2);
    angleCovered = (numberOfPlatforms / 12) * (2 * pi);

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        GestureDetector(
          onTap: widget.onClose,
          child: SizedBox(
            width: containerSize,
            height: containerSize,
            child: CustomPaint(
              painter: CircleFractionPainter(angleCovered),
            ),
          ),
        ),

        // Center label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'Select\nPlatform',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        // Platform selection buttons around the central menu
        for (int i = 0; i < numberOfPlatforms; i++)
          Positioned(
            left: buttonRadius *
                    cos(((i * angleCovered) / numberOfPlatforms - (pi / 2)) +
                        0.2) +
                (buttonRadius),
            top: buttonRadius *
                    sin(((i * angleCovered) / numberOfPlatforms - (pi / 2)) +
                        0.2) +
                (buttonRadius),
            child: _getPlatformButton(i),
          ),
      ],
    );
  }

  Widget _getPlatformButton(int index) {
    final platformName = index < widget.platformIDs.length
        ? widget.platformIDs[index]
        : 'Platform ${index + 1}';

    final isAnyDrone = platformName == 'Any Drone';

    return Tooltip(
      message: platformName,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            widget.onPlatformSelected(widget.platformIDs[index]);
            widget.onClose();
          },
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isAnyDrone ? Colors.orange : AppColors.primary,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isAnyDrone)
                  const Icon(
                    Icons.all_inclusive,
                    color: Colors.white,
                    size: 20,
                  )
                else
                  Image.asset(
                    'assets/icons/drone.png',
                    width: 20,
                    height: 20,
                    color: Colors.white,
                  ),
                const SizedBox(height: 2),
                Text(
                  isAnyDrone ? 'ANY' : '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
