import 'package:flutter/material.dart';

import 'package:cutline/features/admin/screens/admin_auth_gate_screen.dart';
import 'package:cutline/features/admin/screens/salon_review_detail_screen.dart';

class AdminRoutes {
  static const root = '/';
  static const salonReview = '/salon-review';
}

class AdminRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AdminRoutes.root:
        return MaterialPageRoute<void>(
          builder: (_) => const AdminAuthGateScreen(),
          settings: settings,
        );
      case AdminRoutes.salonReview:
        final salonId =
            settings.arguments is String ? settings.arguments as String : '';
        return MaterialPageRoute<void>(
          builder: (_) => SalonReviewDetailScreen(salonId: salonId),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const AdminAuthGateScreen(),
          settings: settings,
        );
    }
  }
}
