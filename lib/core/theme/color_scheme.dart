// lib/app/theme/color_schemes.dart
import 'package:flutter/material.dart';

const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF006E1C),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF006874),
  onSecondary: Color(0xFFFFFFFF),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  background: Color(0xFFF6F6F6),
  onBackground: Color(0xFF1B1B1F),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF1B1B1F),
);

const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF6FE274),
  onPrimary: Color(0xFF003A06),
  secondary: Color(0xFF4FD8EB),
  onSecondary: Color(0xFF00363D),
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF601410),
  background: Color(0xFF1B1B1F),
  onBackground: Color(0xFFE3E2E6),
  surface: Color(0xFF1B1B1F),
  onSurface: Color(0xFFE3E2E6),
);
