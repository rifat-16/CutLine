import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cutline/features/admin/providers/admin_auth_provider.dart';
import 'package:cutline/features/admin/screens/admin_home_screen.dart';
import 'package:cutline/features/admin/screens/admin_login_screen.dart';

class AdminAuthGateScreen extends StatelessWidget {
  const AdminAuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminAuthProvider>(
      builder: (context, auth, _) {
        if (auth.isCheckingClaims) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (auth.isAuthenticated && auth.isSuperadmin) {
          return const AdminHomeScreen();
        }

        return const AdminLoginScreen();
      },
    );
  }
}
