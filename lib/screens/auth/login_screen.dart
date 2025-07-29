// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _mdtUsernameController = TextEditingController(); 
//   final _passwordController = TextEditingController();
//   bool _obscurePassword = true;

//   @override
//   void dispose() {
//     _mdtUsernameController.dispose(); // Changed from _emailController
//     _passwordController.dispose();
//     super.dispose();
//   }

//   Future<void> _handleLogin() async {
//     if (_formKey.currentState!.validate()) {
//       final authProvider = context.read<AuthProvider>();
//       final success = await authProvider.login(
//         _mdtUsernameController.text.trim(), // Pass MDT username
//         _passwordController.text,
//       );

//       if (!success && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Invalid MDT Username or password'), // Updated message
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final authProvider = context.watch<AuthProvider>();

//     return Scaffold(
//       backgroundColor: Theme.of(context).colorScheme.surface,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const SizedBox(height: 60),

//               // App Logo and Title
//               Container(
//                 alignment: Alignment.center,
//                 child: Column(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       child: Icon(
//                         Icons.route,
//                         size: 60,
//                         color: Theme.of(context).colorScheme.primary,
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//                     Text(
//                       'Smart Route Planner',
//                       style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                         fontWeight: FontWeight.bold,
//                         color: Theme.of(context).colorScheme.onSurface,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Plan your routes efficiently',
//                       style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//                         color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 60),

//               // Login Form
//               Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     // MDT Username Field
//                     TextFormField(
//                       controller: _mdtUsernameController, // Changed controller
//                       keyboardType: TextInputType.text, // Changed keyboard type
//                       decoration: InputDecoration(
//                         labelText: 'MDT Username', // Changed label
//                         hintText: 'Enter your MDT username', // Changed hint
//                         prefixIcon: const Icon(Icons.person_outline), // Changed icon
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(
//                             color: Theme.of(context).colorScheme.outline,
//                           ),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(
//                             color: Theme.of(context).colorScheme.primary,
//                             width: 2,
//                           ),
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter your MDT username'; // Updated validation message
//                         }
//                         // Removed email-specific validation
//                         return null;
//                       },
//                     ),

//                     const SizedBox(height: 20),

//                     // Password Field
//                     TextFormField(
//                       controller: _passwordController,
//                       obscureText: _obscurePassword,
//                       decoration: InputDecoration(
//                         labelText: 'Password',
//                         hintText: 'Enter your password',
//                         prefixIcon: const Icon(Icons.lock_outlined),
//                         suffixIcon: IconButton(
//                           icon: Icon(
//                             _obscurePassword ? Icons.visibility_off : Icons.visibility,
//                           ),
//                           onPressed: () {
//                             setState(() {
//                               _obscurePassword = !_obscurePassword;
//                             });
//                           },
//                         ),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         enabledBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(
//                             color: Theme.of(context).colorScheme.outline,
//                           ),
//                         ),
//                         focusedBorder: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide(
//                             color: Theme.of(context).colorScheme.primary,
//                             width: 2,
//                           ),
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter your password';
//                         }
//                         if (value.length < 6) {
//                           return 'Password must be at least 6 characters';
//                         }
//                         return null;
//                       },
//                     ),

//                     const SizedBox(height: 12),

//                     // Forgot Password
//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: TextButton(
//                         onPressed: () {
//                           // TODO: Implement forgot password
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(content: Text('Forgot password feature coming soon')),
//                           );
//                         },
//                         child: Text(
//                           'Forgot Password?',
//                           style: TextStyle(
//                             color: Theme.of(context).colorScheme.primary,
//                           ),
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 20),

//                     // Login Button
//                     ElevatedButton(
//                       onPressed: authProvider.isLoading ? null : _handleLogin,
//                       style: ElevatedButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         elevation: 0,
//                       ),
//                       child: authProvider.isLoading
//                           ? const SizedBox(
//                               height: 20,
//                               width: 20,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             )
//                           : const Text(
//                               'Sign In',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 40),

//               // Demo Credentials Info
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(
//                     color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
//                   ),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(
//                           Icons.info_outline,
//                           size: 20,
//                           color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
//                         ),
//                         const SizedBox(width: 8),
//                         Text(
//                           'Demo Login',
//                           style: TextStyle(
//                             fontWeight: FontWeight.w600,
//                             color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Use any MDT username and password combination to login.\nExample: driver_user / password123', // Updated demo credentials
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
