import 'package:flutter/material.dart';

import 'package:rally/core/theme.dart';
import 'package:rally/models/models.dart';
import 'package:rally/screens/home/mapa_screen.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/services/datos_service.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/widgets/comunes.dart';

/// Pestaña Inicio: Feed nacional (comunidad + noticias) o internacional.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _alcance = 'Nacional';
  late Future<List<Noticia>> _nacionales = DatosService.noticias('nacional');
  late Future<List<Noticia>> _internacionales =
      DatosService.noticias('internacional');
  late Future<List<Publicacion>> _publicaciones = _cargarPublicaciones();

  static Future<List<Publicacion>> _cargarPublicaciones() =>
      DatosService.publicacionesRecientes(
        municipio: AuthService.perfil['municipio'] as String?,
      );

  Future<void> _recargar() async {
    setState(() {
      _publicaciones = _cargarPublicaciones();
      _nacionales = DatosService.noticias('nacional');
      _internacionales = DatosService.noticias('internacional');
    });
    await (_alcance == 'Nacional' ? _nacionales : _internacionales);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EncabezadoSeccion(
          titulo: 'Feed',
          accion: BotonIcono(
            icono: Icons.map_outlined,
            tooltip: 'Mapa',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MapaScreen()),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: _SelectorAlcance(
              valor: _alcance,
              onChanged: (v) => setState(() => _alcance = v),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _recargar,
            child: FutureBuilder<List<Noticia>>(
              future: _alcance == 'Nacional' ? _nacionales : _internacionales,
              builder: (context, snap) {
                final lista = snap.data ?? const <Noticia>[];
                final cargando =
                    snap.connectionState != ConnectionState.done;
                return _alcance == 'Nacional'
                    ? _FeedNacional(
                        noticias: lista,
                        cargando: cargando,
                        publicaciones: _publicaciones,
                      )
                    : _FeedInternacional(noticias: lista, cargando: cargando);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectorAlcance extends StatelessWidget {
  const _SelectorAlcance({required this.valor, required this.onChanged});
  final String valor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: Colors.white,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'Nacional', child: Text('Nacional')),
        PopupMenuItem(value: 'Internacional', child: Text('Internacional')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              valor,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

const _abajo = EdgeInsets.fromLTRB(16, 8, 16, 120);

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _FeedNacional extends StatelessWidget {
  const _FeedNacional({
    required this.noticias,
    required this.cargando,
    required this.publicaciones,
  });
  final List<Noticia> noticias;
  final bool cargando;
  final Future<List<Publicacion>> publicaciones;

  @override
  Widget build(BuildContext context) {
    final lugar = (AuthService.perfil['municipio'] as String?)?.trim();
    return ListenableBuilder(
      listenable: ReporteService.instancia,
      builder: (context, _) {
        final mios = ReporteService.instancia.reportes.take(3).toList();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: _abajo,
          children: [
            Text(
              'Pasó esto en ${lugar == null || lugar.isEmpty ? 'tu comunidad' : lugar}',
              style: AppTheme.tituloImpact,
            ),
            const SizedBox(height: 10),
            for (final r in mios)
              _TarjetaPublicacion(
                pub: Publicacion(
                  nivel: r.nivel,
                  titulo: r.tipo,
                  lugar: r.direccion.isEmpty ? 'Tu reporte' : r.direccion,
                  hace: r.enviado ? 'Enviado' : 'En espera de conexión',
                ),
                esMio: true,
              ),
            FutureBuilder<List<Publicacion>>(
              future: publicaciones,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const _Cargando();
                }
                final lista = snap.data ?? const <Publicacion>[];
                if (lista.isEmpty && mios.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('No hay reportes recientes en tu zona.'),
                  );
                }
                return Column(
                  children: [
                    for (final p in lista) _TarjetaPublicacion(pub: p),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            const Text('Noticias', style: AppTheme.tituloImpact),
            const SizedBox(height: 10),
            if (cargando) const _Cargando(),
            for (final n in noticias) _TarjetaNoticia(noticia: n),
            const _AvisoMuestra(),
          ],
        );
      },
    );
  }
}

class _TarjetaPublicacion extends StatelessWidget {
  const _TarjetaPublicacion({required this.pub, this.esMio = false});
  final Publicacion pub;
  final bool esMio;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: pub.nivel.color, width: 6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (esMio) ...[
                  const Pildora('TU REPORTE'),
                  const SizedBox(height: 6),
                ],
                Text(pub.titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${pub.lugar} · ${pub.hace}',
                    style: const TextStyle(
                        color: AppTheme.grisTexto, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.circle, size: 14, color: pub.nivel.color),
        ],
      ),
    );
  }
}

class _TarjetaNoticia extends StatelessWidget {
  const _TarjetaNoticia({required this.noticia});
  final Noticia noticia;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borde),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.placeholder,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(noticia.icono, color: AppTheme.primary, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Pildora(
                  noticia.categoria,
                  fondo: const Color(0xFFFFF0CC),
                  color: AppTheme.rojo,
                ),
                const SizedBox(height: 4),
                Text(noticia.titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  noticia.resumen.isEmpty
                      ? 'Ejemplo · ${noticia.region}'
                      : noticia.resumen,
                  style:
                      const TextStyle(color: AppTheme.grisTexto, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedInternacional extends StatelessWidget {
  const _FeedInternacional({required this.noticias, required this.cargando});
  final List<Noticia> noticias;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    if (cargando) return const _Cargando();
    if (noticias.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _abajo,
        children: const [Text('Aún no hay noticias internacionales.')],
      );
    }
    final d = noticias.first; // la consulta pone primero la destacada
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _abajo,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.rojo,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Pildora('DESTACADO'),
                  const Spacer(),
                  const Text('Ejemplo editorial',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 10),
              Text(d.titulo,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(d.resumen,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in d.etiquetas)
                    Pildora(e,
                        fondo: Colors.white.withValues(alpha: 0.15),
                        color: Colors.white),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text('Destacados',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Ver todos',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
        for (final n in noticias.skip(1)) _TarjetaNoticia(noticia: n),
        const _AvisoMuestra(),
      ],
    );
  }
}

class _AvisoMuestra extends StatelessWidget {
  const _AvisoMuestra();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borde),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contenido de muestra',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          SizedBox(height: 2),
          Text('Ejemplos editoriales; no son noticias en tiempo real.',
              style: TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
        ],
      ),
    );
  }
}
