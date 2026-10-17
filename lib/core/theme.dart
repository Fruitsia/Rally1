import 'package:flutter/material.dart';

class AppTheme {
  // Colores de marca
  static const Color primary = Color(0xFF5A101C); // vino oscuro (logo, títulos)
  static const Color rojo = Color(0xFF7A1717); // fondos rojos (splash, paneles)
  static const Color secondary = Color(0xFFF8B637); // amarillo (botones, barra)
  static const Color background = Color(0xFFFDF5E4); // crema

  // Semáforo de riesgo
  static const Color verde = Color(0xFF2E9B3E);
  static const Color amarillo = Color(0xFFF8B637);
  static const Color alerta = Color(0xFFB80F0F);

  // Neutros
  static const Color texto = Color(0xFF1F2328);
  static const Color grisTexto = Color(0xFF6B6F76);
  static const Color borde = Color(0xFFE8DFCF);
  static const Color grisCaja = Color(0xFFF1EFEA);
  static const Color placeholder = Color(0xFFD5D7DB);
  static const Color oscuro = Color(0xFF22252B);

  /// Escala de texto elegida en Configuración (Pequeño / Estándar / Grande).
  static final ValueNotifier<double> escalaTexto = ValueNotifier(1.0);

  /// Estilo de los títulos grandes tipo "Noticias", "Mis Donaciones".
  static const TextStyle tituloImpact = TextStyle(
    fontFamily: 'Impact',
    color: rojo,
    fontSize: 26,
    height: 1.1,
  );

  static ThemeData get theme {
    return ThemeData(
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: background,
      ),
      fontFamily: 'CenturyGothic',
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: oscuro,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: primary),
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
