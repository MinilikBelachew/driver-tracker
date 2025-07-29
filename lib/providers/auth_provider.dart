// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../services/auth_service.dart'; // Import the new AuthService

// class AuthProvider extends ChangeNotifier {
//   final AuthService _authService = AuthService(); // Instantiate AuthService

//   bool _isAuthenticated = false;
//   String? _driverId; // New: Store driver ID
//   String? _mdtUsername; // New: Store MDT Username
//   String? _driverName; // New: Store driver's name
//   String? _token; // New: Store JWT token
//   bool _isLoading = false;

//   bool get isAuthenticated => _isAuthenticated;
//   String? get driverId => _driverId;
//   String? get mdtUsername => _mdtUsername;
//   String? get driverName => _driverName;
//   String? get token => _token;
//   bool get isLoading => _isLoading;

//   AuthProvider() {
//     _loadAuthState();
//   }

//   /// Loads the authentication state from SharedPreferences on app startup.
//   Future<void> _loadAuthState() async {
//     final prefs = await SharedPreferences.getInstance();
//     _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
//     _driverId = prefs.getString('driverId');
//     _mdtUsername = prefs.getString('mdtUsername');
//     _driverName = prefs.getString('driverName');
//     _token = prefs.getString('token');
//     notifyListeners();
//   }

//   /// Attempts to log in the driver using the provided MDT username and password.
//   /// Returns true if login is successful, false otherwise.
//   Future<bool> login(String mdtUsername, String password) async {
//     _isLoading = true;
//     notifyListeners();

//     try {
//       final result = await _authService.loginDriver(mdtUsername, password);
      
//       final prefs = await SharedPreferences.getInstance();

//       _isAuthenticated = true;
//       _token = result['token'];
//       _driverId = result['driverInfo']['id'];
//       _mdtUsername = result['driverInfo']['mdtUsername'];
//       _driverName = result['driverInfo']['name'];

//       // Save to SharedPreferences
//       await prefs.setBool('isAuthenticated', true);
//       await prefs.setString('token', _token!);
//       await prefs.setString('driverId', _driverId!);
//       await prefs.setString('mdtUsername', _mdtUsername!);
//       await prefs.setString('driverName', _driverName!);
      
//       _isLoading = false;
//       notifyListeners();
//       return true;
//     } catch (e) {
//       // Handle login errors (e.g., invalid credentials, network issues)
//       print('Login failed: $e');
//       _isAuthenticated = false; // Ensure state is false on failure
//       _token = null;
//       _driverId = null;
//       _mdtUsername = null;
//       _driverName = null;

//       _isLoading = false;
//       notifyListeners();
//       return false;
//     }
//   }

//   /// Logs out the current driver and clears all stored authentication data.
//   Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
    
//     _isAuthenticated = false;
//     _driverId = null;
//     _mdtUsername = null;
//     _driverName = null;
//     _token = null;
    
//     // Clear SharedPreferences
//     await prefs.remove('isAuthenticated');
//     await prefs.remove('token');
//     await prefs.remove('driverId');
//     await prefs.remove('mdtUsername');
//     await prefs.remove('driverName');
    
//     notifyListeners();
//   }
// }
