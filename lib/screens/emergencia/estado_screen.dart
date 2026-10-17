import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/models/models.dart';
import 'package:rally/screens/emergencia/reporte_listo_screen.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/widgets/comunes.dart';

/// "¡Acaba de ocurrir una emergencia! ¿cómo te encuentras?"
/// Clasificación con la tríada del semáforo.
class EstadoScreen extends StatefulWidget {
  const EstadoScreen({super.key});

  @override
  State<EstadoScreen> createState() => _EstadoScreenState();
}

class _EstadoScreenState extends State<EstadoScreen> {
  NivelRiesgo? _enviando;

  Future<void> _elegir(NivelRiesgo nivel) async {
    if (_enviando != null) return;
    HapticFeedback.mediumImpact();

    if (nivel == NivelRiesgo.rojo) {
      Navigator.of(context).pushReplacementNamed(Rutas.reportar);
      return;
    }

    setState(() => _enviando = nivel);
    final reporte = Reporte(nivel: nivel, tipo: nivel.etiqueta);
    final ok = await ReporteService.instancia.enviar(reporte);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReporteListoScreen(enviado: ok)),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return Scaffold(
      backgroundColor: AppTheme.rojo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: BotonCerrar(onTap: () => Navigator.of(context).maybePop()),
              ),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Logo(Img.isoBlanco, alto: 150),
                    SizedBox(height: 16),
                    Text(
                      '¡Acaba de ocurrir una\nemergencia!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      '¿cómo te encuentras?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    for (final n in NivelRiesgo.values) ...[
                      _BotonSemaforo(
                        nivel: n,
                        cargando: _enviando == n,
                        onTap: () => _elegir(n),
                      ),
                      if (n != NivelRiesgo.rojo) const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonSemaforo extends StatelessWidget {
  const _BotonSemaforo({
    required this.nivel,
    required this.onTap,
    this.cargando = false,
  });
  final NivelRiesgo nivel;
  final VoidCallback onTap;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final textoColor =
        nivel == NivelRiesgo.amarillo ? AppTheme.primary : Colors.white;
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: nivel.color,
          foregroundColor: textoColor,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: cargando
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: textoColor,
                ),
              )
            : Text(
                nivel.etiqueta,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
