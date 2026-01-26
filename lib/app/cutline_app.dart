import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/user_location_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/config/app_flavor.dart';
import 'package:cutline/shared/widgets/auth_lifecycle_watcher.dart';

class CutLineApp extends StatelessWidget {
  const CutLineApp({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => UserLocationProvider()..initSilently(),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, child) => AuthLifecycleWatcher(
          child: MaterialApp(
            navigatorKey: AppRouter.navigatorKey,
            debugShowCheckedModeBanner: false,
            title: flavor.displayName,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      ),
    );
  }
}

