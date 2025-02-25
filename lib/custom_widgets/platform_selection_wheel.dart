import 'package:flutter/material.dart';
import 'package:augur/custom_widgets/circle_fraction_painter.dart';

import 'dart:math';

class PlatformSelectionWheel extends StatefulWidget {
  final int numberOfPlatforms;  // Number of drones to display
  final ValueChanged<int> onPlatformSelected;  // Callback to return the selected drone number
  final VoidCallback onClose; // Callback to close the menu

  const PlatformSelectionWheel({
    super.key,
    required this.numberOfPlatforms,
    required this.onPlatformSelected,
    required this.onClose,
  });

  @override
  PlatformSelectionWheelState createState() => PlatformSelectionWheelState();
}

class PlatformSelectionWheelState extends State<PlatformSelectionWheel> {
  final double containerSize = 250.0;  // Size of the container
  final double buttonSize = 40.0;  // Assuming button is 40x40
  final double radius = 105.0; // Adjust this for the size of the outer circle
  late double angleCovered;
  late double buttonRadius;


  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    buttonRadius = (containerSize / 2) - (buttonSize / 2);  
    angleCovered = (widget.numberOfPlatforms / 12) * (2 * pi);  
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        GestureDetector(
          onTap: widget.onClose, // Close menu when tapped outside
          child: SizedBox(
            width: containerSize,  // Size of the selection wheel
            height: containerSize,
            child: CustomPaint(
              painter: CircleFractionPainter(angleCovered),  
            ),
          ),
        ),
        //Platform selection buttons around the central menu
        for (int i = 0; i < widget.numberOfPlatforms; i++)
          Positioned(
            // Position each button based on the angle and fraction of the circle
            left: buttonRadius * cos(((i * angleCovered) / widget.numberOfPlatforms - (pi / 2)) + 0.2) +  (buttonRadius ),
            top: buttonRadius * sin(((i * angleCovered) / widget.numberOfPlatforms - (pi / 2)) + 0.2) + (buttonRadius ),
            child: _getPlatformButton(i),
          ),
      ],
    );
  }

  // Function to assign drone icons dynamically
  IconButton _getPlatformButton(int index) {
    return IconButton(
      icon: Image.asset(
        'assets/drone.png', 
        width: 30.0,
        height: 30.0,
      ),// Icon for drone
      onPressed: () {
        print('Platform $index selected');
        widget.onPlatformSelected(index);  // Return the selected drone index
        widget.onClose();  // Close the selection menu
      },
    );
  }
}
