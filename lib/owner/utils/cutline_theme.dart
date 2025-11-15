import 'package:cutline/ui/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class OwnerSpacing {
  static const EdgeInsets screen =
      EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  static const EdgeInsets section = EdgeInsets.symmetric(vertical: 14);
  static const double cardGap = 16;
}

class OwnerTextStyles {
  static const TextStyle heading = TextStyle(
      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87);
  static const TextStyle subtitle =
      TextStyle(fontSize: 15, color: Colors.black54);
  static const TextStyle label = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87);
}

class OwnerDecorations {
  static const double radius = 18;

  static BoxDecoration card({Color? color, Border? border}) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: border,
      boxShadow: const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 18,
          offset: Offset(0, 12),
        ),
      ],
    );
  }
}

class OwnerTheme {
  static const Color primary = CutlineColors.primary;
  static const Color accent = CutlineColors.accent;
  static const Color background = Colors.white;

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orangeAccent;
      case 'waiting':
        return Colors.amber;
      case 'serving':
        return primary;
      case 'done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
