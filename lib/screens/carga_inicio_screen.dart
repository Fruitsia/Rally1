import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla de carga / inicio de NUNC.
///
/// Requisitos en pubspec.yaml:
/// flutter:
///   assets:
///     - assets/images/logo_nunc.png   (logo blanco con fondo transparente)
class CargaInicioScreen extends StatefulWidget {
  const CargaInicioScreen({super.key});

  static const Color kRojoNunc = Color(0xFF7A1717);

  @override
  State<CargaInicioScreen> createState() => _CargaInicioScreenState();
}

class _CargaInicioScreenState extends State<CargaInicioScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Iconos de la barra de estado en blanco sobre fondo rojo
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    // Simula la carga inicial (3 segundos) y navega a la siguiente pantalla
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      // Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CargaInicioScreen.kRojoNunc,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_rojo.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Informa a tu comunidad y al\nmundo de lo que esta pasando',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}