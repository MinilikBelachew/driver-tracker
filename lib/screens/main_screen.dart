import 'package:flutter/material.dart';
import '../../screens/home/home_map_screen.dart';
import '../../screens/passengers/passenger_list_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/settings/settings_screen.dart';
// Import the renamed tracking page
import '../../screens/tracking_page/tracking_page.dart'; // Corrected import path

class MainScreen extends StatefulWidget {
  final String token;
  final String driverId;
  final String driverName;
  final VoidCallback onLogout;

  const MainScreen({
    super.key,
    required this.token,
    required this.driverId,
    required this.driverName,
    required this.onLogout,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      TrackingPage(
        // Using the renamed widget here
        token: widget.token,
        driverId: widget.driverId,
        driverName: widget.driverName,
      ),
      HomeMapPage(driverId: widget.driverId),
      PassengerListPage(driverId: widget.driverId),
      ProfilePage(
        token: widget.token,
        driverId: widget.driverId,
        driverName: widget.driverName,
        onLogout: widget.onLogout,
      ),
      const SettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(_selectedIndex),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.location_on),
            label: 'Tracking',
          ), // Changed label
          NavigationDestination(
            icon: Icon(Icons.map),
            label: 'Home Map',
          ), // Assuming this is your original map
          NavigationDestination(icon: Icon(Icons.people), label: 'Passengers'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Driver Tracking';
      case 1:
        return 'Home Map';
      case 2:
        return 'Passengers';
      case 3:
        return 'My Profile';
      case 4:
        return 'Settings';
      default:
        return 'Driver App';
    }
  }
}
