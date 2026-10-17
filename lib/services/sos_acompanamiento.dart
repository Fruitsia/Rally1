/// SOS con guardado automático, acompañamiento y escalamiento por etapas.
///
/// Implementa la sección 9 de «Variables_Emergencias_Nunc.docx».
/// La lógica no depende de plugins: las implementaciones reales de las
/// interfaces de abajo están en `sos_adaptadores.dart`.
///
/// Flujo:
///   1. Activar → se guarda en el teléfono ANTES de tocar la red.
///   2. Se toma la ubicación (GPS con límite de tiempo → última conocida).
///   3. Se envía (datos → SMS → cola con reintentos).
///   4. Cada pocos minutos se pregunta «¿Sigues bien?».
///   5. Si no responde: alarma fuerte → aviso al líder y contactos →
///      derivación a la central + llamada automática a la autoridad con la
///      última ubicación registrada.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:rally/models/emergencia_models.dart';

// ═════════════════════════ Datos del SOS ═════════════════════════

enum OrigenUbicacion { gps, red, ultimaConocida, manual }

enum Conectividad { datos, soloSms, sinSenal }

/// Estado del envío que ve la persona (igual que en los diseños).
enum EstadoEnvio { guardado, enviando, enviado, enEspera }

/// Etapa de escalamiento cuando la persona no responde.
enum Etapa { normal, preguntando, alarma, avisoLider, derivado, cerrado }

/// `sinRespuesta` → `sin_respuesta`. La base usa snake_case en sus `check`.
String aSnake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

T _enumDesde<T extends Enum>(List<T> valores, Object? texto, T porDefecto) {
  for (final v in valores) {
    if (v.name == texto || aSnake(v.name) == texto) return v;
  }
  return porDefecto;
}

class PuntoGps {
  const PuntoGps({
    required this.punto,
    required this.precisionM,
    required this.origen,
    required this.hora,
  });

  final PuntoGeo punto;
  final double precisionM;
  final OrigenUbicacion origen;
  final DateTime hora;

  Map<String, dynamic> toJson() => {
        'coordenadas': punto.toGeoJson(), // [lon, lat]
        'precision_m': precisionM,
        'origen': aSnake(origen.name),
        'hora': hora.toUtc().toIso8601String(),
      };

  factory PuntoGps.fromJson(Map<String, dynamic> j) => PuntoGps(
        punto: PuntoGeo.fromGeoJson(j['coordenadas'] as List<dynamic>),
        precisionM: (j['precision_m'] as num?)?.toDouble() ?? 0,
        origen: _enumDesde(
            OrigenUbicacion.values, j['origen'], OrigenUbicacion.ultimaConocida),
        hora: DateTime.parse(j['hora'] as String),
      );
}

class Sos {
  Sos({
    required this.sosId,
    required this.usuarioId,
    required this.tipo,
    required this.creado,
  });

  final String sosId; // se crea en el teléfono: los reintentos no duplican
  final String usuarioId;
  String tipo;
  final DateTime creado;

  final List<PuntoGps> ubicaciones = [];
  EstadoUsuario estadoUsuario = EstadoUsuario.emergencia;
  EstadoEnvio envio = EstadoEnvio.guardado;
  Etapa etapa = Etapa.normal;
  int? bateriaPct;
  Conectividad conectividad = Conectividad.datos;
  DateTime? ultimaInteraccion;
  DateTime? ultimoMovimiento;
  DateTime? ultimoEnvioOk;
  int? personasConUsuario;

  /// Datos de la zona (del perfil), para que el líder filtre por comunidad.
  String? departamento;
  String? municipio;
  String? comunidad;

  /// Número al que se llamó automáticamente (si se llegó a esa etapa).
  String? llamadaA;

  PuntoGps? get ultimaUbicacion => ubicaciones.isEmpty ? null : ubicaciones.last;
  bool get activo => etapa != Etapa.cerrado;

