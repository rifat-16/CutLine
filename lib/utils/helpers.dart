import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class AppHelpers {
  // Format currency
  static String formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
    ).format(amount);
  }

  // Format date
  static String formatDate(DateTime date, {String format = 'MMM dd, yyyy'}) {
    return DateFormat(format).format(date);
  }

  // Format time
  static String formatTime(DateTime date, {String format = 'h:mm a'}) {
    return DateFormat(format).format(date);
  }

  // Format date and time
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy • h:mm a').format(date);
  }

  // Calculate estimated wait time
  static String calculateWaitTime(int queuePosition, int avgServiceDuration) {
    final minutes = queuePosition * avgServiceDuration;
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours hr ${remainingMinutes}min';
    }
  }

  // Get status color
  static Color getStatusColor(String status) {
    switch (status) {
      case 'waiting':
        return const Color(0xFFF97316); // Orange
      case 'inProgress':
        return const Color(0xFF3B82F6); // Blue
      case 'served':
        return const Color(0xFF10B981); // Green
      case 'skipped':
        return const Color(0xFFEF4444); // Red
      case 'cancelled':
        return const Color(0xFF6B7280); // Gray
      default:
        return const Color(0xFF6B7280);
    }
  }

  // Validate phone number
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-()]{10,}$');
    return phoneRegex.hasMatch(phone);
  }

  // Truncate text
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
