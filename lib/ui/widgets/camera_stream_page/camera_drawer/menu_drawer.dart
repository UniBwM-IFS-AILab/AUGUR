
import 'package:augur/ui/utils/app_colors.dart';
import 'package:flutter/material.dart';

class MenuDrawer extends StatefulWidget {
  final List<String> platformNames;
  final Function(int) onPlatformSelected;
  final int selectedPlatformIndex;
  const MenuDrawer({super.key, required this.platformNames, required this.onPlatformSelected, required this.selectedPlatformIndex});
  @override
  MenuDrawerState createState() => MenuDrawerState();
}

class MenuDrawerState extends State<MenuDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/drone.png',
                    height: 32,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select Drone',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ..._buildDroneList(),
            TextButton(
              style: ButtonStyle(
              foregroundColor: WidgetStateProperty.all(AppColors.primary), // Text colorver color
              padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return AppColors.secondary.withAlpha(50); // Light blue hover effect
                  }
                  if (states.contains(WidgetState.pressed)) {
                    return AppColors.secondary.withAlpha(100); // Darker blue when pressed
                  }
                  return null;
                }), // Padding for better touch
              ),
              child: Center(child: Text("Cancel", style: TextStyle(
                color: AppColors.secondary
              ))),
              onPressed: () => onClickListenerButtons(context, -1),
            )
          ],
        ),
    );
  }


  List<Widget> _buildDroneList() {
    return widget.platformNames.asMap().entries.map((entry) {
      int index = entry.key;
      String droneName = entry.value;

      return TextButton(
        style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(AppColors.primary), // Text colorver color
            padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return AppColors.secondary.withAlpha(50); // Light blue hover effect
              }
              if (states.contains(WidgetState.pressed)) {
                return AppColors.secondary.withAlpha(100); // Darker blue when pressed
              }
              return null;
            }), // Padding for better touch
          ),
        child: Center(child: Text(droneName, style: TextStyle(
          color: AppColors.primary
        ))),
        onPressed: () => onClickListenerButtons(context, index),
      );
    }).toList();
  }

  void onClickListenerButtons(BuildContext context, int index){
    if(widget.selectedPlatformIndex != index){
      widget.onPlatformSelected(index);
    }
    Scaffold.of(context).closeDrawer();
  }
}