  Map<String, dynamic> toJson() => {
        'sos_id': sosId,
        'usuario_id': usuarioId,
        'tipo': tipo,
        'creado': creado.toUtc().toIso8601String(),
        'estado_usuario': aSnake(estadoUsuario.name),
        'etapa': aSnake(etapa.name),
        'envio': envio.name,
        'bateria_pct': bateriaPct,
        'conectividad': aSnake(conectividad.name),
        'ultima_interaccion': ultimaInteraccion?.toUtc().toIso8601String(),
        'ultimo_movimiento': ultimoMovimiento?.toUtc().toIso8601String(),
        'ultimo_envio_ok': ultimoEnvioOk?.toUtc().toIso8601String(),
        'personas_con_usuario': personasConUsuario,
        'departamento': departamento,
        'municipio': municipio,
        'comunidad': comunidad,
        'llamada_a': llamadaA,
        'ultima_ubicacion': ultimaUbicacion?.toJson(),
        // Solo los últimos puntos (más reciente primero) para que el envío
        // por datos móviles sea liviano.
        'ubicaciones':
            ubicaciones.reversed.take(20).map((u) => u.toJson()).toList(),
      };

  factory Sos.fromJson(Map<String, dynamic> j) {
    DateTime? fecha(String k) =>
        j[k] == null ? null : DateTime.tryParse(j[k] as String);
    final s = Sos(
      sosId: j['sos_id'] as String,
      usuarioId: j['usuario_id'] as String? ?? 'anonimo',
      tipo: j['tipo'] as String? ?? 'Emergencia',
      creado: DateTime.parse(j['creado'] as String),
    )
      ..estadoUsuario = _enumDesde(
          EstadoUsuario.values, j['estado_usuario'], EstadoUsuario.emergencia)
      ..etapa = _enumDesde(Etapa.values, j['etapa'], Etapa.normal)
      ..envio = _enumDesde(EstadoEnvio.values, j['envio'], EstadoEnvio.guardado)
      ..bateriaPct = (j['bateria_pct'] as num?)?.toInt()
      ..conectividad =
          _enumDesde(Conectividad.values, j['conectividad'], Conectividad.datos)
      ..ultimaInteraccion = fecha('ultima_interaccion')
      ..ultimoMovimiento = fecha('ultimo_movimiento')
      ..ultimoEnvioOk = fecha('ultimo_envio_ok')
      ..personasConUsuario = (j['personas_con_usuario'] as num?)?.toInt()
      ..departamento = j['departamento'] as String?
      ..municipio = j['municipio'] as String?
      ..comunidad = j['comunidad'] as String?
      ..llamadaA = j['llamada_a'] as String?;
    final lista = (j['ubicaciones'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(PuntoGps.fromJson)
        .toList()
        .reversed; // se guardan del más reciente al más antiguo
    s.ubicaciones.addAll(lista);
    return s;
  }

  /// Texto corto para SMS cuando no hay internet.
  String textoSms() {
    final u = ultimaUbicacion;
    final pos = u == null
        ? 'sin ubicacion'
        : 'https://maps.google.com/?q=${u.punto.lat.toStringAsFixed(5)},'
            '${u.punto.lon.toStringAsFixed(5)} (±${u.precisionM.round()}m)';
    final idCorto = sosId.length > 8 ? sosId.substring(0, 8) : sosId;
    return 'NUNC SOS $tipo $pos bat:${bateriaPct ?? '?'}% id:$idCorto';
  }
}

// ═════════════════════════ Interfaces (adaptadores) ═════════════════════════

abstract interface class Ubicador {
  /// Ubicación de alta precisión; null si no llega antes de [limite].
  Future<PuntoGps?> actual({required Duration limite});
  Future<PuntoGps?> ultimaConocida();
}

abstract interface class AlmacenLocal {
  Future<void> guardar(Sos sos);

  /// El último SOS guardado (para reanudarlo si la app se cerró).
  Future<Map<String, dynamic>?> leer();
}

abstract interface class Remoto {
  /// true si el servidor confirmó la recepción.
  Future<bool> enviar(Map<String, dynamic> datos);
  Future<bool> enviarSms(String texto);
  Future<void> avisarLiderYContactos(Sos sos);
  Future<void> derivarACentral(Sos sos);
}

abstract interface class Dispositivo {
  Future<int?> bateria();
  Future<Conectividad> conectividad();
  Future<void> alarmaFuerte(); // sonido + vibración
  Future<void> preguntarSiSigueBien(); // aviso «¿Sigues bien?»
}

abstract interface class Llamador {
  /// Intenta llamar. En Android con permiso llama directo; si no, abre el
  /// marcador con el número escrito. Devuelve true si se pudo iniciar.
  Future<bool> llamar(String numero);
}

// ═════════════════════════ Configuración ═════════════════════════

/// Números de emergencia de Nicaragua.
class NumerosEmergencia {
  static const policia = '118';
  static const bomberos = '115';
  static const ambulancia = '128';

  /// A quién llamar automáticamente según el tipo de emergencia.
  static String paraTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('médica') || t.contains('medica')) return ambulancia;
    if (t.contains('incendio')) return bomberos;
    return policia;
  }
}

