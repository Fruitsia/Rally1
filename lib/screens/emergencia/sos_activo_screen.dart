import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/models/emergencia_models.dart';
import 'package:rally/models/models.dart' show tiposEmergencia, iconoTipo;
import 'package:rally/services/auth_service.dart';
import 'package:rally/services/sos_acompanamiento.dart';
import 'package:rally/screens/home/mapa_screen.dart';
import 'package:rally/services/sos_adaptadores.dart';
import 'package:rally/widgets/mapa_base.dart';

/// Pantalla que acompaña a la persona mientras el SOS está activo:
/// guarda y envía su ubicación sola, le dice a dónde ir y, si deja de
/// responder, escala hasta llamar a la autoridad.
class SosActivoScreen extends StatefulWidget {
  const SosActivoScreen({super.key, this.tipo = 'Emergencia'});

  /// Tipo con el que se activa (si no había un SOS abierto).
  final String tipo;

  @override
  State<SosActivoScreen> createState() => _SosActivoScreenState();
}

class _SosActivoScreenState extends State<SosActivoScreen> {
  SosAcompanamiento get _srv => SosApp.servicio;

  @override
  void initState() {
    super.initState();
    if (!_srv.hayActivo) {
      // No se espera: la pantalla aparece al instante y todo sigue detrás.
      unawaited(SosApp.activar(tipo: widget.tipo));
    }
  }

