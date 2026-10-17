/// Implementaciones reales de las interfaces de `sos_acompanamiento.dart`
/// (GPS, batería, red, guardado local, Supabase, SMS y llamadas) y el punto
/// de entrada único de la app: [SosApp].
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:android_intent_plus/android_intent.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rally/models/emergencia_models.dart';
import 'package:rally/models/models.dart' show NivelRiesgo, Reporte;
import 'package:rally/services/auth_service.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/services/sos_acompanamiento.dart';

bool get _esAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

// ═════════════════════════ Ubicación ═════════════════════════

class GeoUbicador implements Ubicador {
  GeoUbicador._();
  static final GeoUbicador instancia = GeoUbicador._();

  StreamSubscription<Position>? _seguimiento;
  Position? _ultimaDelSeguimiento;

  /// Pide permiso de ubicación. true si se puede usar el GPS.
  Future<bool> asegurarPermiso() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      return p == LocationPermission.whileInUse || p == LocationPermission.always;
    } catch (e) {
      debugPrint('Permiso de ubicación: $e');
      return false;
    }
  }

  /// Mantiene el GPS encendido aunque la persona salga de la app.
  /// En Android usa un servicio en primer plano (notificación fija
  /// «NUNC SOS activo»), así el sistema no cierra la app.
  Future<void> iniciarSeguimiento() async {
    if (_seguimiento != null) return;
    if (!await asegurarPermiso()) return;
    final LocationSettings ajustes = _esAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 15),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'NUNC · SOS activo',
              notificationText:
                  'Compartiendo tu ubicación con tu comunidad. Toca para abrir.',
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          );
    try {
      _seguimiento = Geolocator.getPositionStream(locationSettings: ajustes)
          .listen((p) => _ultimaDelSeguimiento = p,
              onError: (Object e) => debugPrint('Seguimiento GPS: $e'));
    } catch (e) {
      debugPrint('No se pudo iniciar el seguimiento: $e');
    }
  }

  Future<void> detenerSeguimiento() async {
    await _seguimiento?.cancel();
    _seguimiento = null;
  }

  // ignore: unnecessary_cast
  DateTime _hora(Position p) => (p.timestamp as DateTime?) ?? DateTime.now();

  PuntoGps _aPunto(Position p, OrigenUbicacion origen) => PuntoGps(
        punto: PuntoGeo(p.latitude, p.longitude),
        precisionM: p.accuracy,
        origen: origen,
        hora: _hora(p),
      );

  @override
  Future<PuntoGps?> actual({required Duration limite}) async {
    // Si el seguimiento ya tiene un punto reciente, se usa sin gastar batería.
    final s = _ultimaDelSeguimiento;
    if (s != null && DateTime.now().difference(_hora(s)) < limite) {
      return _aPunto(s, OrigenUbicacion.gps);
    }
    try {
      if (!await asegurarPermiso()) return null;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: limite,
        ),
      );
      return _aPunto(p, OrigenUbicacion.gps);
    } catch (e) {
      debugPrint('GPS sin respuesta: $e');
      return null;
    }
  }

  /// Ubicación sin hacer esperar a la persona: usa la del seguimiento o la
  /// última conocida si es reciente (< 2 min); si no, pide el GPS con un
  /// límite corto. Ideal para reportes y para centrar el mapa.
  Future<PuntoGps?> rapida({
    Duration limite = const Duration(seconds: 4),
  }) async {
    final ultima = await ultimaConocida();
    if (ultima != null &&
        DateTime.now().difference(ultima.hora) < const Duration(minutes: 2)) {
      return ultima;
    }
    return await actual(limite: limite) ?? ultima;
  }

  @override
  Future<PuntoGps?> ultimaConocida() async {
    final s = _ultimaDelSeguimiento;
    if (s != null) return _aPunto(s, OrigenUbicacion.ultimaConocida);
    if (kIsWeb) return null; // el navegador no guarda una última ubicación
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : _aPunto(p, OrigenUbicacion.ultimaConocida);
    } catch (_) {
      return null;
    }
  }
}

// ═════════════════════════ Guardado en el teléfono ═════════════════════════

class AlmacenPrefs implements AlmacenLocal {
  static const _clave = 'nunc_sos_activo';

