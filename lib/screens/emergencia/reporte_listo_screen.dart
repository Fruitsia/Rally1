import 'package:flutter/material.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/widgets/comunes.dart';

/// "Listo! ya lo reportamos con tu líder de comunidad".
/// Si no hubo conexión, avisa que quedó guardado para enviarse después.
class ReporteListoScreen extends StatelessWidget {
  const ReporteListoScreen({super.key, required this.enviado});
  final bool enviado;

  static void irAlInicio(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AuthService.haySesion ? Rutas.home : Rutas.emergencia,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.rojo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: BotonCerrar(onTap: () => irAlInicio(context)),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Logo(Img.isoBlanco, alto: 180),
                    const SizedBox(height: 18),
                    Text(
                      enviado
                          ? '¡Listo! ya lo reportamos con tu líder de comunidad'
                          : 'Guardamos tu reporte',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!enviado) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'No hay conexión. Lo enviaremos a tu líder de '
                        'comunidad en cuanto vuelva la señal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
