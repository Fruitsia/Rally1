import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rally/data/datos_ejemplo.dart';
import 'package:rally/models/models.dart';

/// Lecturas y escrituras de noticias, fundaciones, donaciones y preferencias.
/// Si no hay conexión, devuelve los datos de ejemplo para que la app no quede
/// vacía.
class DatosService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const _espera = Duration(seconds: 10);

  static Future<List<Noticia>> noticias(String ambito) async {
    try {
      final filas = await _db
          .from('noticias')
          .select()
          .eq('ambito', ambito)
          .order('destacado', ascending: false)
          .order('creado_en', ascending: false)
          .limit(30)
          .timeout(_espera);
      return filas.map(Noticia.desdeMapa).toList();
    } catch (e) {
      debugPrint('Noticias sin conexión: $e');
      return ambito == 'nacional'
          ? DatosEjemplo.noticiasNacionales
          : [
              DatosEjemplo.destacadoInternacional,
              ...DatosEjemplo.noticiasInternacionales,
            ];
    }
  }

  /// Filas de `puntos_mapa()` (reportes activos de las últimas 72 h, sin
  /// datos personales). Se guardan 30 s para que el feed y el mapa no hagan
  /// la misma consulta dos veces.
  static List<Map<String, dynamic>>? _cachePuntos;
  static DateTime? _cachePuntosHora;
  static Future<List<Map<String, dynamic>>>? _pidiendoPuntos;

  static Future<List<Map<String, dynamic>>> _filasPuntos({
    bool forzar = false,
  }) {
    final hora = _cachePuntosHora;
    if (!forzar &&
        _cachePuntos != null &&
        hora != null &&
        DateTime.now().difference(hora) < const Duration(seconds: 30)) {
      return Future.value(_cachePuntos);
    }
    // Si ya hay una consulta en curso, se reutiliza (sin duplicar).
    return _pidiendoPuntos ??= () async {
      try {
        final filas = (await _db.rpc('puntos_mapa').timeout(_espera) as List)
            .cast<Map<String, dynamic>>()
          ..sort((a, b) =>
              (b['creado_en'] as String).compareTo(a['creado_en'] as String));
        _cachePuntos = filas;
        _cachePuntosHora = DateTime.now();
        return filas;
      } finally {
        _pidiendoPuntos = null;
      }
    }();
  }

  static NivelRiesgo _nivel(Object? v) => NivelRiesgo.values.firstWhere(
        (n) => n.name == v,
        orElse: () => NivelRiesgo.amarillo,
      );

  /// Reportes recientes (sin datos personales) para "Pasó esto en ...".
  static Future<List<Publicacion>> publicacionesRecientes({
    String? municipio,
    bool forzar = false,
  }) async {
    try {
      final filas = (await _filasPuntos(forzar: forzar))
          .where((f) =>
              municipio == null ||
              municipio.isEmpty ||
              (f['municipio'] as String?)?.toLowerCase() ==
                  municipio.toLowerCase())
          .take(10);
      return filas.map((f) {
        final nivel = _nivel(f['nivel']);
        return Publicacion(
          nivel: nivel,
          titulo: etiquetaCodigo(f['tipo'] as String? ?? 'otro', nivel),
          lugar: (f['comunidad'] ?? f['municipio'] ?? 'Sin zona') as String,
          hace: _hace(DateTime.parse(f['creado_en'] as String)),
        );
      }).toList();
    } catch (e) {
      debugPrint('Publicaciones sin conexión: $e');
      return DatosEjemplo.publicaciones;
    }
  }

  /// Puntos con coordenadas para el mapa. `ejemplo` es true si no hubo
  /// conexión y se muestran datos de muestra.
  static Future<({List<PuntoMapa> puntos, bool ejemplo})> puntosMapa({
    bool forzar = false,
  }) async {
    try {
      final filas = await _filasPuntos(forzar: forzar);
      final puntos = <PuntoMapa>[];
      for (final f in filas) {
        final lat = (f['latitud'] as num?)?.toDouble();
        final lon = (f['longitud'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;
        final nivel = _nivel(f['nivel']);
        final creado = DateTime.tryParse(f['creado_en'] as String? ?? '');
        puntos.add(PuntoMapa(
          lat,
          lon,
          nivel,
          etiquetaCodigo(f['tipo'] as String? ?? 'otro', nivel),
          (f['comunidad'] ?? f['municipio'] ?? 'Sin zona') as String,
          creado: creado?.toLocal(),
        ));
        if (puntos.length >= 400) break; // suficiente y fluido
      }
      return (puntos: puntos, ejemplo: false);
    } catch (e) {
      debugPrint('Mapa sin conexión: $e');
      return (puntos: DatosEjemplo.puntosMapa, ejemplo: true);
    }
  }

  static String hace(DateTime fecha) => _hace(fecha);

  static String _hace(DateTime fecha) {
    final d = DateTime.now().difference(fecha.toLocal());
    if (d.inMinutes < 1) return 'ahora';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    return 'hace ${d.inDays} d';
  }

  static Future<List<Fundacion>> fundaciones() async {
    try {
      final filas = await _db
          .from('fundaciones')
          .select()
          .order('nombre')
          .timeout(_espera);
      return filas.map(Fundacion.desdeMapa).toList();
    } catch (e) {
      debugPrint('Fundaciones sin conexión: $e');
      return DatosEjemplo.fundaciones;
    }
  }

  static Future<List<Donacion>> misDonaciones() async {
    if (_db.auth.currentUser == null) return const [];
    try {
      final filas = await _db
          .from('donaciones')
          .select('monto, moneda, etapa, creado_en, fundaciones(nombre, proyecto)')
          .order('creado_en', ascending: false)
          .timeout(_espera);
      return filas.map(Donacion.desdeMapa).toList();
    } catch (e) {
      debugPrint('Donaciones sin conexión: $e');
      return DatosEjemplo.donaciones;
    }
  }

  /// Registra una donación. Lanza un error con mensaje legible si falla.
  static Future<void> donar(Fundacion f, num monto) async {
    if (_db.auth.currentUser == null) {
      throw Exception('Inicia sesión para donar.');
    }
    if (f.id == null) {
      throw Exception('Sin conexión: no se pudo registrar la donación.');
    }
    await _db.from('donaciones').insert({
      'fundacion_id': f.id,
      'monto': monto,
      'moneda': f.moneda,
    }).timeout(_espera);
  }

  // ───────── Contactos de emergencia (máx. 3) ─────────

  static Future<List<Map<String, dynamic>>> contactos() async {
    if (_db.auth.currentUser == null) return const [];
    return await _db
        .from('contactos_emergencia')
        .select('id, nombre, telefono, parentesco')
        .order('nombre')
        .timeout(_espera);
  }

  static Future<void> agregarContacto({
    required String nombre,
    required String telefono,
    String parentesco = '',
  }) async {
    await _db.from('contactos_emergencia').insert({
      'nombre': nombre,
      'telefono': telefono,
      'parentesco': parentesco,
    }).timeout(_espera);
  }

  static Future<void> borrarContacto(String id) async {
    await _db.from('contactos_emergencia').delete().eq('id', id).timeout(_espera);
  }

  /// Guarda una preferencia de Configuración en la tabla `preferencias`.
  /// Si no hay sesión o conexión, se queda solo en el teléfono.
  static Future<void> guardarPreferencia(String columna, Object valor) async {
    final id = _db.auth.currentUser?.id;
    if (id == null) return;
    try {
      await _db
          .from('preferencias')
          .update({columna: valor})
          .eq('user_id', id)
          .timeout(_espera);
    } catch (e) {
      debugPrint('Preferencia sin sincronizar: $e');
    }
  }

  /// Lee las preferencias guardadas en la nube (null si no hay).
  static Future<Map<String, dynamic>?> preferencias() async {
    final id = _db.auth.currentUser?.id;
    if (id == null) return null;
    try {
      return await _db
          .from('preferencias')
          .select()
          .eq('user_id', id)
          .maybeSingle()
          .timeout(_espera);
    } catch (_) {
      return null;
    }
  }
}
