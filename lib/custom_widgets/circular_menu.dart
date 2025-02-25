import 'package:flutter/material.dart';
import 'dart:math';


class CircularMenu extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onDroneSelectionRequested;
  const CircularMenu({super.key, required this.onClose, required this.onDroneSelectionRequested});
  @override
  CircularMenuState createState() => CircularMenuState();
}


class CircularMenuState extends State<CircularMenu> {
  final double radius = 70.0; // Adjust this for the size of the circle
  final int numberOfButtons = 8;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        GestureDetector(
          onTap: widget.onClose,  // Close menu when tapped outside
          child: Container(
            width: 180,  // Size of the circular menu
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
          ),
        ),
        // Central button
        CircleAvatar(
          radius: 30.0,
          backgroundColor: Colors.blue,
          child: ClipOval(
              child: Image.asset(
                'assets/drone.png', 
                width: 40.0,
                height: 40.0,
                //fit: BoxFit.fitWidth,
              ),
          ),
        ),
        // Circular buttons around the central button
        for (int i = 0; i < numberOfButtons; i++)
          Positioned(
            left: radius * cos((i * 2*pi) / numberOfButtons) + radius,
            top: radius * sin((i * 2*pi) / numberOfButtons) + radius,
            child: _getIconButton(i),
          ),
      ],
    );
  }

  // Function to assign different icons for each position
  IconButton _getIconButton(int index) {
    return IconButton(
      icon: Icon(_getIcon(index), size: 20.0, color: Colors.blue),
      onPressed: () {
        if (index == 7) {
          widget.onDroneSelectionRequested();
        } else {
          print('Button $index pressed');
          widget.onClose();  // Close menu after button press
        }
      },
    );
  }

  IconData _getIcon(int index){
    switch (index) {
      case 0:
        return Icons.image;  // Replace with appropriate icon
      case 1:
        return Icons.calendar_today;
      case 2:
        return Icons.search;
      case 3:
        return Icons.settings;
      case 4:
        return Icons.layers;
      case 5:
        return Icons.person;
      case 6:
        return Icons.message;
      case 7:
        return Icons.location_on;
      default:
        return Icons.circle;  // Fallback icon
    }
  }
}