import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF5A101C);
  static const Color secondary = Color(0xFFF8B637);
  static const Color background = Color(0xFFF7F1EA);

  static ThemeData get theme {
    return ThemeData(
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: background, // Reemplazo de 'background' por 'surface'
      ),
      fontFamily: 'CenturyGothic',
      textTheme: const TextTheme(
        // Títulos importantes o emergencias SOS
        displayLarge: TextStyle(
          fontFamily: 'Impact',
          color: primary,
          fontSize: 32.0,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Impact',
          color: secondary,
          fontSize: 28.0,
        ),
        // Títulos principales
        headlineLarge: TextStyle(
          fontFamily: 'CenturyGothic',
          fontWeight: FontWeight.w700,
          color: primary,
          fontSize: 24.0,
        ),
        titleLarge: TextStyle(
          fontFamily: 'CenturyGothic',
          fontWeight: FontWeight.w700,
          color: primary,
          fontSize: 20.0,
        ),
        // Textos normales
        bodyLarge: TextStyle(
          fontFamily: 'CenturyGothic',
          fontWeight: FontWeight.w400,
          fontSize: 16.0,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'CenturyGothic',
          fontWeight: FontWeight.w400,
          fontSize: 14.0,
        ),
      ),
    );
  }
}