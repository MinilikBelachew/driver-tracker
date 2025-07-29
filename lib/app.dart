
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'providers/theme_provider.dart';
// import 'providers/auth_provider.dart';
// import 'screens/auth/login_screen.dart';
// import 'screens/main_screen.dart';

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     final authProvider = Provider.of<AuthProvider>(context);

//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Smart Route Planner',
//       themeMode: themeProvider.currentMode,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.blue,
//           brightness: Brightness.light,
//         ),
//         primarySwatch: Colors.blue,
//         brightness: Brightness.light,
//         useMaterial3: true,
//         scaffoldBackgroundColor: Colors.grey[50],
//         appBarTheme: AppBarTheme(
//           elevation: 0,
//           centerTitle: true,
//           backgroundColor: Colors.white,
//           foregroundColor: Colors.black,
//         ),
//       ),
//       darkTheme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.blue,
//           brightness: Brightness.dark,
//         ),
//         brightness: Brightness.dark,
//         useMaterial3: true,
//         scaffoldBackgroundColor: Colors.grey[900],
//         appBarTheme: AppBarTheme(
//           elevation: 0,
//           centerTitle: true,
//           backgroundColor: Colors.grey[850],
//           foregroundColor: Colors.white,
//         ),
//       ),
//       home: authProvider.isAuthenticated ? const MainScreen() : const LoginScreen(),
//     );
//   }
// }