  @override
  Future<void> guardar(Sos sos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, jsonEncode(sos.toJson()));
    } catch (e) {
      debugPrint('No se pudo guardar el SOS: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> leer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave);
      return crudo == null ? null : jsonDecode(crudo) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

// ═════════════════════════ Servidor (Supabase) y SMS ═════════════════════════

class RemotoSupabase implements Remoto {
  static const _espera = Duration(seconds: 10);
  SupabaseClient get _db => Supabase.instance.client;

  String? _sosCreado;
  final Set<String> _puntosEnviados = {};
  String? _smsAbiertoPara;
  List<String>? _telefonosContactos;

  @override
  Future<bool> enviar(Map<String, dynamic> d) async {
    final id = d['sos_id'] as String;
    final u = d['ultima_ubicacion'] as Map<String, dynamic>?;
    final c = u?['coordenadas'] as List<dynamic>?;
    final cerrado = d['etapa'] == 'cerrado';

    final fila = <String, dynamic>{
      'id': id,
      'tipo': d['tipo'],
      'estado_usuario': d['estado_usuario'],
      'etapa': d['etapa'],
      'bateria_pct': d['bateria_pct'],
      'conectividad': d['conectividad'],
      'ultima_latitud': c == null ? null : (c[1] as num).toDouble(),
      'ultima_longitud': c == null ? null : (c[0] as num).toDouble(),
      'ultima_precision_m': u?['precision_m'],
      'origen_ubicacion': u?['origen'],
      'ultima_interaccion': d['ultima_interaccion'],
      'ultimo_movimiento': d['ultimo_movimiento'],
      'personas_con_usuario': d['personas_con_usuario'],
      'departamento': d['departamento'],
      'municipio': d['municipio'],
      'comunidad': d['comunidad'],
      'actualizado_en': DateTime.now().toUtc().toIso8601String(),
      if (cerrado) 'cerrado_en': DateTime.now().toUtc().toIso8601String(),
    };

    if (_db.auth.currentUser != null) {
      // Con cuenta: se crea o se actualiza la misma fila.
      await _db.from('sos').upsert(fila).timeout(_espera);
    } else if (_sosCreado != id) {
      // Sin cuenta solo se puede crear (no actualizar): luego van las
      // ubicaciones nuevas en `sos_ubicaciones`.
      try {
        await _db.from('sos').insert(fila).timeout(_espera);
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow; // 23505 = ya existía
      }
    }
    _sosCreado = id;

    // Recorrido: solo los puntos que aún no se han subido.
    if (!cerrado) {
      final nuevos = (d['ubicaciones'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((p) => !_puntosEnviados.contains('$id|${p['hora']}'))
          .toList();
      if (nuevos.isNotEmpty) {
        await _db
            .from('sos_ubicaciones')
            .insert([
              for (final p in nuevos)
                {
                  'sos_id': id,
                  'latitud': ((p['coordenadas'] as List)[1] as num).toDouble(),
                  'longitud': ((p['coordenadas'] as List)[0] as num).toDouble(),
                  'precision_m': p['precision_m'],
                  'origen': p['origen'],
                  'hora': p['hora'],
                },
            ])
            .timeout(_espera);
        _puntosEnviados.addAll(nuevos.map((p) => '$id|${p['hora']}'));
      }
    }
    return true;
  }

  Future<List<String>> _contactos() async {
    if (_telefonosContactos != null) return _telefonosContactos!;
    final propios = <String>[];
    final tel = AuthService.perfil['telefono'] as String?;
    try {
      if (_db.auth.currentUser != null) {
        final filas = await _db
            .from('contactos_emergencia')
            .select('telefono')
            .limit(3)
            .timeout(_espera);
        propios.addAll(filas.map((f) => '${f['telefono']}'));
      }
    } catch (_) {}
    propios.removeWhere((t) => t.trim().isEmpty || t == tel);
    return _telefonosContactos = propios;
  }

  /// Sin internet: abre los mensajes con el texto y la ubicación ya escritos
  /// para los contactos de emergencia. Solo una vez por SOS (no molesta).
  @override
  Future<bool> enviarSms(String texto) async {
    if (kIsWeb) return false;
    final id = texto.split('id:').last;
    if (_smsAbiertoPara == id) return false;
    final numeros = await _contactos();
    if (numeros.isEmpty) return false;
    _smsAbiertoPara = id;
    try {
      final uri = Uri.parse(
          'sms:${numeros.join(',')}?body=${Uri.encodeComponent(texto)}');
      await launchUrl(uri);
    } catch (_) {}
    // Abrir el SMS no confirma la entrega: el SOS sigue «en espera».
    return false;
  }

  @override
  Future<void> avisarLiderYContactos(Sos sos) async {
    // El panel del líder escucha la tabla `sos` en tiempo real: la etapa
    // `aviso_lider` ya lo pone en «Requieren atención». Además, si no hay
    // internet, se preparan los SMS a los contactos.
    if (sos.conectividad != Conectividad.datos) {
      await enviarSms(sos.textoSms());
    }
  }

  @override
  Future<void> derivarACentral(Sos sos) async {
    // La etapa `derivado` ya se guardó con `enviar`. Aquí se conectará la
    // central municipal (Edge Function / webhook) cuando exista.
  }
}

// ═════════════════════════ Teléfono: batería, red, alarma ═════════════════════════

class DispositivoReal implements Dispositivo {
  final _bateria = Battery();
  final _red = Connectivity();

  @override
  Future<int?> bateria() async {
    try {
      return await _bateria.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Conectividad> conectividad() async {
    try {
      final r = await _red.checkConnectivity();
      if (r.isEmpty || r.every((x) => x == ConnectivityResult.none)) {
        // Sin datos. En el teléfono aún puede haber señal para SMS.
        return kIsWeb ? Conectividad.sinSenal : Conectividad.soloSms;
      }
      return Conectividad.datos;
    } catch (_) {
      return Conectividad.datos; // si no se sabe, se intenta por datos
    }
  }

  @override
  Future<void> alarmaFuerte() async {
    for (var i = 0; i < 6; i++) {
      await HapticFeedback.vibrate();
      await SystemSound.play(SystemSoundType.alert);
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  @override
  Future<void> preguntarSiSigueBien() async {
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
  }
}

// ═════════════════════════ Llamadas ═════════════════════════

class LlamadorReal implements Llamador {
  @override
  Future<bool> llamar(String numero) async {
    // Android con permiso: llamada directa, sin que la persona toque nada.
    if (_esAndroid) {
      try {
        if (await Permission.phone.isGranted) {
          await AndroidIntent(
            action: 'android.intent.action.CALL',
            data: 'tel:$numero',
          ).launch();
          return true;
        }
      } catch (e) {
        debugPrint('Llamada directa no disponible: $e');
      }
    }
    // Resto: abre el marcador con el número escrito.
    try {
      return await launchUrl(Uri(scheme: 'tel', path: numero));
    } catch (_) {
      return false;
    }
  }
}

// ═════════════════════════ Recursos: albergues y hospitales ═════════════════════════

class RecursosSos {
  static SupabaseClient get _db => Supabase.instance.client;

  static Recursos? _cache;
  static String? _cacheMunicipio;
  static DateTime? _cacheHora;

  /// Albergues activos y centros de salud operativos. Se guardan 2 min en
  /// memoria para que el mapa y el SOS no repitan la consulta.
  static Future<Recursos> cargar({String? municipio, bool forzar = false}) async {
    final hora = _cacheHora;
    if (!forzar &&
        _cache != null &&
        _cacheMunicipio == municipio &&
        hora != null &&
        DateTime.now().difference(hora) < const Duration(minutes: 2)) {
      return _cache!;
    }
    final r = await _consultar(municipio: municipio);
    if (r.albergues.isNotEmpty || r.centrosSalud.isNotEmpty) {
      _cache = r;
      _cacheMunicipio = municipio;
      _cacheHora = DateTime.now();
    }
    return r;
  }

  static Future<Recursos> _consultar({String? municipio}) async {
    try {
      var qa = _db.from('albergues').select().eq('activo', true);
      var qc = _db.from('centros_salud').select().eq('operativo', true);
      if (municipio != null && municipio.isNotEmpty) {
        qa = qa.ilike('municipio', municipio);
        qc = qc.ilike('municipio', municipio);
      }
      final res = await Future.wait([
        qa.limit(200).timeout(const Duration(seconds: 8)),
        qc.limit(200).timeout(const Duration(seconds: 8)),
      ]);
      double n(Object? v) => (v as num?)?.toDouble() ?? 0;
      int e(Object? v) => (v as num?)?.toInt() ?? 0;
      return Recursos(
        albergues: [
          for (final f in res[0])
            Albergue(
              id: '${f['id']}',
              nombre: '${f['nombre']}',
              ubicacion: PuntoGeo(n(f['latitud']), n(f['longitud'])),
              capacidad: e(f['capacidad']),
              ocupacion: e(f['ocupacion']),
              activo: f['activo'] == true,
              accesible: f['accesible'] == true,
            ),
        ],
        centrosSalud: [
          for (final f in res[1])
            CentroSalud(
              id: '${f['id']}',
              nombre: '${f['nombre']}',
              ubicacion: PuntoGeo(n(f['latitud']), n(f['longitud'])),
              operativo: f['operativo'] == true,
              camasTotales: e(f['camas_totales']),
              camasOcupadas: e(f['camas_ocupadas']),
            ),
        ],
      );
    } catch (e) {
      debugPrint('Recursos sin conexión: $e');
      return const Recursos();
    }
  }
}

// ═════════════════════════ Punto de entrada ═════════════════════════

/// Todo lo que la interfaz necesita del SOS.
class SosApp {
  SosApp._();

  /// Cambia a `ConfigSos.demo()` para la presentación (todo pasa en ~2 min).
  static const ConfigSos configuracion = ConfigSos();

  static final SosAcompanamiento servicio = SosAcompanamiento(
    ubicador: GeoUbicador.instancia,
    almacen: AlmacenPrefs(),
    remoto: RemotoSupabase(),
    dispositivo: DispositivoReal(),
    llamador: LlamadorReal(),
    config: configuracion,
  );

  /// Albergues y hospitales cercanos (se cargan al activar).
  static final ValueNotifier<Recursos> recursos = ValueNotifier(const Recursos());

  /// Activa el SOS. No espera a la red: la pantalla se muestra al instante.
  static Future<void> activar({String tipo = 'Emergencia'}) async {
    if (servicio.hayActivo) return;
    final perfil = AuthService.perfil;
    final usuario = AuthService.usuario?.id ?? 'anonimo';

    await _pedirPermisos();
    await servicio.activar(
      sosId: _uuidV4(),
      usuarioId: usuario,
      tipo: tipo,
      departamento: perfil['departamento'] as String?,
      municipio: perfil['municipio'] as String?,
      comunidad: perfil['comunidad'] as String?,
    );
    unawaited(GeoUbicador.instancia.iniciarSeguimiento());

    // El SOS también aparece como reporte rojo en el mapa de la comunidad.
    final u = servicio.sos?.ultimaUbicacion;
    unawaited(ReporteService.instancia.enviar(Reporte(
      nivel: NivelRiesgo.rojo,
      tipo: tipo,
      direccion: u == null ? 'SOS sin ubicación automática' : 'Ubicación GPS (SOS)',
      latitud: u?.punto.lat,
      longitud: u?.punto.lon,
      precisionM: u?.precisionM,
    )));

    recursos.value =
        await RecursosSos.cargar(municipio: perfil['municipio'] as String?);
    // Si en el municipio no hay nada registrado, se busca en todo el país.
    if (recursos.value.albergues.isEmpty && recursos.value.centrosSalud.isEmpty) {
      recursos.value = await RecursosSos.cargar();
    }
  }

  /// Al abrir la app: si quedó un SOS abierto, se retoma.
  static Future<bool> reanudar() async {
    final habia = await servicio.reanudar();
    if (habia) {
      unawaited(GeoUbicador.instancia.iniciarSeguimiento());
      unawaited(RecursosSos.cargar(
              municipio: AuthService.perfil['municipio'] as String?)
          .then((r) => recursos.value = r));
    }
    return habia;
  }

  static Future<void> cerrar() async {
    await servicio.cerrar();
    await GeoUbicador.instancia.detenerSeguimiento();
  }

  /// Ubicación (GPS), llamadas (para llamar solo si no responde) y
  /// notificaciones (para el aviso fijo del seguimiento).
  static Future<void> _pedirPermisos() async {
    await GeoUbicador.instancia.asegurarPermiso();
    if (_esAndroid) {
      try {
        await [Permission.phone, Permission.notification].request();
      } catch (_) {}
    }
  }

  static String _uuidV4() {
    final r = math.Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}
