import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';

// User screens
import '../screens/user/user_home_screen.dart';
import '../screens/user/salon_details_screen.dart';
import '../screens/user/booking_screen.dart';
import '../screens/user/queue_status_screen.dart';

// Owner screens
import '../screens/owner/owner_dashboard.dart';
import '../screens/owner/salon_setup_screen.dart';
import '../screens/owner/add_barber_screen.dart';
import '../screens/owner/manage_barbers_screen.dart';
import '../screens/owner/manage_queue_screen.dart';

// Barber screens
import '../screens/barber/barber_dashboard.dart';
import '../screens/barber/barber_queue_screen.dart';
import '../screens/barber/barber_profile_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String signup = '/signup';

  // User routes
  static const String userHome = '/user-home';
  static const String salonDetails = '/salon-details';
  static const String booking = '/booking';
  static const String queueStatus = '/queue-status';

  // Owner routes
  static const String ownerDashboard = '/owner-dashboard';
  static const String salonSetup = '/salon-setup';
  static const String addBarber = '/add-barber';
  static const String manageBarbers = '/manage-barbers';
  static const String manageQueue = '/manage-queue';

  // Barber routes
  static const String barberDashboard = '/barber-dashboard';
  static const String barberQueue = '/barber-queue';
  static const String barberProfile = '/barber-profile';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splash: (context) => const SplashScreen(),
      roleSelection: (context) => const RoleSelectionScreen(),
      login: (context) => const LoginScreen(),
      signup: (context) => const SignupScreen(),

      // User routes
      userHome: (context) => const UserHomeScreen(),
      salonDetails: (context) {
        final salonId = ModalRoute.of(context)!.settings.arguments as String;
        return SalonDetailsScreen(salonId);
      },
      booking: (context) {
        final arguments = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return BookingScreen(arguments: arguments);
      },
      queueStatus: (context) => const QueueStatusScreen(),

      // Owner routes
      ownerDashboard: (context) => const OwnerDashboard(),
      salonSetup: (context) => const SalonSetupScreen(),
      addBarber: (context) => const AddBarberScreen(),
      manageBarbers: (context) => const ManageBarbersScreen(),
      manageQueue: (context) => const ManageQueueScreen(),

      // Barber routes
      barberDashboard: (context) => const BarberDashboard(),
      barberQueue: (context) => const BarberQueueScreen(),
      barberProfile: (context) => const BarberProfileScreen(),
    };
  }
}
