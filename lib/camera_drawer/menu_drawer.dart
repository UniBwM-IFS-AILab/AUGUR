
import 'package:flutter/material.dart';

class MenuDrawer extends StatefulWidget {
  final List<String> platformNames;
  final Function(int) onPlatformSelected; // Callback parameter
  final int selectedPlatformIndex; // Callback parameter
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
                    'assets/drone.png',
                    height: 32,
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
          ],
        ),
    );
  }


  List<Widget> _buildDroneList() {
    return widget.platformNames.asMap().entries.map((entry) {
      int index = entry.key;
      String droneName = entry.value;

      return TextButton(
        child: Center(child: Text(droneName)),
        onPressed: () => onClickListenerButtons(context, index),
      );
    }).toList();
  }

  void onClickListenerButtons(BuildContext context, int index){
    if(widget.selectedPlatformIndex != index){
      //new drone selected
      widget.onPlatformSelected(index); // Call the callback
    }
    Scaffold.of(context).closeDrawer();
  }
}
