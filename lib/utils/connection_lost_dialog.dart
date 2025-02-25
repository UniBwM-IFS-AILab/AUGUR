import 'package:flutter/material.dart';
import 'ip_address_field.dart'; // Import your IP input field widget

class ConnectionLostDialog extends StatefulWidget {
  final TextEditingController ipController;
  final Future<bool> Function() onReconnect;
  final VoidCallback onOffline;

  const ConnectionLostDialog({
    super.key,
    required this.ipController,
    required this.onReconnect,
    required this.onOffline,
  });

  @override
  ConnectionLostDialogState createState() => ConnectionLostDialogState();
}

class ConnectionLostDialogState extends State<ConnectionLostDialog> {
  bool isConnecting = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Connection to Database Lost"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Please enter the IP address to reconnect:"),
          SizedBox(height: 5),
          IPAddressField(
            controller: widget.ipController,
            onSubmitted: (value) async {
              if (isConnecting) return; // Prevent multiple reconnect attempts
              setState(() => isConnecting = true);

              bool success = await widget.onReconnect();

              setState(() => isConnecting = false);

              if (success) {
                Navigator.of(context).pop(); // Close dialog if connected
              } else {
                setState(() => errorMessage = "Failed to reconnect. Try again.");
              }
            },
          ),
          if (errorMessage.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                errorMessage,
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      actions: [
        // Offline Button
        TextButton(
          onPressed: () {
            if (isConnecting) return;
            widget.onOffline();
            Navigator.of(context).pop(); // Close dialog
          },
          child: Text("Offline"),
        ),

        // Reconnect Button
        TextButton(
          onPressed: isConnecting
              ? null
              : () async {
                  if (isConnecting) return;
                  setState(() => isConnecting = true);

                  bool success = await widget.onReconnect();

                  setState(() => isConnecting = false);

                  if (success) {
                    Navigator.of(context).pop(); // Close dialog if connected
                  } else {
                    setState(() => errorMessage = "Failed to reconnect. Try again.");
                  }
                },
          child: isConnecting
              ? CircularProgressIndicator() // Show loading spinner
              : Text("Reconnect"),
        ),
      ],
    );
  }
}
