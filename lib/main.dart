import 'package:cutline/ui/screens/login_screen.dart';
import 'package:cutline/ui/screens/signup_screen.dart';
import 'package:cutline/ui/screens/splash_screen.dart';
import 'package:cutline/ui/screens/role_selection_screen.dart';
import 'package:cutline/ui/screens/user/salon_details_screen.dart';
import 'package:cutline/ui/screens/user/salon_gallery_screen.dart';
import 'package:cutline/ui/screens/user/user_home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CutLineApp());
}

class CutLineApp extends StatelessWidget {
  const CutLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CutLine',
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/welcome': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/user-home': (context) => const UserHomeScreen(),
        '/salon-details': (context) =>  SalonDetailsScreen(salonName: ModalRoute.of(context)?.settings.arguments as String? ?? ''),

      },
    );
  }
}