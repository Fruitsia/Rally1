import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rally/core/theme.dart';
import 'package:rally/models/models.dart';
import 'package:rally/screens/emergencia/envio_reporte_screen.dart';
import 'package:rally/services/sos_acompanamiento.dart' show PuntoGps;
import 'package:rally/services/sos_adaptadores.dart';
import 'package:rally/widgets/comunes.dart';

/// Formulario "Reportar emergencia".
class ReportarEmergenciaScreen extends StatefulWidget {
  const ReportarEmergenciaScreen({super.key, this.inicial});

  /// Si viene de "Revisar datos", se precarga el reporte anterior.
  final Reporte? inicial;

  @override
  State<ReportarEmergenciaScreen> createState() =>
      _ReportarEmergenciaScreenState();
}

class _ReportarEmergenciaScreenState extends State<ReportarEmergenciaScreen> {
  final _form = GlobalKey<FormState>();
  late String _tipo = widget.inicial?.tipo ?? 'Terremoto';
  late final _direccion = TextEditingController(
    text: widget.inicial?.direccion ?? '',
  );
  late final _referencia =
      TextEditingController(text: widget.inicial?.referencia ?? '');

  PuntoGps? _gps;
  bool _buscandoGps = true;

  @override
  void initState() {
    super.initState();
    if (widget.inicial?.tieneGps ?? false) {
      _buscandoGps = false;
    } else {
      _buscarGps();
    }
  }

  Future<void> _buscarGps() async {
    setState(() => _buscandoGps = true);
    final u = await GeoUbicador.instancia.rapida(
      limite: const Duration(seconds: 6),
    );
    if (!mounted) return;
    setState(() {
      _gps = u;
      _buscandoGps = false;
    });
  }

  bool get _tieneGps => _gps != null || (widget.inicial?.tieneGps ?? false);

  @override
  void dispose() {
    _direccion.dispose();
    _referencia.dispose();
    super.dispose();
  }

  Future<void> _elegirTipo() async {
    final elegido = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in tiposEmergencia)
              ListTile(
                leading: Icon(iconoTipo(t), color: AppTheme.primary),
                title: Text(t),
                trailing: t == _tipo
                    ? const Icon(Icons.check, color: AppTheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, t),
              ),
          ],
        ),
      ),
    );
    if (elegido != null) setState(() => _tipo = elegido);
  }

  void _enviar() {
    if (!_form.currentState!.validate()) return;
    HapticFeedback.heavyImpact();
    final base = widget.inicial;
    final g = _gps;
    final escrita = _direccion.text.trim();
    // La base exige dirección en los reportes rojos: con GPS se completa sola.
    final direccion = escrita.isEmpty && _tieneGps ? 'Ubicación GPS' : escrita;
    final reporte = base != null
        ? base.copiarCon(
            tipo: _tipo,
            direccion: direccion,
            referencia: _referencia.text.trim(),
            latitud: g?.punto.lat,
            longitud: g?.punto.lon,
            precisionM: g?.precisionM,
          )
        : Reporte(
            nivel: NivelRiesgo.rojo,
            tipo: _tipo,
            direccion: direccion,
            referencia: _referencia.text.trim(),
            latitud: g?.punto.lat,
            longitud: g?.punto.lon,
            precisionM: g?.precisionM,
          );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => EnvioReporteScreen(reporte: reporte)),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    const etiqueta = TextStyle(fontSize: 13, color: AppTheme.texto);
    const gris = TextStyle(fontSize: 12, color: AppTheme.grisTexto);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            BarraEmergencias(onAtras: () => Navigator.of(context).maybePop()),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    const Text(
                      'Reportar emergencia',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.texto,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Revisa el tipo y la ubicación antes de enviar.',
                      style: TextStyle(color: AppTheme.grisTexto),
                    ),
                    const SizedBox(height: 20),
                    const Text('Tipo de emergencia', style: etiqueta),
                    const SizedBox(height: 6),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        onTap: _elegirTipo,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        leading: Icon(iconoTipo(_tipo), color: AppTheme.primary),
                        title: Text(_tipo),
                        trailing: const Icon(Icons.chevron_right),
                        shape: const Border(
                          bottom: BorderSide(color: AppTheme.borde),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('Ubicación de la emergencia', style: etiqueta),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (_buscandoGps)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _tieneGps
                                ? Icons.my_location
                                : Icons.location_off_outlined,
                            size: 14,
                            color: _tieneGps ? AppTheme.verde : AppTheme.grisTexto,
                          ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _buscandoGps
                                ? 'Buscando tu ubicación…'
                                : _tieneGps
                                    ? 'Ubicación automática lista'
                                        '${_gps == null ? '' : ' (±${_gps!.precisionM.round()} m)'}'
                                        '. La dirección es opcional.'
                                    : 'Sin ubicación automática. Escríbela aquí.',
                            style: gris,
                          ),
                        ),
                        if (!_buscandoGps && !_tieneGps)
                          TextButton(
                            onPressed: _buscarGps,
                            child: const Text('Reintentar'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _direccion,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (!_tieneGps && (v == null || v.trim().isEmpty))
                              ? 'Escribe dónde está ocurriendo'
                              : null,
                      decoration: _deco(
                        'Dirección (ej. Av. del Parque 120)',
                        Icons.edit_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _referencia,
                      textInputAction: TextInputAction.done,
                      decoration: _deco(
                        'Referencia (ej. Entrada principal)',
                        null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Puedes editar la dirección y añadir una referencia para '
                      'identificar el lugar.',
                      style: gris,
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Enviar un reporte no confirma que recibirás atención.',
                      style: gris,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _enviar,
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: const Text('Enviar reporte SOS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.rojo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String pista, IconData? icono) => InputDecoration(
        hintText: pista,
        hintStyle: const TextStyle(color: AppTheme.grisTexto, fontSize: 14),
        suffixIcon:
            icono == null ? null : Icon(icono, size: 18, color: AppTheme.grisTexto),
        isDense: true,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.borde),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
      );
}