class ConfigSos {
  const ConfigSos({
    this.limiteGps = const Duration(seconds: 10),
    this.reintento = const Duration(seconds: 30),
    this.gpsEnMovimiento = const Duration(seconds: 30),
    this.gpsQuieto = const Duration(minutes: 2),
    this.chequeo = const Duration(minutes: 5),
    this.chequeoEmergencia = const Duration(minutes: 3),
    this.hastaAlarma = const Duration(minutes: 2),
    this.hastaAvisoLider = const Duration(minutes: 5),
    this.hastaDerivar = const Duration(minutes: 10),
    this.movimientoReciente = const Duration(minutes: 2),
    this.metrosMovimiento = 25,
    this.bateriaBaja = 15,
    this.bateriaCritica = 5,
    this.llamarAlDerivar = true,
  });

  /// Tiempos cortos para probar en la presentación (todo pasa en ~2 min).
  const ConfigSos.demo()
      : this(
          chequeo: const Duration(seconds: 40),
          chequeoEmergencia: const Duration(seconds: 30),
          hastaAlarma: const Duration(seconds: 20),
          hastaAvisoLider: const Duration(seconds: 45),
          hastaDerivar: const Duration(seconds: 75),
          gpsEnMovimiento: const Duration(seconds: 15),
          gpsQuieto: const Duration(seconds: 30),
        );

  final Duration limiteGps;
  final Duration reintento;
  final Duration gpsEnMovimiento;
  final Duration gpsQuieto;
  final Duration chequeo;
  final Duration chequeoEmergencia;
  final Duration hastaAlarma;
  final Duration hastaAvisoLider;
  final Duration hastaDerivar;
  final Duration movimientoReciente;
  final double metrosMovimiento;
  final int bateriaBaja;
  final int bateriaCritica;
  final bool llamarAlDerivar;
}

// ═════════════════════════ Servicio ═════════════════════════

class SosAcompanamiento extends ChangeNotifier {
  SosAcompanamiento({
    required this.ubicador,
    required this.almacen,
    required this.remoto,
    required this.dispositivo,
    this.llamador,
    this.config = const ConfigSos(),
    DateTime Function()? reloj,
  }) : _ahora = reloj ?? DateTime.now;

  final Ubicador ubicador;
  final AlmacenLocal almacen;
  final Remoto remoto;
  final Dispositivo dispositivo;
  final Llamador? llamador;
  ConfigSos config;
  final DateTime Function() _ahora;

  Sos? _sos;
  Sos? get sos => _sos;
  bool get hayActivo => _sos != null && _sos!.activo;

