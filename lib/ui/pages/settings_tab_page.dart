import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:augur/ui/utils/app_colors.dart';
import 'package:augur/ui/widgets/utility_widgets/switch_button.dart';
import 'package:augur/state/redis_provider.dart';
import 'package:augur/state/settings_provider.dart';
import 'package:augur/core/services/default_settings_service.dart';

class SettingsTabPage extends ConsumerStatefulWidget {
  const SettingsTabPage({super.key});

  @override
  ConsumerState<SettingsTabPage> createState() => _SettingsTabPageState();
}

class _SettingsTabPageState extends ConsumerState<SettingsTabPage> {
  late TextEditingController _defaultIpController;
  final DefaultSettingsService _settingsService = DefaultSettingsService();

  @override
  void initState() {
    super.initState();
    _defaultIpController = TextEditingController();
    _loadDefaultIp();
  }

  @override
  void dispose() {
    _defaultIpController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultIp() async {
    final defaultIp = await _settingsService.getDefaultIp();
    setState(() {
      _defaultIpController.text = defaultIp;
    });
  }

  Future<void> _setDefaultIp() async {
    final newIp = _defaultIpController.text.trim();

    if (!DefaultSettingsService.isValidIp(newIp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid IP address format'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _settingsService.setDefaultIp(newIp);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Default IP updated to $newIp'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save default IP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Settings
            _buildSettingsSection(
              title: 'Connection Settings',
              icon: Icons.settings_ethernet,
              children: [
                _buildDefaultIpTile(),
              ],
            ),

            const SizedBox(height: 16),

            // Map Settings
            _buildSettingsSection(
              title: 'Map Settings',
              icon: Icons.map,
              children: [
                _buildSettingsTile(
                  title: 'Satellite View',
                  subtitle: 'Use satellite imagery instead of street map',
                  trailing: CustomSwitch(
                    isSwitched: settings.isSatelliteMode,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setSatelliteMode(value);
                    },
                  ),
                ),
                _buildSettingsTile(
                  title: 'Show Trajectories',
                  subtitle: 'Display platform movement trajectories',
                  trailing: CustomSwitch(
                    isSwitched: settings.isTrajectoryMode,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setTrajectoryMode(value);
                      ref
                          .read(redisClientProvider.notifier)
                          .setTrajectoryMode(value);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Voice & Audio Settings
            _buildSettingsSection(
              title: 'Voice & Audio',
              icon: Icons.mic,
              children: [
                _buildSettingsTile(
                  title: 'Voice Control',
                  subtitle: 'Enable voice commands for platform control',
                  trailing: CustomSwitch(
                    isSwitched: settings.isVoiceControlEnabled,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setVoiceControlEnabled(value);
                    },
                  ),
                ),
                _buildSettingsTile(
                  title: 'Voice Feedback',
                  subtitle: 'Receive audio feedback for commands',
                  trailing: CustomSwitch(
                    isSwitched: true,
                    onChanged: (value) {
                      // TODO: Implement voice feedback setting
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Display Settings
            _buildSettingsSection(
              title: 'Display Settings',
              icon: Icons.display_settings,
              children: [
                _buildSettingsTile(
                  title: 'Theme',
                  subtitle: 'Choose app theme',
                  trailing:
                      const Text('Light', style: TextStyle(color: Colors.grey)),
                  onTap: () {
                    _showThemeDialog();
                  },
                ),
                _buildSettingsTile(
                  title: 'UI Scale',
                  subtitle: 'Adjust interface scaling',
                  trailing:
                      const Text('100%', style: TextStyle(color: Colors.grey)),
                  onTap: () {
                    _showScaleDialog();
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // About Section
            _buildSettingsSection(
              title: 'About',
              icon: Icons.info,
              children: [
                _buildSettingsTile(
                  title: 'Version',
                  subtitle: 'AUGUR v1.0.0',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showAboutDialog();
                  },
                ),
                _buildSettingsTile(
                  title: 'Licenses',
                  subtitle: 'View open source licenses',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showLicensePage(context: context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIpTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Default IP Address',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Set the default IP address for connecting to AUGUR systems',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _defaultIpController,
                cursorColor: AppColors.secondary,
                style: TextStyle(color: AppColors.primary),
                decoration: InputDecoration(
                  labelText: "Default IP Address",
                  labelStyle: TextStyle(color: AppColors.primary),
                  border: const OutlineInputBorder(),
                  hintStyle: TextStyle(color: AppColors.primary),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.secondary, width: 2.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) => _setDefaultIp(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _setDefaultIp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Light'),
              leading: const Icon(Icons.light_mode),
            ),
            ListTile(
              title: const Text('Dark'),
              leading: const Icon(Icons.dark_mode),
            ),
            ListTile(
              title: const Text('System'),
              leading: const Icon(Icons.settings),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showScaleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('UI Scale'),
        content: const Text('Adjust interface scaling (requires restart):'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'AUGUR',
      applicationVersion: '1.0.0',
      applicationIcon:
          Image.asset('assets/icons/augur_logo.png', width: 48, height: 48),
      children: [
        const Text('Advanced Unmanned Ground & Aerial Robotics'),
        const SizedBox(height: 8),
        const Text('A comprehensive platform for drone and robotics control.'),
      ],
    );
  }
}
