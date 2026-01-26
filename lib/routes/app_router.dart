import 'package:cutline/features/auth/models/user_role.dart';
import 'package:cutline/features/auth/screens/forgot_password_screen.dart';
import 'package:cutline/features/auth/screens/login_screen.dart';
import 'package:cutline/features/auth/screens/role_selection_screen.dart';
import 'package:cutline/features/auth/screens/session_restore_screen.dart';
import 'package:cutline/features/auth/screens/signup_screen.dart';
import 'package:cutline/features/auth/screens/splash_screen.dart';
import 'package:cutline/features/barber/screens/barber_home_screen.dart';
import 'package:cutline/features/barber/screens/barber_notification_screen.dart';
import 'package:cutline/features/barber/screens/barber_profile_screen.dart';
import 'package:cutline/features/barber/screens/barber_edit_profile_screen.dart';
import 'package:cutline/features/barber/screens/work_history_screen.dart';
import 'package:cutline/features/owner/screens/barbers_screen.dart';
import 'package:cutline/features/owner/screens/booking_detail_screen.dart'
    as owner_booking;
import 'package:cutline/features/owner/screens/booking_requests_screen.dart';
import 'package:cutline/features/owner/screens/bookings_screen.dart';
import 'package:cutline/features/owner/screens/dashboard_screen.dart';
import 'package:cutline/features/owner/screens/edit_salon_information.dart';
import 'package:cutline/features/owner/screens/manage_queue_screen.dart';
import 'package:cutline/features/owner/screens/manage_services_screen.dart';
import 'package:cutline/features/owner/screens/notifications_screen.dart';
import 'package:cutline/features/owner/screens/owner_home_screen.dart';
import 'package:cutline/features/owner/screens/owner_profile_screen.dart';
import 'package:cutline/features/owner/screens/salon_setup_screen.dart';
import 'package:cutline/features/owner/screens/settings_screen.dart';
import 'package:cutline/features/owner/screens/working_hours_screen.dart';
import 'package:cutline/features/user/screens/user_booking_receipt_screen.dart'
    as user_booking;
import 'package:cutline/features/user/screens/user_booking_screen.dart';
import 'package:cutline/features/user/screens/booking_summary_screen.dart';
import 'package:cutline/features/user/screens/chats_screen.dart';
import 'package:cutline/features/user/screens/favorite_salon_screen.dart';
import 'package:cutline/features/user/screens/my_booking_screen.dart';
import 'package:cutline/features/user/screens/notification_screen.dart';
import 'package:cutline/features/user/screens/salon_details_screen.dart';
import 'package:cutline/features/user/screens/salon_gallery_screen.dart';
import 'package:cutline/features/user/screens/salon_map_screen.dart';
import 'package:cutline/features/user/screens/user_home_screen.dart';
import 'package:cutline/features/user/screens/user_edit_profile_screen.dart';
import 'package:cutline/features/user/screens/user_profile_screen.dart';
import 'package:cutline/features/user/screens/view_all_salon_services.dart';
import 'package:cutline/features/user/screens/waiting_customer_screen.dart';
import 'package:cutline/features/user/screens/turn_ready_screen.dart';
import 'package:flutter/material.dart';

import '../features/owner/screens/owner_chats_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const roleSelection = '/welcome';
  static const sessionRestore = '/session-restore';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const signup = '/signup';
  static const ownerLogin = '/owner-login';
  static const ownerSignup = '/owner-signup';
  static const barberLogin = '/barber-login';
  static const ownerRedirect = '/owner-redirect'; // internal guard

  static const userHome = '/user-home';
  static const ownerHome = '/owner-home';
  static const barberHome = '/barber-home';

  static const salonDetails = '/salon-details';
  static const salonMap = '/salon-map';
  static const booking = '/booking';
  static const bookingSummary = '/booking-summary';
  static const bookingReceipt = '/booking-receipt';
  static const favoriteSalons = '/favorite-salons';
  static const userNotifications = '/user-notifications';
  static const viewAllServices = '/view-all-services';
  static const salonGallery = '/salon-gallery';
  static const waitingCustomers = '/waiting-customers';
  static const turnReady = '/turn-ready';
  static const myBookings = '/my-bookings';
  static const userChats = '/user-chats';
  static const userProfile = '/user-profile';
  static const userEditProfile = '/user-edit-profile';

  static const ownerBookings = '/owner-bookings';
  static const ownerBookingRequests = '/owner-booking-requests';
  static const ownerManageQueue = '/owner-manage-queue';
  static const ownerManageServices = '/owner-manage-services';
  static const ownerWorkingHours = '/owner-working-hours';
  static const ownerNotifications = '/owner-notifications';
  static const ownerProfile = '/owner-profile';
  static const ownerBarbers = '/owner-barbers';
  static const ownerDashboard = '/owner-dashboard';
  static const ownerSettings = '/owner-settings';
  static const ownerChats = '/owner-chats';
  static const ownerSalonSetup = '/owner-salon-setup';
  static const ownerEditSalonInfo = '/owner-edit-salon-info';
  static const ownerBookingReceipt = '/owner-booking-receipt';

  static const barberNotifications = '/barber-notifications';
  static const barberWorkHistory = '/barber-work-history';
  static const barberEditProfile = '/barber-edit-profile';
  static const barberProfile = '/barber-profile';
}

class AppRouter {
  // Global navigator key for navigation from anywhere in the app
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _page(const SplashScreen(), settings);
      case AppRoutes.roleSelection:
        final args = settings.arguments;
        final message = args is String ? args : null;
        return _page(RoleSelectionScreen(message: message), settings);
      case AppRoutes.sessionRestore:
        final args = settings.arguments;
        final reason = args is String ? args : null;
        return _page(SessionRestoreScreen(reason: reason), settings);
      case AppRoutes.login:
        final roleArg = settings.arguments;
        final selectedRole = roleArg is UserRole ? roleArg : UserRole.customer;
        return _page(LoginScreen(role: selectedRole), settings);
      case AppRoutes.forgotPassword:
        final args = settings.arguments;
        final initialEmail = args is String ? args : null;
        return _page(
          ForgotPasswordScreen(initialEmail: initialEmail),
          settings,
        );
      case AppRoutes.signup:
        final roleArg = settings.arguments;
        final selectedRole = roleArg is UserRole ? roleArg : UserRole.customer;
        return _page(SignupScreen(role: selectedRole), settings);
      case AppRoutes.ownerLogin:
        return _page(
          const LoginScreen(
            successRoute: AppRoutes.ownerHome,
            signupRoute: AppRoutes.ownerSignup,
            role: UserRole.owner,
            title: 'Salon Owner Login',
            subtitle: 'Manage your salon with CutLine.',
            signupPrompt: 'New salon owner?',
            signupActionLabel: 'Create account',
          ),
          settings,
        );
      case AppRoutes.ownerSignup:
        return _page(
          const SignupScreen(
            postSignupRoute: AppRoutes.ownerLogin,
            loginRoute: AppRoutes.ownerLogin,
            signOutAfterSignup: true,
            role: UserRole.owner,
            title: 'Salon Owner Sign Up',
            subtitle: 'Create your salon owner account to manage bookings.',
            loginPrompt: 'Already registered?',
            loginActionLabel: 'Login',
          ),
          settings,
        );
      case AppRoutes.barberLogin:
        return _page(
          const LoginScreen(
            role: UserRole.barber,
            successRoute: AppRoutes.barberHome,
            signupPrompt: 'Need an account?',
            signupActionLabel: 'Ask your owner',
            title: 'Barber Login',
            subtitle: 'Sign in with the credentials shared by the salon owner.',
          ),
          settings,
        );

      case AppRoutes.userHome:
        return _page(const UserHomeScreen(), settings);
      case AppRoutes.ownerHome:
        return _page(const OwnerHomeScreen(), settings);
      case AppRoutes.barberHome:
        return _page(const BarberHomeScreen(), settings);

