import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Håller reda på om vi kör ljust eller mörkt tema.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
