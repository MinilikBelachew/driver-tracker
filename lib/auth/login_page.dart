// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:io';
// import 'dart:async';

// class LoginPage extends StatefulWidget {
//   final Function(String, String, String) onLoggedIn;
//   final String serverUrl;

//   const LoginPage({
//     super.key,
//     required this.onLoggedIn,
//       required this.serverUrl,
//   });

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final _userCtrl = TextEditingController();
//   final _passCtrl = TextEditingController();
//   bool _isLoading = false;
//   bool _obscurePassword = true;
//   final _formKey = GlobalKey<FormState>();

//   Future<void> _login() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
//     setState(() => _isLoading = true);
//     try {
//       final response = await http.post(
//         Uri.parse('${widget.serverUrl}/drivers/login'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'mdtUsername': _userCtrl.text.trim(),
//           'password': _passCtrl.text,
//         }),
//       ).timeout(const Duration(seconds: 15));

//       if (!mounted) return;
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         widget.onLoggedIn(data['token'], data['driverId'], data['name']);
//       } else {
//         final error = jsonDecode(response.body)['error'] ?? 'Login failed';
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(error),
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//         );
//       }
//     } on SocketException {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Network error. Please check connection.'),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//     } on TimeoutException {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Connection timeout.'),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('An unexpected error occurred.'),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Theme.of(context).colorScheme.primaryContainer,
//               Theme.of(context).colorScheme.secondaryContainer,
//             ],
//           ),
//         ),
//         child: Center(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(24.0),
//             child: Card(
//               elevation: 8,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(24.0),
//                 child: Form(
//                   key: _formKey,
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         Icons.person_pin_circle,
//                         size: 72,
//                         color: Theme.of(context).colorScheme.primary,
//                       ),
//                       const SizedBox(height: 24),
//                       Text(
//                         'Driver Login',
//                         style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                               fontWeight: FontWeight.bold,
//                             ),
//                       ),
//                       const SizedBox(height: 32),
//                       TextFormField(
//                         controller: _userCtrl,
//                         decoration: InputDecoration(
//                           labelText: 'MDT Username',
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           prefixIcon: const Icon(Icons.person_outline),
//                           contentPadding: const EdgeInsets.symmetric(
//                               horizontal: 16, vertical: 14),
//                         ),
//                         validator: (value) =>
//                             (value == null || value.isEmpty)
//                                 ? 'Please enter username'
//                                 : null,
//                       ),
//                       const SizedBox(height: 20),
//                       TextFormField(
//                         controller: _passCtrl,
//                         obscureText: _obscurePassword,
//                         decoration: InputDecoration(
//                           labelText: 'Password',
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           prefixIcon: const Icon(Icons.lock_outline),
//                           suffixIcon: IconButton(
//                             icon: Icon(
//                               _obscurePassword
//                                   ? Icons.visibility_off
//                                   : Icons.visibility,
//                             ),
//                             onPressed: () {
//                               setState(() {
//                                 _obscurePassword = !_obscurePassword;
//                               });
//                             },
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                               horizontal: 16, vertical: 14),
//                         ),
//                         validator: (value) =>
//                             (value == null || value.isEmpty)
//                                 ? 'Please enter password'
//                                 : null,
//                       ),
//                       const SizedBox(height: 32),
//                       SizedBox(
//                         width: double.infinity,
//                         child: _isLoading
//                             ? const Center(child: CircularProgressIndicator())
//                             : ElevatedButton(
//                                 onPressed: _login,
//                                 style: ElevatedButton.styleFrom(
//                                   padding: const EdgeInsets.symmetric(vertical: 16),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                 ),
//                                 child: const Text(
//                                   'LOGIN',
//                                   style: TextStyle(fontSize: 16),
//                                 ),
//                               ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }