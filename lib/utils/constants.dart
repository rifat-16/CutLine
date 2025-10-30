class AppConstants {
  // App Info
  static const String appName = 'Cutline';
  static const String appTagline = 'Skip the waiting line — your haircut, your time';

  // Collections
  static const String usersCollection = 'users';
  static const String salonsCollection = 'salons';
  static const String bookingsCollection = 'bookings';
  static const String barbersSubcollection = 'barbers';
  static const String queueSubcollection = 'queue';

  // Storage Paths
  static const String salonImagesPath = 'salon_images';
  static const String barberImagesPath = 'barber_images';

  // Notifications
  static const String notificationChannelId = 'cutline_notifications';
  static const String notificationChannelName = 'Cutline Notifications';

  // Default Values
  static const int defaultBookingDuration = 30; // minutes
  static const String defaultCurrency = 'USD';
}

class RouteNames {
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
}
