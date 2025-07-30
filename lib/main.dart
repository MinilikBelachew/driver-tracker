import 'package:driver/screens/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/login_page.dart';
import '../providers/theme_provider.dart';

import '../services/native_location_service.dart';
import 'providers/driver_location_provider.dart';
import 'providers/route_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DriverLocationProvider()),
        ChangeNotifierProvider(create: (_) => RouteProvider()),
      ],
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _token;
  int? _driverId;
  String? _driverName;
  bool _isLoadingAuth = true;
  final String _serverUrl =
      'https://driver-cotrolling.onrender.com'; // Ensure this is your correct IP

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // We pass the context here for showing the dialog.
    await _requestPermissions(context);
    await _checkLoginStatus();
  }

  // --- PERMISSION LOGIC UPDATED HERE ---
  Future<void> _requestPermissions(BuildContext context) async {
    // Request notification permission first (for the foreground service)
    await Permission.notification.request();

    // Request location permission
    var status = await Permission.location.request();

    if (status.isDenied) {
      // If the user denies the permission, you can show a rationale and request again.
      // This is optional but good practice.
    }

    // Handle the case where the user has permanently denied the permission.
    if (status.isPermanentlyDenied) {
      if (mounted) {
        await showDialog(
          context: context,
          builder:
              (BuildContext dialogContext) => AlertDialog(
                title: const Text('Location Permission Required'),
                content: const Text(
                  'This app needs location access to track the driver. Please grant the permission in the app settings.',
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                  TextButton(
                    child: const Text('Open Settings'),
                    onPressed: () {
                      openAppSettings();
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ],
              ),
        );
      }
      return; // Stop further permission requests if permanently denied.
    }

    // If location is granted, proceed to request "Always" permission for background tracking.
    if (status.isGranted) {
      await Permission.locationAlways.request();
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final driverId = prefs.getInt('driverId') ?? -1;
    final driverName = prefs.getString('driverName');

    if (token != null && driverId != null && driverName != null) {
      // If logged in, automatically start the service if it's not already running
      await NativeLocationService.startService(
        token: token,
        driverId: driverId,
        serverUrl: _serverUrl,
      );
      setState(() {
        _token = token;
        _driverId = driverId;
        _driverName = driverName;
      });
    }
    if (mounted) {
      setState(() => _isLoadingAuth = false);
    }
  }

  Future<void> _onLoggedIn(
    String token,
    int driverId,
    String driverName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString('token', token),
      prefs.setInt('driverId', driverId),
      prefs.setString('driverName', driverName),
      prefs.setString('serverUrl', _serverUrl),
    ]);

    await NativeLocationService.startService(
      token: token,
      driverId: driverId,
      serverUrl: _serverUrl,
    );

    if (mounted) {
      setState(() {
        _token = token;
        _driverId = driverId;
        _driverName = driverName;
      });
    }
  }

  Future<void> _logout() async {
    await NativeLocationService.stopService();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      setState(() {
        _token = null;
        _driverId = null;
        _driverName = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAuth) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Route Planner',
      themeMode: themeProvider.currentMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.white,
        ),
      ),
          home:
              _token == null
                  ? LoginPage(onLoggedIn: _onLoggedIn, serverUrl: _serverUrl)
                  : MainScreen(
                    token: _token!,
                    driverId: _driverId!,
                    driverName: _driverName!,
                    onLogout: _logout,
                  ),
        );
      },
    );
  }
}
