

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/driver_location_provider.dart';

// -------------- Settings Page --------------
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final driverProvider = context.read<DriverLocationProvider>();
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: ListView(
        children: [
          SettingsSectionTitle(title: "Appearance"),
          SwitchListTile(
            title: const Text("Dark Mode"),
            subtitle: Text("Switch between light and dark theme"),
            value: themeProvider.isDark,
            onChanged: (_) => themeProvider.toggle(),
            secondary: Icon(
              themeProvider.isDark ? Icons.dark_mode : Icons.light_mode,
            ),
          ),

          SettingsSectionTitle(title: "Location & Navigation"),
          SwitchListTile(
            title: const Text("Live Location Tracking"),
            subtitle: Text("Enable real-time location updates"),
            value: driverProvider.tracking,
            secondary: Icon(Icons.location_on),
            onChanged: (val) {
              if (val) {
                driverProvider.startTracking();
              } else {
                driverProvider.stopTracking();
              }
            },
          ),
          ListTile(
            title: Text("Map Type"),
            subtitle: Text("Standard"),
            leading: Icon(Icons.map),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          ListTile(
            title: Text("Navigation Settings"),
            subtitle: Text("Route preferences, avoid tolls, etc."),
            leading: Icon(Icons.navigation),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),

          SettingsSectionTitle(title: "Notifications"),
          SwitchListTile(
            title: const Text("Push Notifications"),
            subtitle: Text("Receive alerts for new passengers"),
            value: true,
            secondary: Icon(Icons.notifications),
            onChanged: (val) {},
          ),
          SwitchListTile(
            title: const Text("SMS Notifications"),
            subtitle: Text("Get text messages for important updates"),
            value: false,
            secondary: Icon(Icons.sms),
            onChanged: (val) {},
          ),

          SettingsSectionTitle(title: "About"),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("App Version"),
            subtitle: const Text("2.0.0"),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text("Privacy Policy"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text("Terms of Service"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text("Help & Support"),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class SettingsSectionTitle extends StatelessWidget {
  final String title;

  const SettingsSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
