import 'package:augur/ui/utils/app_colors.dart';
import 'package:flutter/material.dart';


class CustomSwitch extends StatefulWidget {
  final VoidCallback? onPressed; // Callback when the switch is pressed
  final bool isSwitched; // Current state of the switch
  final ValueChanged<bool> onChanged; // Callback for state changes

  const CustomSwitch({super.key, this.onPressed, required this.isSwitched, required this.onChanged});

  @override
  CustomSwitchState createState() => CustomSwitchState();
}


class CustomSwitchState extends State<CustomSwitch> {
  //bool isSwitched = false;
  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: () {
        widget.onChanged(!widget.isSwitched);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40.0,
        height: 20.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.0),
          color: widget.isSwitched ? AppColors.primary : AppColors.secondary, // Background color
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeIn,
              left: widget.isSwitched ? 20.0 : 0.0, // Thumb position
              right: widget.isSwitched ? 0.0 : 20.0,
              child: Container(
                width: 20.0,
                height: 20.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white, // Thumb color
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2.0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}