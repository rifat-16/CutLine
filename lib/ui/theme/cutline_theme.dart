import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CutlineColors {
  static const Color primary = Colors.blueAccent;
  static const Color accent = Colors.orangeAccent;
  static const Color background = Colors.white;
  static final Color secondaryBackground = Colors.blue.shade50;
}

class CutlineSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets section = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets card = EdgeInsets.all(16);
}

class CutlineTextStyles {
  static const TextStyle appBarTitle = TextStyle(
    color: CutlineColors.primary,
    fontWeight: FontWeight.bold,
    fontSize: 20,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 15,
    color: Colors.black54,
  );

  static const TextStyle subtitleBold = TextStyle(
    fontSize: 15,
    color: Colors.black87,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: Colors.black87,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: Colors.black54,
  );

  static const TextStyle link = TextStyle(
    color: CutlineColors.primary,
    fontWeight: FontWeight.w600,
    fontSize: 14,
  );
}

class CutlineDecorations {
  static const double radius = 16;
  static const List<BoxShadow> shadow = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 10,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static BoxDecoration card({List<Color>? colors, Color? solidColor}) {
    return BoxDecoration(
      color: solidColor ?? CutlineColors.background,
      gradient: colors != null ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors) : null,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadow.map((s) => s.copyWith(color: s.color.withValues(alpha: 0.08))).toList(),
    );
  }
}

class CutlineButtons {
  static ButtonStyle primary({EdgeInsetsGeometry? padding}) {
    return ElevatedButton.styleFrom(
      backgroundColor: CutlineColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }

  static ButtonStyle accent({EdgeInsetsGeometry? padding}) {
    return ElevatedButton.styleFrom(
      backgroundColor: CutlineColors.accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }
}

class CutlineAnimations {
  static Widget entrance(Widget child, {int delayMs = 0, double offset = 0.1}) {
    return child.animate().fadeIn(duration: 400.ms, delay: delayMs.ms).slideY(
          begin: offset,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOut,
        );
  }

  static Widget staggeredList({required Widget child, required int index}) {
    return entrance(child, delayMs: index * 100);
  }
}

class CutlineAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const CutlineAppBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = false,
    this.leading,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: CutlineTextStyles.appBarTitle),
      backgroundColor: CutlineColors.background,
      foregroundColor: CutlineColors.primary,
      elevation: 0.5,
      centerTitle: centerTitle,
      actions: actions,
      leading: leading,
      bottom: bottom,
    );
  }
}

class CutlineSectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const CutlineSectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: CutlineTextStyles.title),
        if (action != null) action!,
      ],
    );
  }
}
