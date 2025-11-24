import 'package:cutline/features/owner/screens/owner_home_screen.dart';
import 'package:cutline/features/auth/screens/login_screen.dart';
import 'package:cutline/features/auth/screens/role_selection_screen.dart';
import 'package:cutline/features/auth/screens/signup_screen.dart';
import 'package:cutline/features/user/screens/salon_details_screen.dart';
import 'package:cutline/features/user/screens/user_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() {
  runApp(const CutLineApp());
}

class CutLineApp extends StatelessWidget {
  const CutLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CutLine',
        initialRoute: '/',
        routes: {
          '/': (context) => const OwnerHomeScreen(),
          '/welcome': (context) => const RoleSelectionScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/user-home': (context) => const UserHomeScreen(),
          '/owner-home': (context) => const OwnerHomeScreen(),
          '/salon-details': (context) => SalonDetailsScreen(
                salonName: ModalRoute.of(context)?.settings.arguments as String? ?? '',
              ),
        },
      ),
    );
  }
}
