import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final String _baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'http://localhost:3001';

  Future<Map<String, dynamic>> loginDriver(String mdtUsername, String password) async {
    final url = Uri.parse('$_baseUrl/api/v1/drivers/login');
    
    print('AuthService: Attempting to log in with URL: $url'); // Add this
    print('AuthService: Sending MDT Username: $mdtUsername'); 
    print('AuthService: Sending MDT Username: $password');// Add this (be careful not to log sensitive passwords in production)
    
    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'mdtUsername': mdtUsername,
          'password': password,
        }),
      );

      print('AuthService: Response status code: ${response.statusCode}'); // Add this
      print('AuthService: Response body: ${response.body}'); // Add this

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('AuthService: Login successful. Response data: $responseData'); // Add this
        return {
          'token': responseData['token'],
          'driverInfo': responseData['driver'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        print('AuthService: Login failed with status ${response.statusCode}. Error: ${errorData['message']}'); // Add this
        throw Exception(errorData['message'] ?? 'Failed to log in driver');
      }
    } catch (e) {
      print('AuthService: Error during driver login: $e'); // This print is already there, make sure to check its output
      rethrow;
    }
  }
}




// import 'dart:convert';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:http/http.dart' as http;

// class AuthService {
//   // Base URL for your backend API, loaded from .env
//   // IMPORTANT: Ensure your .env file has BACKEND_BASE_URL set to your computer's LOCAL IP address (e.g., http://192.168.1.X:3001)
//   final String _baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'http://localhost:3001'; 

//   /// Logs in a driver using MDT username and password.
//   /// Returns a Map containing 'token' and 'driverInfo' on success.
//   /// Throws an exception on failure.
//   Future<Map<String, dynamic>> loginDriver(String mdtUsername, String password) async {
//     // Ensure the URL is correct for your backend's API versioning if you have /api/v1/
//     final url = Uri.parse('$_baseUrl/api/v1/drivers/login'); 
    
//     try {
//       final response = await http.post(
//         url,
//         headers: <String, String>{
//           'Content-Type': 'application/json; charset=UTF-8',
//         },
//         body: jsonEncode(<String, String>{
//           'mdtUsername': mdtUsername,
//           'password': password,
//         }),
//       );

//       if (response.statusCode == 200) {
//         // Successful login
//         final responseData = jsonDecode(response.body);
//         return {
//           'token': responseData['token'],
//           'driverInfo': responseData['driver'], // Assuming your backend returns a 'driver' object
//         };
//       } else {
//         // Login failed
//         final errorData = jsonDecode(response.body);
//         throw Exception(errorData['message'] ?? 'Failed to log in driver');
//       }
//     } catch (e) {
//       // Handle network errors or other exceptions
//       print('Error during driver login: $e');
//       rethrow; // Re-throw to be caught by the AuthProvider
//     }
//   }

//   // You can add other authentication-related methods here, e.g., registerDriver, fetchDriverProfile, etc.
// }