  Timer? _gps;
  Timer? _reintento;
  Timer? _chequeo;
  Timer? _vigilante;
  DateTime? _preguntadoEn;
  DateTime? _proximoChequeo;
  bool _pospuesto = false;
  bool _enMovimiento = false;
  bool _enviando = false;
  bool _enviarOtraVez = false;
  bool _revisando = false;

  /// Cuándo se le preguntó «¿Sigues bien?» (null si no hay pregunta abierta).
  DateTime? get preguntadoEn => _preguntadoEn;

  /// Tiempo que falta para el siguiente paso, para mostrar una cuenta atrás.
  Duration? get faltaParaSiguientePaso {
    final s = _sos;
    if (s == null || !s.activo) return null;
    final desde = _preguntadoEn;
    if (desde == null) {
      final p = _proximoChequeo;
      return p == null ? null : _positivo(p.difference(_ahora()));
    }
    final espera = _ahora().difference(desde);
    final meta = switch (s.etapa) {
      Etapa.preguntando => config.hastaAlarma,
      Etapa.alarma => config.hastaAvisoLider,
      Etapa.avisoLider => config.hastaDerivar,
      _ => null,
    };
    return meta == null ? null : _positivo(meta - espera);
  }

  static Duration _positivo(Duration d) => d.isNegative ? Duration.zero : d;

  // ───────── 9.1 Activar ─────────

  Future<void> activar({
    required String sosId,
    required String usuarioId,
    required String tipo,
    String? departamento,
    String? municipio,
    String? comunidad,
  }) async {
    if (hayActivo) return; // ya hay uno activo

    final s = Sos(sosId: sosId, usuarioId: usuarioId, tipo: tipo, creado: _ahora())
      ..ultimaInteraccion = _ahora()
      ..departamento = departamento
      ..municipio = municipio
      ..comunidad = comunidad;
    _sos = s;
    _preguntadoEn = null;
    _pospuesto = false;

    // 1. Guardar primero, antes de cualquier red.
    await almacen.guardar(s);
    notifyListeners();

    // Los relojes arrancan ya: aunque la red tarde, el acompañamiento sigue.
    _arrancarRelojes();

    // 2. Ubicación con límite; si no llega, la última conocida.
    await _tomarUbicacion();

    // 3. Enviar (datos → SMS → cola).
    await _enviar();
  }

  /// Si la app se cerró con un SOS abierto, lo retoma. Devuelve true si había.
  Future<bool> reanudar() async {
    if (hayActivo) return true;
    try {
      final j = await almacen.leer();
      if (j == null) return false;
      final s = Sos.fromJson(j);
      if (!s.activo) return false;
      _sos = s;
      // Si quedó a mitad de una pregunta, se vuelve a preguntar desde cero.
      if (s.etapa == Etapa.preguntando) s.etapa = Etapa.normal;
      notifyListeners();
      _arrancarRelojes();
      unawaited(_tomarUbicacion().then((_) => _enviar()));
      return true;
    } catch (e) {
      debugPrint('No se pudo reanudar el SOS: $e');
      return false;
    }
  }

  void _arrancarRelojes() {
    _programarGps();
    _programarChequeo();
    _vigilante?.cancel();
    _vigilante =
        Timer.periodic(const Duration(seconds: 5), (_) => _revisarEtapa());
  }

  // ───────── Entradas de la persona y sensores ─────────

  /// «Estoy bien», «Necesito ayuda» o un cambio en el semáforo.
  Future<void> respondio({EstadoUsuario? estado}) async {
    final s = _sos;
    if (s == null || !s.activo) return;
    s.ultimaInteraccion = _ahora();
    if (estado != null) {
      s.estadoUsuario = estado;
    } else if (s.estadoUsuario == EstadoUsuario.sinRespuesta) {
      s.estadoUsuario = EstadoUsuario.emergencia;
    }
    s.etapa = Etapa.normal;
    _preguntadoEn = null;
    _pospuesto = false;
    await almacen.guardar(s);
    _programarChequeo();
    notifyListeners();
    await _enviar();
  }