  Future<void> _cerrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Ya estás a salvo?'),
        content: const Text(
          'Se cerrará el SOS y dejaremos de compartir tu ubicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir con el SOS'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, estoy a salvo'),
          ),
        ],
      ),
    );
    if (ok != true) {
      await _srv.toque();
      return;
    }
    await SosApp.cerrar();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AuthService.haySesion ? Rutas.home : Rutas.emergencia,
      (_) => false,
    );
  }

  Future<void> _elegirTipo() async {
    final actual = _srv.sos?.tipo;
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
                trailing: t == actual
                    ? const Icon(Icons.check, color: AppTheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, t),
              ),
          ],
        ),
      ),
    );
    if (elegido != null) await _srv.cambiarTipo(elegido);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return PopScope(
      // Volver atrás no cierra el SOS por accidente.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cerrar();
      },
      child: Listener(
        // Cualquier toque cuenta como «sigo aquí».
        onPointerDown: (_) => _srv.toque(),
        child: ListenableBuilder(
          listenable: _srv,
          builder: (context, _) {
            final s = _srv.sos;
            final preguntando = s != null &&
                s.activo &&
                s.etapa != Etapa.normal;
            return Scaffold(
              backgroundColor: AppTheme.rojo,
              body: SafeArea(
                child: Stack(
                  children: [
                    _Contenido(
                      sos: s,
                      falta: _srv.faltaParaSiguientePaso,
                      config: _srv.config,
                      onTipo: _elegirTipo,
                      onCerrar: _cerrar,
                      onLlamar: _srv.llamar,
                      onEstado: (e) => _srv.respondio(estado: e),
                    ),
                    if (preguntando)
                      _AvisoSigueBien(
                        etapa: s.etapa,
                        falta: _srv.faltaParaSiguientePaso,
                        llamadaA: s.llamadaA,
                        onBien: () =>
                            _srv.respondio(estado: EstadoUsuario.precaucion),
                        onAyuda: () =>
                            _srv.respondio(estado: EstadoUsuario.emergencia),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═════════════════════════ Contenido principal ═════════════════════════

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.sos,
    required this.falta,
    required this.config,
    required this.onTipo,
    required this.onCerrar,
    required this.onLlamar,
    required this.onEstado,
  });

  final Sos? sos;
  final Duration? falta;
  final ConfigSos config;
  final VoidCallback onTipo;
  final VoidCallback onCerrar;
  final Future<bool> Function(String numero) onLlamar;
  final void Function(EstadoUsuario estado) onEstado;

  @override
  Widget build(BuildContext context) {
    final s = sos;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            const _Pulso(),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'SOS activo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            TextButton(
              onPressed: onCerrar,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Estoy a salvo'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'No cierres la app. Te acompañamos hasta que estés a salvo.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),

        // ── Qué está guardado y enviado ──
        _Tarjeta(
          child: Column(
            children: [
              _FilaEstado(
                icono: Icons.my_location,
                titulo: _textoUbicacion(s),
                ok: s?.ultimaUbicacion != null,
              ),
              const Divider(height: 18),
              _FilaEstado(
                icono: Icons.cloud_upload_outlined,
                titulo: _textoEnvio(s),
                ok: s?.envio == EstadoEnvio.enviado,
              ),
              const Divider(height: 18),
              _FilaEstado(
                icono: Icons.battery_std,
                titulo: s?.bateriaPct == null
                    ? 'Batería: no disponible'
                    : 'Batería: ${s!.bateriaPct}%'
                        '${s.bateriaPct! <= config.bateriaBaja ? ' · modo ahorro' : ''}',
                ok: (s?.bateriaPct ?? 100) > config.bateriaBaja,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Tipo de emergencia ──
        _Tarjeta(
          child: InkWell(
            onTap: onTipo,
            child: Row(
              children: [
                Icon(iconoTipo(s?.tipo ?? ''), color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tipo de emergencia',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.grisTexto)),
                      Text(s?.tipo ?? '…',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Text('Cambiar',
                    style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── A dónde ir ──
        _Destino(sos: s),
        const SizedBox(height: 12),

        // ── Semáforo ──
        _Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Cómo estás ahora?',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _BotonSemaforo(
                    texto: 'Emergencia',
                    color: AppTheme.alerta,
                    elegido: s?.estadoUsuario == EstadoUsuario.emergencia ||
                        s?.estadoUsuario == EstadoUsuario.sinRespuesta,
                    onTap: () => onEstado(EstadoUsuario.emergencia),
                  ),
                  const SizedBox(width: 8),
                  _BotonSemaforo(
                    texto: 'Precaución',
                    color: AppTheme.amarillo,
                    textoOscuro: true,
                    elegido: s?.estadoUsuario == EstadoUsuario.precaucion,
                    onTap: () => onEstado(EstadoUsuario.precaucion),
                  ),
                  const SizedBox(width: 8),
                  _BotonSemaforo(
                    texto: 'A salvo',
                    color: AppTheme.verde,
                    elegido: false,
                    onTap: onCerrar,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Llamadas ──
        _Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Llamar ahora',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _BotonLlamar('Policía', NumerosEmergencia.policia, onLlamar),
                  const SizedBox(width: 8),
                  _BotonLlamar(
                      'Ambulancia', NumerosEmergencia.ambulancia, onLlamar),
                  const SizedBox(width: 8),
                  _BotonLlamar('Bomberos', NumerosEmergencia.bomberos, onLlamar),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Qué pasa si no respondo ──
        Text(
          _textoEscalamiento(s, falta, config),
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
        ),
      ],
    );
  }

  static String _hace(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'hace ${d.inSeconds.clamp(0, 59)} s';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    return 'hace ${d.inHours} h';
  }

  static String _textoUbicacion(Sos? s) {
    final u = s?.ultimaUbicacion;
    if (u == null) return 'Buscando tu ubicación…';
    final origen = switch (u.origen) {
      OrigenUbicacion.gps => 'GPS',
      OrigenUbicacion.red => 'red',
      OrigenUbicacion.ultimaConocida => 'última conocida',
      OrigenUbicacion.manual => 'manual',
    };
    return 'Ubicación guardada ($origen, ±${u.precisionM.round()} m) · '
        '${_hace(u.hora)}';
  }

  static String _textoEnvio(Sos? s) => switch (s?.envio) {
        EstadoEnvio.enviado => 'Enviada a tu comunidad'
            '${s?.ultimoEnvioOk == null ? '' : ' · ${_hace(s!.ultimoEnvioOk!)}'}',
        EstadoEnvio.enviando => 'Enviando…',
        EstadoEnvio.enEspera => 'Sin conexión: guardada en tu teléfono. '
            'Reintentamos sola.',
        _ => 'Guardada en tu teléfono',
      };

  static String _min(Duration d) => d.inMinutes >= 1
      ? '${d.inMinutes} min'
      : '${d.inSeconds} s';

  static String _textoEscalamiento(Sos? s, Duration? falta, ConfigSos c) {
    final numero = NumerosEmergencia.paraTipo(s?.tipo ?? '');
    final proxima = falta == null ? '' : ' La próxima pregunta es en ${_min(falta)}.';
    return 'Te preguntaremos cada pocos minutos si sigues bien.$proxima '
        'Si no respondes: a los ${_min(c.hastaAlarma)} suena una alarma, a los '
        '${_min(c.hastaAvisoLider)} avisamos a tu líder de comunidad y a tus '
        'contactos, y a los ${_min(c.hastaDerivar)} llamamos al $numero con tu '
        'última ubicación.';
  }
}

// ═════════════════════════ A dónde ir ═════════════════════════

class _Destino extends StatelessWidget {
  const _Destino({required this.sos});
  final Sos? sos;

  /// Redondeo a ~10 m: el mapa pequeño no se vuelve a crear por
  /// variaciones mínimas del GPS.
  static LatLng? _ll(PuntoGeo? p) => p == null
      ? null
      : LatLng(
          (p.lat * 10000).roundToDouble() / 10000,
          (p.lon * 10000).roundToDouble() / 10000,
        );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Recursos>(
      valueListenable: SosApp.recursos,
      builder: (context, recursos, _) {
        final u = sos?.ultimaUbicacion;
        final tipo = (sos?.tipo ?? '').toLowerCase();
        final destino = u == null
            ? const Destino(
                nombre: 'Buscando',
                punto: null,
                instruccion: 'Buscando tu ubicación para indicarte el lugar '
                    'seguro más cercano…',
              )
            : siguienteDestino(
                yo: u.punto,
                emergenciaMedica:
                    tipo.contains('médica') || tipo.contains('atrapada'),
                necesitaAccesible: false,
                recursos: recursos,
                hayRutaSegura: true,
              );
        final punto = destino.punto;
        final yo = _ll(u?.punto);
        final meta = _ll(punto);
        final esHospital = recursos.centrosSalud
            .any((c) => c.nombre == destino.nombre);
        return _Tarjeta(
          color: AppTheme.secondary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.directions_walk, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('Qué hacer ahora',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 8),
              Text(destino.instruccion,
                  style: const TextStyle(
                      fontSize: 16, color: AppTheme.texto, height: 1.3)),
              const SizedBox(height: 12),
              MapaMini(
                yo: yo,
                precisionM: u?.precisionM ?? 30,
                destino: meta,
                iconoDestino:
                    esHospital ? Icons.local_hospital : Icons.home_work,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MapaScreen(enfocar: meta ?? yo),
                  ),
                ),
              ),
              if (punto != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => MapaBase.comoLlegar(meta!),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Cómo llegar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════ «¿Sigues bien?» ═════════════════════════

class _AvisoSigueBien extends StatefulWidget {
  const _AvisoSigueBien({
    required this.etapa,
    required this.falta,
    required this.llamadaA,
    required this.onBien,
    required this.onAyuda,
  });

  final Etapa etapa;
  final Duration? falta;
  final String? llamadaA;
  final VoidCallback onBien;
  final VoidCallback onAyuda;

  @override
  State<_AvisoSigueBien> createState() => _AvisoSigueBienState();
}

class _AvisoSigueBienState extends State<_AvisoSigueBien>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  String get _titulo => switch (widget.etapa) {
        Etapa.preguntando => '¿Sigues bien?',
        Etapa.alarma => '¡Responde! ¿Sigues bien?',
        Etapa.avisoLider => 'Avisamos a tu líder de comunidad',
        Etapa.derivado => widget.llamadaA == null
            ? 'Pedimos ayuda a la central'
            : 'Llamando al ${widget.llamadaA}',
        _ => '',
      };

  String get _detalle {
    final f = widget.falta;
    final t = f == null ? '' : _Contenido._min(f);
    return switch (widget.etapa) {
      Etapa.preguntando => 'Toca un botón. Si no respondes en $t sonará una alarma.',
      Etapa.alarma => 'Si no respondes en $t avisaremos a tu líder y a tus contactos.',
      Etapa.avisoLider =>
        'Ya tienen tu última ubicación. En $t llamaremos a emergencias.',
      Etapa.derivado =>
        'Tu última ubicación fue enviada. Si puedes, toca «Estoy bien» o '
            '«Necesito ayuda».',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final fuerte = widget.etapa.index >= Etapa.alarma.index;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Container(
        color: Color.lerp(
          Colors.black.withAlpha(200),
          fuerte ? AppTheme.alerta : Colors.black.withAlpha(230),
          fuerte ? _anim.value : 0,
        ),
        child: child,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_active,
                  color: Colors.white, size: 64),
              const SizedBox(height: 12),
              Text(
                _titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _detalle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 72,
                child: ElevatedButton(
                  onPressed: widget.onBien,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verde,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Estoy bien',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 72,
                child: ElevatedButton(
                  onPressed: widget.onAyuda,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.alerta,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Necesito ayuda',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════ Piezas pequeñas ═════════════════════════

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}

class _FilaEstado extends StatelessWidget {
  const _FilaEstado({required this.icono, required this.titulo, required this.ok});
  final IconData icono;
  final String titulo;
  final bool ok;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icono, size: 20, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 14))),
          Icon(
            ok ? Icons.check_circle : Icons.schedule,
            size: 18,
            color: ok ? AppTheme.verde : AppTheme.amarillo,
          ),
        ],
      );
}

class _BotonSemaforo extends StatelessWidget {
  const _BotonSemaforo({
    required this.texto,
    required this.color,
    required this.elegido,
    required this.onTap,
    this.textoOscuro = false,
  });
  final String texto;
  final Color color;
  final bool elegido;
  final bool textoOscuro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: textoOscuro ? AppTheme.primary : Colors.white,
              padding: EdgeInsets.zero,
              side: elegido
                  ? const BorderSide(color: AppTheme.texto, width: 3)
                  : null,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(texto,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

class _BotonLlamar extends StatelessWidget {
  const _BotonLlamar(this.nombre, this.numero, this.onLlamar);
  final String nombre;
  final String numero;
  final Future<bool> Function(String numero) onLlamar;

  @override
  Widget build(BuildContext context) => Expanded(
        child: OutlinedButton(
          onPressed: () => onLlamar(numero),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.primary),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Column(
            children: [
              Text(numero,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              Text(nombre, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
}

/// Punto blanco que late, para que se note que el SOS está vivo.
class _Pulso extends StatefulWidget {
  const _Pulso();

  @override
  State<_Pulso> createState() => _PulsoState();
}

class _PulsoState extends State<_Pulso> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
        child: const Icon(Icons.circle, color: Colors.white, size: 16),
      );
}
