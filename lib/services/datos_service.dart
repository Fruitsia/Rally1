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

  /// Reportes recientes (sin datos personales) para "Pasó esto en ...".
  /// Usa la función `puntos_mapa()` de la base.
  static Future<List<Publicacion>> publicacionesRecientes({
    String? municipio,
  }) async {
    try {
      final filas = (await _db.rpc('puntos_mapa').timeout(_espera) as List)
          .cast<Map<String, dynamic>>()
          .where((f) =>
              municipio == null ||
              municipio.isEmpty ||
              f['municipio'] == municipio)
          .toList()
        ..sort((a, b) =>
            (b['creado_en'] as String).compareTo(a['creado_en'] as String));
      return filas.take(10).map((f) {
        final nivel = NivelRiesgo.values.byName(f['nivel'] as String);
        return Publicacion(
          nivel: nivel,
          titulo: etiquetaCodigo(f['tipo'] as String, nivel),
          lugar: (f['comunidad'] ?? f['municipio'] ?? 'Sin zona') as String,
          hace: _hace(DateTime.parse(f['creado_en'] as String)),
        );
      }).toList();
    } catch (e) {
      debugPrint('Publicaciones sin conexión: $e');
      return DatosEjemplo.publicaciones;
    }
  }

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
