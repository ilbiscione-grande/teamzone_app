// lib/app/theme/theme.dart
import 'package:flutter/material.dart';
import 'color_scheme.dart';
import 'typography.dart'; // <-- importera din nya fil

class TeamZoneTheme {
  static ThemeData _baseLight = ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    // Sätt fontFamily globalt (om du vill)
    fontFamily: TeamZoneTypography.fontFamily,
  );

  static ThemeData _baseDark = ThemeData(
    useMaterial3: true,
    colorScheme: darkColorScheme,
    fontFamily: TeamZoneTypography.fontFamily,
  );

  /// Ljusa temat med din custom TextTheme
  static final ThemeData lightTheme = _baseLight.copyWith(
    textTheme: TeamZoneTypography.textTheme.apply(
      // bodyColor för brödtext, displayColor för rubriker
      bodyColor: lightColorScheme.onSurface,
      displayColor: lightColorScheme.onSurface,
    ),
  );

  /// Mörka temat med din custom TextTheme
  static final ThemeData darkTheme = _baseDark.copyWith(
    textTheme: TeamZoneTypography.textTheme.apply(
      bodyColor: darkColorScheme.onSurface,
      displayColor: darkColorScheme.onSurface,
    ),
  );
}
