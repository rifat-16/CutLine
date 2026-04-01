import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:cutline/features/admin/providers/admin_auth_provider.dart';
import 'package:cutline/routes/admin_router.dart';
import 'package:cutline/shared/config/app_flavor.dart';

class CutLineAdminApp extends StatelessWidget {
  const CutLineAdminApp({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF0F766E),
      secondary: const Color(0xFF2F855A),
      surface: Colors.white,
    );
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
    );
    final textTheme = GoogleFonts.manropeTextTheme(baseTheme.textTheme).apply(
      bodyColor: const Color(0xFF10261D),
      displayColor: const Color(0xFF10261D),
    );

    return ChangeNotifierProvider(
      create: (_) => AdminAuthProvider(),
      child: MaterialApp(
        navigatorKey: AdminRouter.navigatorKey,
        debugShowCheckedModeBanner: false,
        title: '${flavor.displayName} Admin',
        theme: baseTheme.copyWith(
          textTheme: textTheme,
          scaffoldBackgroundColor: const Color(0xFFF3F5F2),
          dividerColor: const Color(0xFFE0E7E3),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFFF3F5F2),
            foregroundColor: const Color(0xFF10261D),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleTextStyle: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF10261D),
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white.withValues(alpha: 0.96),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFFDDE6E0)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F766E),
              side: const BorderSide(color: Color(0xFFBCD7D0)),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.92),
            hintStyle: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF7A8A84),
            ),
            labelStyle: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF4D635D),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFD7DFDB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide:
                  const BorderSide(color: Color(0xFF0F766E), width: 1.4),
            ),
          ),
          navigationBarTheme: const NavigationBarThemeData(
            height: 74,
            backgroundColor: Colors.transparent,
            indicatorColor: Color(0xFFDDF0E8),
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFFE7EEEB),
            selectedColor: const Color(0xFF0F766E),
            secondarySelectedColor: const Color(0xFF0F766E),
            disabledColor: const Color(0xFFE7EEEB),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            side: BorderSide.none,
            labelStyle: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
            secondaryLabelStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10261D),
            contentTextStyle: textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        initialRoute: AdminRoutes.root,
        onGenerateRoute: AdminRouter.onGenerateRoute,
      ),
    );
  }
}