      case AppRoutes.salonDetails:
        final args = settings.arguments;
        final parsedArgs = args is SalonDetailsArgs ? args : null;
        final salonName = parsedArgs?.salonName ?? (args is String ? args : '');
        final salonId = parsedArgs?.salonId ?? '';
        return _page(
            SalonDetailsScreen(salonId: salonId, salonName: salonName),
            settings);
      case AppRoutes.salonMap:
        final args = settings.arguments;
        final parsedArgs = args is SalonMapArgs ? args : null;
        return _page(
          SalonMapScreen(
            salonName: parsedArgs?.salonName ?? 'Salon',
            address: parsedArgs?.address ?? 'Address unavailable',
            salonLat: parsedArgs?.lat ?? 23.8103,
            salonLng: parsedArgs?.lng ?? 90.4125,
          ),
          settings,
        );
      case AppRoutes.booking:
        final args = settings.arguments;
        final parsedArgs = args is BookingArgs ? args : null;
        return _page(
            BookingScreen(
              salonId: parsedArgs?.salonId ?? '',
              salonName: parsedArgs?.salonName ?? '',
            ),
            settings);
      case AppRoutes.bookingSummary:
        final args = settings.arguments;
        final parsedArgs = args is BookingSummaryArgs ? args : null;
        return _page(
          BookingSummaryScreen(
            salonId: parsedArgs?.salonId ?? '',
            salonName: parsedArgs?.salonName ?? '',
            services: parsedArgs?.services ?? const [],
            barberName: parsedArgs?.barberName ?? '',
            date: parsedArgs?.date ?? DateTime.now(),
            time: parsedArgs?.time ?? '',
            customerName: parsedArgs?.customerName ?? '',
            customerPhone: parsedArgs?.customerPhone ?? '',
            customerEmail: parsedArgs?.customerEmail ?? '',
            customerUid: parsedArgs?.customerUid ?? '',
          ),
          settings,
        );
      case AppRoutes.bookingReceipt:
        final args = settings.arguments;
        final parsedArgs = args is BookingReceiptArgs ? args : null;
        return _page(
            user_booking.BookingReceiptScreen(
              salonId: parsedArgs?.salonId ?? '',
              bookingId: parsedArgs?.bookingId ?? '',
            ),
            settings);
      case AppRoutes.favoriteSalons:
        return _page(const FavoriteSalonScreen(), settings);
      case AppRoutes.userNotifications:
        return _page(const NotificationScreen(), settings);
      case AppRoutes.viewAllServices:
        final args = settings.arguments;
        final parsedArgs = args is ViewAllServicesArgs ? args : null;
        final salonName = parsedArgs?.salonName ?? (args is String ? args : '');
        return _page(ViewAllSalonServices(salonName: salonName), settings);
      case AppRoutes.salonGallery:
        final args = settings.arguments;
        final parsedArgs = args is SalonGalleryArgs ? args : null;
        return _page(
          SalonGalleryScreen(
            salonName: parsedArgs?.salonName ?? (args is String ? args : ''),
            uploadedCount: parsedArgs?.uploadedCount ?? 0,
            totalLimit: parsedArgs?.totalLimit ?? 10,
            photos: parsedArgs?.photos ?? const [],
          ),
          settings,
        );
      case AppRoutes.waitingCustomers:
        final salonIdArg = settings.arguments;
        final salonId = salonIdArg is String ? salonIdArg : null;
        return _page(WaitingListScreen(salonId: salonId), settings);
      case AppRoutes.turnReady:
        final args = settings.arguments;
        final parsedArgs = args is TurnReadyArgs ? args : null;
        return _page(
          TurnReadyScreen(
            bookingId: parsedArgs?.bookingId ?? '',
            salonId: parsedArgs?.salonId ?? '',
            salonName: parsedArgs?.salonName ?? 'Salon',
          ),
          settings,
        );
      case AppRoutes.myBookings:
        return _page(const MyBookingScreen(), settings);
      case AppRoutes.userChats:
        return _page(const ChatsScreen(), settings);
      case AppRoutes.userProfile:
        return _page(const UserProfileScreen(), settings);
      case AppRoutes.userEditProfile:
        return _page(const UserEditProfileScreen(), settings);