  /// Cualquier toque en la pantalla del SOS. Si había una pregunta abierta,
  /// cuenta como respuesta; si no, solo se anota (sin gastar red).
  Future<void> toque() async {
    final s = _sos;
    if (s == null || !s.activo) return;
    if (s.etapa != Etapa.normal) return respondio();
    s.ultimaInteraccion = _ahora();
    _programarChequeo();
  }

  Future<void> cambiarTipo(String tipo) async {
    final s = _sos;
    if (s == null || !s.activo || s.tipo == tipo) return;
    s.tipo = tipo;
    await respondio();
  }

  /// Llamar cuando haya movimiento real (no ruido).
  void huboMovimiento() {
    final s = _sos;
    if (s == null) return;
    s.ultimoMovimiento = _ahora();
    if (!_enMovimiento) {
      _enMovimiento = true;
      _programarGps();
    }
  }

  void quieto() {
    if (_enMovimiento) {
      _enMovimiento = false;
      _programarGps();
    }
  }

  /// La persona llegó al refugio/hospital o el líder cerró el caso.
  Future<void> cerrar() async {
    final s = _sos;
    if (s == null) return;
    s
      ..etapa = Etapa.cerrado
      ..estadoUsuario = EstadoUsuario.aSalvo;
    _preguntadoEn = null;
    _cancelarTimers();
    await almacen.guardar(s);
    notifyListeners();
    await _enviar();
  }

  /// Llamada manual (botones 118 / 128 / 115).
  Future<bool> llamar(String numero) async {
    await toque();
    return await llamador?.llamar(numero) ?? false;
  }

  // ───────── 9.2 Guardado automático ─────────

  Future<void> _tomarUbicacion() async {
    final s = _sos;
    if (s == null) return;

    PuntoGps? p;
    try {
      p = await ubicador.actual(limite: config.limiteGps) ??
          await ubicador.ultimaConocida();
    } catch (e) {
      debugPrint('Ubicación no disponible: $e');
    }

    if (p != null) {
      final anterior = s.ultimaUbicacion;
      s.ubicaciones.add(p);
      if (s.ubicaciones.length > 200) s.ubicaciones.removeAt(0);
      // Movimiento a partir del GPS: más de N metros (y más que el error).
      if (anterior != null) {
        final metros = anterior.punto.distanciaKm(p.punto) * 1000;
        final umbral = [config.metrosMovimiento, p.precisionM, anterior.precisionM]
            .reduce((a, b) => a > b ? a : b);
        if (metros > umbral) {
          huboMovimiento();
        } else {
          quieto();
        }
      }
    }

    try {
      s.bateriaPct = await dispositivo.bateria();
      s.conectividad = await dispositivo.conectividad();
    } catch (_) {}
    await almacen.guardar(s);
    notifyListeners();

    // Batería crítica: mandar ya la última ubicación y avisar al líder,
    // sin marcar a la persona como «sin respuesta».
    final b = s.bateriaPct;
    if (b != null &&
        b <= config.bateriaCritica &&
        s.etapa.index < Etapa.avisoLider.index) {
      await _enviar();
      try {
        await remoto.avisarLiderYContactos(s);
      } catch (_) {}
    }
  }

  void _programarGps() {
    _gps?.cancel();
    final s = _sos;
    if (s == null || !s.activo) return;
    var cada = _enMovimiento ? config.gpsEnMovimiento : config.gpsQuieto;
    final b = s.bateriaPct;
    if (b != null && b <= config.bateriaBaja) cada *= 2; // ahorro de batería
    _gps = Timer.periodic(cada, (_) async {
      await _tomarUbicacion();
      await _enviar();
    });
  }

