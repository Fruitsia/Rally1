import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rally/core/theme.dart';

/// Piezas comunes de los mapas reales (OpenStreetMap, sin API key).
class MapaBase {
  MapaBase._();

  /// Centro de Nicaragua, para cuando aún no hay ubicación.
  static const centroNicaragua = LatLng(12.8654, -85.2072);

  /// Capa de calles de OpenStreetMap.
  static TileLayer capaCalles() => TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.rally',
        maxNativeZoom: 19,
      );

  /// Crédito obligatorio de OpenStreetMap.
  static Widget credito() => RichAttributionWidget(
        alignment: AttributionAlignment.bottomLeft,
        attributions: [
          TextSourceAttribution(
            'OpenStreetMap',
            onTap: () => launchUrl(
              Uri.parse('https://www.openstreetmap.org/copyright'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      );

  /// Abre Google Maps (o el navegador) con la ruta a pie hasta el punto.
  static Future<void> comoLlegar(LatLng p) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${p.latitude},${p.longitude}&travelmode=walking',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Marcadores de «tú estás aquí»: círculo de precisión + punto azul.
  static List<Widget> capasYo(LatLng? yo, double precisionM) {
    if (yo == null) return const [];
    return [
      CircleLayer(circles: [
        CircleMarker(
          point: yo,
          radius: precisionM.clamp(5, 500).toDouble(),
          useRadiusInMeter: true,
          color: const Color(0x332F7DE1),
          borderColor: const Color(0x662F7DE1),
          borderStrokeWidth: 1,
        ),
      ]),
      MarkerLayer(markers: [
        Marker(
          point: yo,
          width: 22,
          height: 22,
          child: const PuntoYo(),
        ),
      ]),
    ];
  }
}

/// Punto azul de la ubicación propia.
class PuntoYo extends StatelessWidget {
  const PuntoYo({super.key});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2F7DE1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
      );
}

/// Marcador redondo con ícono (incidentes, albergues, hospitales).
class MarcadorMapa extends StatelessWidget {
  const MarcadorMapa({
    super.key,
    required this.color,
    required this.icono,
    this.onTap,
    this.colorIcono = Colors.white,
    this.destacado = false,
  });

  final Color color;
  final IconData icono;
  final Color colorIcono;
  final VoidCallback? onTap;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: destacado ? AppTheme.texto : Colors.white,
            width: destacado ? 3 : 2,
          ),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        child: Center(child: Icon(icono, size: 18, color: colorIcono)),
      ),
    );
  }
}

/// Mapa pequeño, fijo (no se arrastra), para tarjetas como la del SOS.
/// Muestra tu ubicación y, si hay, el destino. Tocarlo llama a [onTap].
class MapaMini extends StatelessWidget {
  const MapaMini({
    super.key,
    required this.yo,
    this.precisionM = 30,
    this.destino,
    this.iconoDestino = Icons.home_work,
    this.onTap,
    this.alto = 170,
  });

  final LatLng? yo;
  final double precisionM;
  final LatLng? destino;
  final IconData iconoDestino;
  final VoidCallback? onTap;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final centro = yo ?? destino ?? MapaBase.centroNicaragua;
    final ambos = yo != null && destino != null;
    return SizedBox(
      height: alto,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RepaintBoundary(
          child: Stack(
            children: [
              FlutterMap(
                // La clave cambia con los puntos: así el encuadre se ajusta
                // cuando llega la ubicación o cambia el destino.
                key: ValueKey('$yo|$destino'),
                options: MapOptions(
                  initialCenter: centro,
                  initialZoom: yo == null && destino == null ? 6.5 : 14,
                  initialCameraFit: ambos
                      ? CameraFit.coordinates(
                          coordinates: [yo!, destino!],
                          padding: const EdgeInsets.all(36),
                          maxZoom: 16,
                        )
                      : null,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                  onTap: onTap == null ? null : (_, _) => onTap!(),
                ),
                children: [
                  MapaBase.capaCalles(),
                  if (ambos)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: [yo!, destino!],
                        strokeWidth: 3,
                        color: AppTheme.primary.withValues(alpha: 0.7),
                        pattern: StrokePattern.dashed(segments: const [8, 6]),
                      ),
                    ]),
                  if (destino != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: destino!,
                        width: 34,
                        height: 34,
                        child: MarcadorMapa(
                          color: AppTheme.verde,
                          icono: iconoDestino,
                        ),
                      ),
                    ]),
                  ...MapaBase.capasYo(yo, precisionM),
                ],
              ),
              if (onTap != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onTap,
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_full,
                                size: 14, color: AppTheme.primary),
                            SizedBox(width: 4),
                            Text('Ver mapa',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const Positioned(
                left: 6,
                bottom: 4,
                child: Text('© OpenStreetMap',
                    style: TextStyle(fontSize: 9, color: Colors.black54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
