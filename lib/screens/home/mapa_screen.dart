import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/models/emergencia_models.dart' show Recursos;
import 'package:rally/models/models.dart';
import 'package:rally/services/datos_service.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/services/sos_adaptadores.dart';
import 'package:rally/widgets/comunes.dart';
import 'package:rally/widgets/mapa_base.dart';
import 'package:rally/widgets/nav_bar.dart';

enum _Filtro { todos, emergencia, precaucion, albergues, salud }

extension on _Filtro {
  String get texto => switch (this) {
        _Filtro.todos => 'Todos',
        _Filtro.emergencia => 'Emergencia',
        _Filtro.precaucion => 'Precaución',
        _Filtro.albergues => 'Albergues',
        _Filtro.salud => 'Salud',
      };
}

/// "Mira los lugares afectados": mapa real con los reportes activos
/// (semáforo), albergues con cupo y centros de salud.
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key, this.enfocar});

  /// Punto a centrar al abrir (por ejemplo, el destino del SOS).
  final LatLng? enfocar;

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final _mapa = MapController();
  Timer? _refresco;

  _Filtro _filtro = _Filtro.todos;
  List<PuntoMapa> _puntos = const [];
  Recursos _recursos = const Recursos();
  bool _ejemplo = false;
  bool _cargando = true;
  bool _movidoPorPersona = false;
  bool _listo = false;

  LatLng? _yo;
  double _precision = 30;

  /// Marcadores ya construidos: solo se recalculan cuando cambian los datos
  /// o el filtro, no en cada movimiento del mapa.
  List<Marker> _marcadores = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
    _ubicarme(mover: widget.enfocar == null, avisar: false);
    // Actualiza solo cada minuto mientras el mapa está abierto.
    _refresco = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cargar(forzar: true, silencioso: true),
    );
  }

  @override
  void dispose() {
    _refresco?.cancel();
    _mapa.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool forzar = false, bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    final puntos = DatosService.puntosMapa(forzar: forzar);
    final recursos = RecursosSos.cargar(forzar: forzar);
    final p = await puntos;
    final r = await recursos;
    if (!mounted) return;
    setState(() {
      _puntos = p.puntos;
      _ejemplo = p.ejemplo;
      _recursos = r;
      _cargando = false;
      _marcadores = _construirMarcadores();
    });
  }

  Future<void> _ubicarme({bool mover = true, bool avisar = true}) async {
    final u = await GeoUbicador.instancia.rapida(
      limite: const Duration(seconds: 6),
    );
    if (!mounted) return;
    if (u == null) {
      if (avisar) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pudimos obtener tu ubicación. Revisa que el GPS '
              'esté activo y que NUNC tenga permiso.'),
        ));
      }
      return;
    }
    final yo = LatLng(u.punto.lat, u.punto.lon);
    setState(() {
      _yo = yo;
      _precision = u.precisionM;
    });
    if (mover && _listo && !_movidoPorPersona) _mapa.move(yo, 14);
  }

  void _centrarEnMi() {
    _movidoPorPersona = false;
    final yo = _yo;
    if (yo != null && _listo) _mapa.move(yo, 15);
    _ubicarme();
  }

  // ───────── Marcadores ─────────

  List<Marker> _construirMarcadores() {
    final f = _filtro;
    final lista = <Marker>[];

    bool verNivel(NivelRiesgo n) =>
        f == _Filtro.todos ||
        (f == _Filtro.emergencia && n == NivelRiesgo.rojo) ||
        (f == _Filtro.precaucion && n == NivelRiesgo.amarillo);

    // Reportes propios que aún no se enviaron (los enviados ya vienen de
    // la base y así no se duplican).
    final mios = ReporteService.instancia.pendientes
        .where((r) => r.tieneGps && r.nivel != NivelRiesgo.verde)
        .map((r) => PuntoMapa(
              r.latitud!,
              r.longitud!,
              r.nivel,
              r.tipo,
              'Tu reporte (en espera)',
              creado: r.creado,
              esMio: true,
            ));

    for (final p in [...mios, ..._puntos]) {
      if (!verNivel(p.nivel)) continue;
      final rojo = p.nivel == NivelRiesgo.rojo;
      lista.add(Marker(
        point: LatLng(p.lat, p.lon),
        width: 34,
        height: 34,
        child: MarcadorMapa(
          color: rojo ? AppTheme.alerta : AppTheme.amarillo,
          colorIcono: rojo ? Colors.white : AppTheme.primary,
          icono: rojo ? Icons.priority_high : Icons.warning_amber_rounded,
          destacado: p.esMio,
          onTap: () => _detallePunto(p),
        ),
      ));
    }

    if (f == _Filtro.todos || f == _Filtro.albergues) {
      for (final a in _recursos.albergues) {
        final punto = LatLng(a.ubicacion.lat, a.ubicacion.lon);
        lista.add(Marker(
          point: punto,
          width: 34,
          height: 34,
          child: MarcadorMapa(
            color: a.cuposLibres > 0 ? AppTheme.verde : AppTheme.grisTexto,
            icono: Icons.home_work,
            onTap: () => _detalleLugar(
              titulo: a.nombre,
              sub: a.cuposLibres > 0
                  ? 'Albergue · ${a.cuposLibres} cupos libres'
                      '${a.accesible ? ' · accesible' : ''}'
                  : 'Albergue · sin cupo',
              punto: punto,
              color: AppTheme.verde,
              icono: Icons.home_work,
            ),
          ),
        ));
      }
    }

    if (f == _Filtro.todos || f == _Filtro.salud) {
      for (final c in _recursos.centrosSalud) {
        final punto = LatLng(c.ubicacion.lat, c.ubicacion.lon);
        lista.add(Marker(
          point: punto,
          width: 34,
          height: 34,
          child: MarcadorMapa(
            color: _azul,
            icono: Icons.local_hospital,
            onTap: () => _detalleLugar(
              titulo: c.nombre,
              sub: 'Centro de salud · ${c.camasLibres} camas libres',
              punto: punto,
              color: _azul,
              icono: Icons.local_hospital,
            ),
          ),
        ));
      }
    }
    return lista;
  }

  static const _azul = Color(0xFF2F7DE1);

  void _elegirFiltro(_Filtro f) {
    if (f == _filtro) return;
    setState(() {
      _filtro = f;
      _marcadores = _construirMarcadores();
    });
  }

  // ───────── Detalles ─────────

  void _detallePunto(PuntoMapa p) {
    final creado = p.creado;
    _detalleLugar(
      titulo: p.titulo,
      sub: [
        p.lugar,
        p.nivel.etiqueta,
        if (creado != null) DatosService.hace(creado),
      ].join(' · '),
      punto: LatLng(p.lat, p.lon),
      color: p.nivel.color,
      icono: p.nivel == NivelRiesgo.rojo
          ? Icons.priority_high
          : Icons.warning_amber_rounded,
    );
  }

  void _detalleLugar({
    required String titulo,
    required String sub,
    required LatLng punto,
    required Color color,
    required IconData icono,
  }) {
    final yo = _yo;
    final km = yo == null
        ? null
        : const Distance().as(LengthUnit.Meter, yo, punto) / 1000;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color,
                    child: Icon(icono, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17)),
                        Text(sub,
                            style: const TextStyle(color: AppTheme.grisTexto)),
                        if (km != null)
                          Text('A ${km.toStringAsFixed(1)} km de ti',
                              style: const TextStyle(
                                  color: AppTheme.grisTexto, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    MapaBase.comoLlegar(punto);
                  },
                  icon: const Icon(Icons.directions),
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
          ),
        ),
      ),
    );
  }

  // ───────── UI ─────────

  @override
  Widget build(BuildContext context) {
    final enfocar = widget.enfocar;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EncabezadoSeccion(
              titulo: 'Mapa',
              accion: BotonIcono(
                icono: Icons.map_outlined,
                resaltado: true,
                tooltip: 'Volver',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final f in _Filtro.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(f.texto),
                        selected: _filtro == f,
                        onSelected: (_) => _elegirFiltro(f),
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color:
                              _filtro == f ? Colors.white : AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppTheme.primary),
                        showCheckmark: false,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: FlutterMap(
                      mapController: _mapa,
                      options: MapOptions(
                        initialCenter: enfocar ?? MapaBase.centroNicaragua,
                        initialZoom: enfocar == null ? 7 : 15,
                        minZoom: 5,
                        maxZoom: 19,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                        onMapReady: () {
                          _listo = true;
                          final yo = _yo;
                          if (yo != null && enfocar == null) _mapa.move(yo, 14);
                        },
                        onPositionChanged: (_, conGesto) {
                          if (conGesto) _movidoPorPersona = true;
                        },
                      ),
                      children: [
                        MapaBase.capaCalles(),
                        ...MapaBase.capasYo(_yo, _precision),
                        MarkerLayer(markers: _marcadores),
                        if (enfocar != null)
                          MarkerLayer(markers: [
                            Marker(
                              point: enfocar,
                              width: 40,
                              height: 40,
                              child: const MarcadorMapa(
                                color: AppTheme.verde,
                                icono: Icons.flag,
                                destacado: true,
                              ),
                            ),
                          ]),
                        MapaBase.credito(),
                      ],
                    ),
                  ),
                  if (_cargando)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  if (_ejemplo)
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 70,
                      child: _Aviso(
                        texto: 'Sin conexión: se muestran puntos de ejemplo.',
                        onReintentar: () => _cargar(forzar: true),
                      ),
                    )
                  else if (!_cargando && _marcadores.isEmpty)
                    const Positioned(
                      top: 10,
                      left: 12,
                      right: 70,
                      child: _Aviso(
                        texto: 'No hay reportes activos en las últimas 72 h.',
                      ),
                    ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Column(
                      children: [
                        _BotonMapa(
                          icono: Icons.my_location,
                          tooltip: 'Mi ubicación',
                          onTap: _centrarEnMi,
                        ),
                        const SizedBox(height: 8),
                        _BotonMapa(
                          icono: Icons.refresh,
                          tooltip: 'Actualizar',
                          onTap: () => _cargar(forzar: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _Leyenda(),
          ],
        ),
      ),
      floatingActionButton: BotonAlerta(
        onTap: () => Navigator.of(context).pushNamed(
          SosApp.servicio.hayActivo ? Rutas.sosActivo : Rutas.estado,
        ),
      ),
    );
  }
}

class _BotonMapa extends StatelessWidget {
  const _BotonMapa({
    required this.icono,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icono, color: AppTheme.primary),
        ),
      );
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, this.onReintentar});
  final String texto;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(texto, style: const TextStyle(fontSize: 12)),
              ),
              if (onReintentar != null)
                TextButton(
                  onPressed: onReintentar,
                  child: const Text('Reintentar'),
                ),
            ],
          ),
        ),
      );
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 12, color: c),
            const SizedBox(width: 4),
            Text(t, style: const TextStyle(fontSize: 12)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 96, 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            item(AppTheme.alerta, 'Emergencia'),
            item(AppTheme.amarillo, 'Precaución'),
            item(AppTheme.verde, 'Albergue'),
            item(const Color(0xFF2F7DE1), 'Salud / Tú'),
          ],
        ),
      ),
    );
  }
}
