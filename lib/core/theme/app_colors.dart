import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand — monocromático PHD
  static const Color primary = Color(0xFFFFFFFF);
  static const Color primaryDark = Color(0xFFCCCCCC);
  static const Color primaryLight = Color(0xFFFFFFFF);

  // Background
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0F0F0F);
  static const Color surfaceVariant = Color(0xFF1A1A1A);
  static const Color bottomNav = Color(0xFF000000);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textHint = Color(0xFF444444);

  // Status (mantidos coloridos para legibilidade funcional)
  static const Color active = Color(0xFF4CAF50);
  static const Color inactive = Color(0xFF888888);
  static const Color error = Color(0xFFFF5252);

  // Input
  static const Color inputFill = Color(0xFF0F0F0F);
  static const Color inputBorder = Color(0xFF2A2A2A);
  static const Color inputFocused = Color(0xFFFFFFFF);

  // Divider
  static const Color divider = Color(0xFF1C1C1C);
}
