import 'package:flutter/material.dart';
import 'package:augur/pages/main_page.dart';
import 'package:augur/utils/ip_address_field.dart'; 

class LaunchMenu extends StatefulWidget {
  const LaunchMenu({super.key});

  @override
  LaunchMenuState createState() => LaunchMenuState();
}

class LaunchMenuState extends State<LaunchMenu> {
  final TextEditingController _ipController = TextEditingController(text: "127.0.0.1");

  void _confirm() {
    String ip = _ipController.text;

    if (!_validateIP(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid IP")),
      );
      return;
    }

    // Navigate to the main application screen with the entered IP and Port
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainPage(ip: ip),
      ),
    );
  }
   
  bool _validateIP(String ip) {
    List<String> parts = ip.split(".");
    if (parts.length != 4) return false;
    for (var part in parts) {
      int? num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 233, 232, 232),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.1, // Scales to 40% of screen width
                height: MediaQuery.of(context).size.height * 0.25, // Scales to 30% of screen height
                child: Container(
                  width: 150, // Fixed size inside the scalable box
                  height: 205, // Fixed size inside the scalable box
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20), // Rounded corners
                    color: Colors.white.withAlpha(200), // Adjust opacity using alpha (0-255)
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(80), // Shadow with 80/255 opacity
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20), // Ensure corners are rounded
                    child: Image.asset(
                      'assets/augur_logo_flutter.png',
                      fit: BoxFit.cover, // Ensures the image fills the container
                    ),
                  ),
                ),
              ),

              SizedBox(height: 10),

              // App Title Below Icon
              Text(
                "AUGUR",
                style: TextStyle(
                  fontSize: 45,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 30),

              // IP and Port Fields in a Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // IP Address Field (Smaller width)
                  SizedBox(
                    width: 180, // Smaller width
                    child: IPAddressField(
                      controller: _ipController,
                      onSubmitted: (value) => _confirm(),
                    ),
                  )
                ],
              ),
              SizedBox(height: 30),

              // Confirm Button
              ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: TextStyle(fontSize: 18),
                ),
                child: Text("Confirm"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}