import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rally/models/models.dart';

/// Envía reportes a Supabase y guarda en el teléfono los que no se pudieron
/// enviar (sin conexión) para reintentarlos después.
class ReporteService extends ChangeNotifier {
  ReporteService._();
  static final ReporteService instancia = ReporteService._();

  static const _claveLocal = 'nunc_reportes';
  static const _tiempoMaximo = Duration(seconds: 12);

  final List<Reporte> _reportes = [];
  RealtimeChannel? _canalAlertas;

  /// Quién recibe las alertas. Se reemplaza cada vez que se abre Inicio, para
  /// no llamar a una pantalla que ya se cerró (p. ej., después de cerrar sesión).
  void Function(Map<String, dynamic> alerta)? _alLlegar;

  /// Se activa cuando llega una alerta de la comunidad (tabla `alertas`).
  bool alertaActiva = false;

  List<Reporte> get reportes => List.unmodifiable(_reportes);
  List<Reporte> get pendientes => _reportes.where((r) => !r.enviado).toList();

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_claveLocal);
      if (crudo == null) return;
      final lista = (jsonDecode(crudo) as List).cast<Map<String, dynamic>>();
      _reportes
        ..clear()
        ..addAll(lista.map(Reporte.desdeJson));
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudieron leer reportes guardados: $e');
    }
  }

  Future<void> _guardar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _claveLocal,
        jsonEncode(_reportes.map((r) => r.aJson()).toList()),
      );
    } catch (e) {
      debugPrint('No se pudieron guardar reportes: $e');
    }
  }

  /// Intenta enviar el reporte. Devuelve `true` si llegó al servidor.
  /// Si falla, queda guardado como pendiente.
  Future<bool> enviar(Reporte reporte) async {
    final i = _reportes.indexWhere((r) => r.id == reporte.id);
    if (i >= 0) {
      _reportes[i] = reporte;
    } else {
      _reportes.insert(0, reporte);
    }

    try {
      final cliente = Supabase.instance.client;
      await cliente
          .from('reportes')
          .insert(reporte.aSupabase(
            cliente.auth.currentUser?.userMetadata ?? const {},
          ))
          .timeout(_tiempoMaximo);
      reporte.enviado = true;
    } on PostgrestException catch (e) {
      // 23505 = ya existía (se envió antes pero no recibimos la respuesta).
      reporte.enviado = e.code == '23505';
      if (!reporte.enviado) debugPrint('Reporte en espera: ${e.message}');
    } catch (e) {
      debugPrint('Reporte en espera: $e');
      reporte.enviado = false;
    }

    await _guardar();
    notifyListeners();
    return reporte.enviado;
  }

  /// Reintenta todos los pendientes. Devuelve cuántos se enviaron.
  Future<int> reintentarPendientes() async {
    var enviados = 0;
    for (final r in pendientes) {
      if (await enviar(r)) enviados++;
    }
    return enviados;
  }

  /// Escucha nuevas filas en la tabla `alertas` (Supabase Realtime).
  void escucharAlertas(void Function(Map<String, dynamic> alerta) alLlegar) {
    _alLlegar = alLlegar;
    if (_canalAlertas != null) return;
    try {
      _canalAlertas = Supabase.instance.client
          .channel('alertas_comunidad')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'alertas',
            callback: (payload) {
              alertaActiva = true;
              notifyListeners();
              _alLlegar?.call(payload.newRecord);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime no disponible: $e');
    }
  }

  /// Deja de entregar alertas a una pantalla que se va a cerrar.
  void dejarDeEscuchar(void Function(Map<String, dynamic> alerta) alLlegar) {
    if (_alLlegar == alLlegar) _alLlegar = null;
  }

  void descartarAlerta() {
    alertaActiva = false;
    notifyListeners();
  }
}
