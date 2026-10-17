import 'package:flutter/material.dart';

import 'package:rally/core/theme.dart';
import 'package:rally/models/models.dart';
import 'package:rally/screens/emergencia/reportar_emergencia_screen.dart';
import 'package:rally/screens/emergencia/reporte_listo_screen.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/widgets/comunes.dart';

enum _Fase { enviando, enviado, enEspera }

/// Una sola pantalla con los 3 estados del diseño:
/// "Enviando reporte..." → "Reporte enviado" o "Reporte en espera".
class EnvioReporteScreen extends StatefulWidget {
  const EnvioReporteScreen({super.key, required this.reporte});
  final Reporte reporte;

  @override
  State<EnvioReporteScreen> createState() => _EnvioReporteScreenState();
}

class _EnvioReporteScreenState extends State<EnvioReporteScreen> {
  _Fase _fase = _Fase.enviando;

  @override
  void initState() {
    super.initState();
    _enviar();
  }

  Future<void> _enviar() async {
    setState(() => _fase = _Fase.enviando);
    final ok = await ReporteService.instancia.enviar(widget.reporte);
    if (mounted) setState(() => _fase = ok ? _Fase.enviado : _Fase.enEspera);
  }

  void _revisarDatos() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReportarEmergenciaScreen(inicial: widget.reporte),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (icono, fondoIcono, colorIcono, titulo, colorTitulo, texto) =
        switch (_fase) {
      _Fase.enviando => (
          null,
          AppTheme.grisCaja,
          AppTheme.grisTexto,
          'Enviando reporte...',
          AppTheme.texto,
          'El envío está en curso. Todavía no se ha confirmado.',
        ),
      _Fase.enviado => (
          Icons.check,
          const Color(0xFFE3F1E6),
          AppTheme.verde,
          'Reporte enviado',
          AppTheme.texto,
          'El envío se completó. Esto no confirma que recibirás atención.',
        ),
      _Fase.enEspera => (
          Icons.wifi_off,
          const Color(0xFFFBE3E3),
          AppTheme.alerta,
          'Reporte en espera',
          AppTheme.primary,
          'No hay conexión. Comprueba tu conexión y vuelve a intentarlo.',
        ),
    };

    return PopScope(
      canPop: _fase != _Fase.enviando,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              BarraEmergencias(
                onAtras: _fase == _Fase.enviando
                    ? null
                    : () => ReporteListoScreen.irAlInicio(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: fondoIcono,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(13),
                        child: icono == null
                            ? const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.grisTexto,
                              )
                            : Icon(icono, color: colorIcono),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: colorTitulo,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(texto,
                        style: const TextStyle(
                            color: AppTheme.grisTexto, fontSize: 15)),
                    const SizedBox(height: 20),
                    TarjetaReporte(reporte: widget.reporte),
                    const SizedBox(height: 16),
                    const CajaAtencionInmediata(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _botones(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botones() {
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    switch (_fase) {
      case _Fase.enviando:
        return Column(
          children: [
            const Text(
              'Espera el resultado antes de volver a enviar.',
              style: TextStyle(color: AppTheme.grisTexto, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: const Color(0xFFE6E8EB),
                  disabledForegroundColor: AppTheme.grisTexto,
                  shape: forma,
                ),
                child: const Text('Enviando reporte...'),
              ),
            ),
          ],
        );
      case _Fase.enviado:
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => ReporteListoScreen.irAlInicio(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.oscuro,
              foregroundColor: Colors.white,
              shape: forma,
            ),
            child: const Text('Volver al inicio'),
          ),
        );
      case _Fase.enEspera:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _enviar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar envío'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.rojo,
                  foregroundColor: Colors.white,
                  shape: forma,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton(
                onPressed: _revisarDatos,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.texto,
                  shape: forma,
                ),
                child: const Text(
                  'Revisar datos',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'El reporte queda guardado en tu teléfono y se reintentará '
              'automáticamente al abrir la app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grisTexto, fontSize: 12),
            ),
          ],
        );
    }
  }
}