  Future<void> _enviar() async {
    final s = _sos;
    if (s == null) return;
    // Si ya hay un envío en curso, se repite al terminar (sin duplicar).
    if (_enviando) {
      _enviarOtraVez = true;
      return;
    }
    _enviando = true;
    s.envio = EstadoEnvio.enviando;
    notifyListeners();

    var ok = false;
    if (s.conectividad == Conectividad.datos) {
      try {
        ok = await remoto.enviar(s.toJson());
      } catch (e) {
        debugPrint('SOS en espera: $e');
        ok = false;
      }
    }
    if (!ok && s.conectividad != Conectividad.sinSenal) {
      try {
        ok = await remoto.enviarSms(s.textoSms());
      } catch (_) {
        ok = false;
      }
    }

    s.envio = ok ? EstadoEnvio.enviado : EstadoEnvio.enEspera;
    if (ok) s.ultimoEnvioOk = _ahora();
    await almacen.guardar(s);
    _enviando = false;
    notifyListeners();

    _reintento?.cancel();
    if (_enviarOtraVez) {
      _enviarOtraVez = false;
      await _enviar();
    } else if (!ok && s.activo) {
      _reintento = Timer(config.reintento, () async {
        try {
          _sos?.conectividad = await dispositivo.conectividad();
        } catch (_) {}
        await _enviar();
      });
    }
  }

  // ───────── 9.4 Escalamiento ─────────

  void _programarChequeo() {
    _chequeo?.cancel();
    final s = _sos;
    if (s == null || !s.activo) return;
    final cada = s.estadoUsuario == EstadoUsuario.aSalvo ||
            s.estadoUsuario == EstadoUsuario.precaucion
        ? config.chequeo
        : config.chequeoEmergencia;
    _proximoChequeo = _ahora().add(cada);
    _chequeo = Timer(cada, () async {
      final s = _sos;
      if (s == null || !s.activo) return;
      s.etapa = Etapa.preguntando;
      _preguntadoEn = _ahora();
      _proximoChequeo = null;
      notifyListeners();
      try {
        await dispositivo.preguntarSiSigueBien();
      } catch (_) {}
    });
  }

  Future<void> _revisarEtapa() async {
    final s = _sos;
    final desde = _preguntadoEn;
    if (s == null || !s.activo) return;
    if (desde == null) {
      notifyListeners(); // refresca la cuenta atrás
      return;
    }
    if (_revisando) return;
    _revisando = true;
    try {
      var espera = _ahora().difference(desde);

      // Si se movió hace poco, probablemente va caminando: posponer una vez.
      final mov = s.ultimoMovimiento;
      final seMueve =
          mov != null && _ahora().difference(mov) < config.movimientoReciente;
      if (seMueve && !_pospuesto && espera >= config.hastaAlarma) {
        _pospuesto = true;
        final mitad = config.hastaAlarma ~/ 2;
        _preguntadoEn = _ahora().subtract(mitad);
        espera = mitad;
      }

      if (espera >= config.hastaDerivar && s.etapa.index < Etapa.derivado.index) {
        await _derivar();
      } else if (espera >= config.hastaAvisoLider &&
          s.etapa.index < Etapa.avisoLider.index) {
        await _avisarLider();
      } else if (espera >= config.hastaAlarma &&
          s.etapa.index < Etapa.alarma.index) {
        s.etapa = Etapa.alarma;
        notifyListeners();
        try {
          await dispositivo.alarmaFuerte();
        } catch (_) {}
        await _enviar();
      } else if (s.etapa == Etapa.alarma || s.etapa == Etapa.avisoLider) {
        // La alarma se repite mientras no haya respuesta.
        try {
          await dispositivo.alarmaFuerte();
        } catch (_) {}
      }
    } finally {
      _revisando = false;
      notifyListeners();
    }
  }

