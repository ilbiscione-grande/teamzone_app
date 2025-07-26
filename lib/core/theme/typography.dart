// lib/app/theme/typography.dart
import 'package:flutter/material.dart';

class TeamZoneTypography {
  // Den fontFamily du registrerat i pubspec.yaml
  static const String fontFamily = 'Figtree';

  // TextTheme för Material 3: bodySmall, bodyMedium, bodyLarge, plus ev. fler
  static final TextTheme textTheme = TextTheme(
    bodySmall: const TextStyle(fontFamily: fontFamily, fontSize: 12),
    bodyMedium: const TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      // color: Colors.black,
    ),
    bodyLarge: const TextStyle(fontFamily: fontFamily, fontSize: 16),
    // Du kan lägga till t.ex. headlineLarge, titleMedium, labelSmall, osv:
    headlineSmall: const TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: const TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  );
}
