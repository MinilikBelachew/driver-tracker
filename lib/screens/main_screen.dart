import 'package:flutter/material.dart';
import '../../screens/home/home_map_screen.dart';
import '../../screens/passengers/passenger_list_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/tracking_page/tracking_page.dart';


class MainScreen extends StatefulWidget {

  final String token;
  final int driverId;
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

  // Use 'late' to declare that this will be initialized later.
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState(); // Always call the parent's initState first!

    // Now, 'widget' is available, so you can safely initialize the list.
    _pages = [
      TrackingMapContent(
        token: widget.token,
        driverId: widget.driverId,
        driverName: widget.driverName,
      ),
      const HomeMapPage(),
      const PassengerListPage(),
      const ProfilePage(),
      const SettingsPage(),
    ];
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Routes'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Passengers'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Location'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}