      case AppRoutes.ownerBookings:
        return _page(const BookingsScreen(), settings);
      case AppRoutes.ownerBookingRequests:
        return _page(const BookingRequestsScreen(), settings);
      case AppRoutes.ownerManageQueue:
        return _page(const ManageQueueScreen(), settings);
      case AppRoutes.ownerManageServices:
        return _page(const ManageServicesScreen(), settings);
      case AppRoutes.ownerWorkingHours:
        return _page(const WorkingHoursScreen(), settings);
      case AppRoutes.ownerNotifications:
        return _page(const OwnerNotificationsScreen(), settings);
      case AppRoutes.ownerProfile:
        return _page(const OwnerProfileScreen(), settings);
      case AppRoutes.ownerBarbers:
        return _page(const OwnerBarbersScreen(), settings);
      case AppRoutes.ownerDashboard:
        return _page(const OwnerDashboardScreen(), settings);
      case AppRoutes.ownerSettings:
        return _page(const OwnerSettingsScreen(), settings);
      case AppRoutes.ownerChats:
        return _page(const OwnerChatsScreen(), settings);
      case AppRoutes.ownerSalonSetup:
        return _page(const SalonSetupScreen(), settings);
      case AppRoutes.ownerEditSalonInfo:
        return _page(const EditSalonInfoScreen(), settings);
      case AppRoutes.ownerBookingReceipt:
        final args = settings.arguments;
        final parsedArgs = args is BookingReceiptArgs ? args : null;
        return _page(
          owner_booking.BookingReceiptScreen(
            bookingId: parsedArgs?.bookingId,
          ),
          settings,
        );

      case AppRoutes.barberNotifications:
        return _page(const BarberNotificationScreen(), settings);
      case AppRoutes.barberWorkHistory:
        return _page(const WorkHistoryScreen(), settings);
      case AppRoutes.barberEditProfile:
        return _page(const EditProfileScreen(), settings);
      case AppRoutes.barberProfile:
        return _page(const BarberProfileScreen(), settings);
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
          settings: settings,
        );
    }
  }

  static MaterialPageRoute _page(Widget child, RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => child, settings: settings);
  }
}

class SalonDetailsArgs {
  final String salonId;
  final String salonName;

  const SalonDetailsArgs({
    required this.salonId,
    required this.salonName,
  });
}

class SalonMapArgs {
  final String salonName;
  final String address;
  final double lat;
  final double lng;

  const SalonMapArgs({
    required this.salonName,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class BookingArgs {
  final String salonId;
  final String salonName;

  const BookingArgs({
    required this.salonId,
    required this.salonName,
  });
}

class BookingSummaryArgs {
  final String salonId;
  final String salonName;
  final List<String> services;
  final String barberName;
  final DateTime date;
  final String time;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerUid;

  const BookingSummaryArgs({
    required this.salonId,
    required this.salonName,
    required this.services,
    required this.barberName,
    required this.date,
    required this.time,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.customerUid,
  });
}

class BookingReceiptArgs {
  final String salonId;
  final String bookingId;

  const BookingReceiptArgs({
    required this.salonId,
    required this.bookingId,
  });
}

class ViewAllServicesArgs {
  final String salonName;

  const ViewAllServicesArgs({required this.salonName});
}

class SalonGalleryArgs {
  final String salonName;
  final List<String> photos;
  final int uploadedCount;
  final int totalLimit;

  const SalonGalleryArgs({
    required this.salonName,
    this.photos = const [],
    this.uploadedCount = 7,
    this.totalLimit = 10,
  });
}

class TurnReadyArgs {
  final String bookingId;
  final String salonId;
  final String salonName;

  const TurnReadyArgs({
    required this.bookingId,
    required this.salonId,
    required this.salonName,
  });
}
