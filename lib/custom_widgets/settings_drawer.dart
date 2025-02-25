
import 'package:flutter/material.dart';
import 'package:augur/custom_widgets/switch_button.dart';

class SettingsDrawer extends StatefulWidget {
  final bool isSatelliteOn; 
  final bool isTrajectoryOn; 
  final Function(bool) onSatelliteSwitchToggled; 
  final Function(bool) onTrajectorySwitchToggled; 
  const SettingsDrawer({super.key, required this.isSatelliteOn, required this.onSatelliteSwitchToggled, required this.isTrajectoryOn, required this.onTrajectorySwitchToggled});
  @override
  SettingsDrawerState createState() => SettingsDrawerState();
}

class SettingsDrawerState extends State<SettingsDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: ListView(
          children: <Widget>[
            const SizedBox(
              height: 60, // Adjust the height as per your requirement
              child: DrawerHeader(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18, // Adjust font size as per your needs
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spread out the children
                  children: [
                    const Expanded(
                      child: Center(
                        child: Text("Use Satellite Map"),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: CustomSwitch(
                          isSwitched: widget.isSatelliteOn,
                          onChanged:widget.onSatelliteSwitchToggled,
                        ), // Your custom switch widget
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spread out the children
                  children: [
                    const Expanded(
                      child: Center(
                        child: Text("Show Trajectories"),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: CustomSwitch(
                          isSwitched: widget.isTrajectoryOn,
                          onChanged:widget.onTrajectorySwitchToggled,
                        ), // Your custom switch widget
                      ),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
    );
  }

  void onClickListenerButtons(BuildContext context){
    Scaffold.of(context).closeDrawer();
  }
}
