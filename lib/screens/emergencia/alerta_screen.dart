import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/widgets/comunes.dart';

/// Pantalla "ALERTA" que aparece cuando llega una alerta de emergencia.
/// Al tocarla, lleva a "¿cómo te encuentras?".
class AlertaScreen extends StatefulWidget {
  const AlertaScreen({super.key});

  @override
  State<AlertaScreen> createState() => _AlertaScreenState();
}

class _AlertaScreenState extends State<AlertaScreen>
    with SingleTickerProviderStateMixin {
  late final _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    HapticFeedback.vibrate();
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pushReplacementNamed(Rutas.estado),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: BotonCerrar(
                    onTap: () {
                      ReporteService.instancia.descartarAlerta();
                      Navigator.of(context).maybePop();
                    },
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: Tween(begin: 0.94, end: 1.04).animate(
                          CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
                        ),
                        child: const Logo(Img.isoRojo, alto: 230),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'ALERTA',
                        style: TextStyle(
                          fontFamily: 'Impact',
                          color: AppTheme.primary,
                          fontSize: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Toca para indicar cómo te encuentras',
                        style: TextStyle(color: AppTheme.grisTexto),
                      ),
                    ],
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

/// Aviso rojo "A ocurrido una emergencia y hay personas que necesitan ayuda"
/// (se muestra sobre Donaciones cuando hay una alerta activa).
Future<void> mostrarAvisoAyuda(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: AppTheme.background.withValues(alpha: 0.6),
    builder: (context) => Dialog(
      backgroundColor: AppTheme.rojo,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 40, 26, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Logo(Img.isoBlanco, alto: 170)),
                const SizedBox(height: 40),
                const Text(
                  'Ha ocurrido una emergencia y hay personas que necesitan '
                  'ayuda',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                BotonAmarillo(
                  texto: 'QUIERO AYUDAR',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: BotonCerrar(
              onTap: () {
                ReporteService.instancia.descartarAlerta();
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    ),
  );
}
