import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/widgets/comunes.dart';

/// Pantalla de carga / inicio de NUNC.
class CargaInicioScreen extends StatefulWidget {
  const CargaInicioScreen({super.key});

  static const Color kRojoNunc = AppTheme.rojo;

  @override
  State<CargaInicioScreen> createState() => _CargaInicioScreenState();
}

class _CargaInicioScreenState extends State<CargaInicioScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    // Carga los reportes guardados en el teléfono mientras se ve el logo.
    ReporteService.instancia.cargar();

    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(Rutas.emergencia);
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
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Logo(Img.logoBlanco, ancho: 240),
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