  Future<void> _avisarLider() async {
    final s = _sos!;
    s
      ..etapa = Etapa.avisoLider
      ..estadoUsuario = EstadoUsuario.sinRespuesta;
    await almacen.guardar(s);
    notifyListeners();
    await _enviar();
    try {
      await remoto.avisarLiderYContactos(s);
    } catch (_) {}
  }

  /// Último paso: la central recibe el caso y se llama a la autoridad con la
  /// última ubicación registrada.
  Future<void> _derivar() async {
    final s = _sos!;
    s
      ..etapa = Etapa.derivado
      ..estadoUsuario = EstadoUsuario.sinRespuesta;
    // Ubicación lo más fresca posible antes de llamar.
    await _tomarUbicacion();
    await almacen.guardar(s);
    notifyListeners();
    await _enviar();
    try {
      await remoto.derivarACentral(s);
    } catch (_) {}

    if (config.llamarAlDerivar && llamador != null && s.llamadaA == null) {
      final numero = NumerosEmergencia.paraTipo(s.tipo);
      s.llamadaA = numero;
      await almacen.guardar(s);
      notifyListeners();
      try {
        await llamador!.llamar(numero);
      } catch (e) {
        debugPrint('No se pudo llamar a $numero: $e');
      }
    }
  }

  void _cancelarTimers() {
    for (final t in [_gps, _reintento, _chequeo, _vigilante]) {
      t?.cancel();
    }
    _proximoChequeo = null;
  }

  @override
  void dispose() {
    _cancelarTimers();
    super.dispose();
  }
}

// ═════════════════════════ 9.3 Acompañamiento: a dónde ir ═════════════════════════

class Destino {
  const Destino({required this.nombre, required this.punto, required this.instruccion});
  final String nombre;
  final PuntoGeo? punto;
  final String instruccion;
}

/// Una sola instrucción clara. La ruta exacta la calcula el mapa con
/// [elegirVia] y las vías de la zona.
Destino siguienteDestino({
  required PuntoGeo yo,
  required bool emergenciaMedica,
  required bool necesitaAccesible,
  required Recursos recursos,
  required bool hayRutaSegura,
}) {
  if (!hayRutaSegura) {
    return const Destino(
      nombre: 'Lugar seguro',
      punto: null,
      instruccion: 'Quédate en un lugar seguro. Tu ubicación ya fue enviada.',
    );
  }

  if (emergenciaMedica) {
    final centros = recursos.centrosSalud.where((c) => c.camasLibres > 0).toList()
      ..sort((a, b) => yo.distanciaKm(a.ubicacion).compareTo(yo.distanciaKm(b.ubicacion)));
    if (centros.isNotEmpty) {
      final c = centros.first;
      return Destino(
        nombre: c.nombre,
        punto: c.ubicacion,
        instruccion: 'Dirígete a ${c.nombre} '
            '(${yo.distanciaKm(c.ubicacion).toStringAsFixed(1)} km). Tiene camas disponibles.',
      );
    }
  }

  final albergues = recursos.albergues
      .where((a) => a.cuposLibres > 0 && (!necesitaAccesible || a.accesible))
      .toList()
    ..sort((a, b) => yo.distanciaKm(a.ubicacion).compareTo(yo.distanciaKm(b.ubicacion)));
  if (albergues.isNotEmpty) {
    final a = albergues.first;
    return Destino(
      nombre: a.nombre,
      punto: a.ubicacion,
      instruccion: 'Ve al albergue ${a.nombre} '
          '(${yo.distanciaKm(a.ubicacion).toStringAsFixed(1)} km). Quedan ${a.cuposLibres} cupos.',
    );
  }

  return const Destino(
    nombre: 'Lugar seguro',
    punto: null,
    instruccion: 'No hay albergues con cupo registrados cerca. Quédate en un '
        'lugar seguro; tu líder de comunidad ya tiene tu ubicación.',
  );
}
