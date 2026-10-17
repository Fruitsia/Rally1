import 'package:flutter/material.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/data/datos_ejemplo.dart';
import 'package:rally/models/models.dart';
import 'package:rally/widgets/comunes.dart';
import 'package:rally/widgets/nav_bar.dart';

/// "Mira los lugares afectados": mapa esquemático con puntos del semáforo.
class MapaScreen extends StatelessWidget {
  const MapaScreen({super.key});

  void _detalle(BuildContext context, PuntoMapa p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.background,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: p.nivel.color,
                child: const Text('!',
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Impact',
                        fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.titulo,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 17)),
                    Text('Zona ${p.lugar} · ${p.nivel.etiqueta}',
                        style: const TextStyle(color: AppTheme.grisTexto)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EncabezadoSeccion(
              titulo: 'Mapa',
              accion: BotonIcono(
                icono: Icons.map_outlined,
                resaltado: true,
                tooltip: 'Volver al feed',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Mira los lugares afectados',
                    style: AppTheme.tituloImpact),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final lado = c.biggest.shortestSide;
                    return Center(
                      child: SizedBox(
                        width: lado,
                        height: lado * 0.93,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: CustomPaint(painter: _PintorMapa()),
                            ),
                            for (final p in DatosEjemplo.puntosMapa)
                              Positioned(
                                left: p.x * lado - 15,
                                top: p.y * lado * 0.93 - 15,
                                child: _Marcador(
                                  punto: p,
                                  onTap: () => _detalle(context, p),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const _Leyenda(),
          ],
        ),
      ),
      floatingActionButton: BotonAlerta(
        onTap: () => Navigator.of(context).pushNamed(Rutas.estado),
      ),
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador({required this.punto, required this.onTap});
  final PuntoMapa punto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esRojo = punto.nivel == NivelRiesgo.rojo;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: esRojo ? AppTheme.alerta : AppTheme.amarillo,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        alignment: Alignment.center,
        child: const Text('!',
            style: TextStyle(
                color: Colors.white, fontFamily: 'Impact', fontSize: 18)),
      ),
    );
  }
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
      padding: const EdgeInsets.only(bottom: 24, left: 20, right: 96),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          item(AppTheme.alerta, 'Emergencia'),
          item(AppTheme.amarillo, 'Precaución'),
        ],
      ),
    );
  }
}

/// Dibuja la silueta del territorio (medida sobre el diseño).
class _PintorMapa extends CustomPainter {
  const _PintorMapa();

  static const _contorno = <Offset>[
    Offset(0.99, 0.00), Offset(0.62, 0.10), Offset(0.47, 0.25),
    Offset(0.24, 0.33), Offset(0.16, 0.30), Offset(0.13, 0.38),
    Offset(0.00, 0.48), Offset(0.04, 0.54), Offset(0.13, 0.59),
    Offset(0.25, 0.63), Offset(0.31, 0.79), Offset(0.43, 0.92),
    Offset(0.57, 0.95), Offset(0.72, 0.97), Offset(0.85, 1.00),
    Offset(0.87, 0.87), Offset(0.88, 0.62), Offset(0.91, 0.33),
    Offset(0.96, 0.14),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final ruta = Path()
      ..addPolygon(
        [for (final o in _contorno) Offset(o.dx * size.width, o.dy * size.height)],
        true,
      );
    canvas.drawPath(ruta, Paint()..color = const Color(0xFFF3D5DA));
    canvas.drawPath(
      ruta,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = AppTheme.primary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
