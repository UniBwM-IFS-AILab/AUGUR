import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/pages/app_shell.dart';

class MainPage extends ConsumerStatefulWidget {
  final String ip;
  const MainPage({super.key, required this.ip});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  @override
  Widget build(BuildContext context) {
    // Simply return the app shell - speech service is initialized in main()
    return AppShell(ipAddress: widget.ip);
  }
}
