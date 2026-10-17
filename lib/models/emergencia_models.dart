/// Variables para la toma de decisiones en emergencias municipales.
///
/// Implementa el documento «Variables_Emergencias_Nunc.docx».
/// Regla general: `null` significa «no se sabe», nunca «cero».
library;

import 'dart:math' as math;

// ═════════════════════════ 1. Convenciones ═════════════════════════

enum Fuente { ciudadano, liderComunidad, institucion, sensor, sistema }

/// Metadatos que lleva todo registro.
class Meta {
  const Meta({
    required this.id,
    required this.eventoId,
    required this.municipioId,
    this.zonaId,
    required this.actualizadoEn,
    required this.fuente,
    this.confiabilidad = 0.5,
  }) : assert(confiabilidad >= 0 && confiabilidad <= 1);

  final String id;
  final String eventoId;
  final String municipioId;
  final String? zonaId;
  final DateTime actualizadoEn; // siempre UTC
  final Fuente fuente;
  final double confiabilidad; // 0 a 1

  /// Un dato sin cambios por más de 30 min se muestra como desactualizado.
  bool desactualizado([Duration limite = const Duration(minutes: 30)]) =>
      DateTime.now().toUtc().difference(actualizadoEn) > limite;

  Map<String, dynamic> toJson() => {
        'id': id,
        'evento_id': eventoId,
        'municipio_id': municipioId,
        'zona_id': zonaId,
        'actualizado_en': actualizadoEn.toUtc().toIso8601String(),
        'fuente': fuente.name,
        'confiabilidad': confiabilidad,
      };

  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
        id: j['id'] as String,
        eventoId: j['evento_id'] as String,
        municipioId: j['municipio_id'] as String,
        zonaId: j['zona_id'] as String?,
        actualizadoEn: DateTime.parse(j['actualizado_en'] as String).toUtc(),
        fuente: _enum(Fuente.values, j['fuente'], Fuente.ciudadano),
        confiabilidad: (j['confiabilidad'] as num?)?.toDouble() ?? 0.5,
      );
}

/// Punto en WGS84. En GeoJSON el orden es [longitud, latitud].
class PuntoGeo {
  const PuntoGeo(this.lat, this.lon);
  final double lat;
  final double lon;

  List<double> toGeoJson() => [lon, lat];
  factory PuntoGeo.fromGeoJson(List<dynamic> c) =>
      PuntoGeo((c[1] as num).toDouble(), (c[0] as num).toDouble());

  /// Distancia en km (fórmula de Haversine).
  double distanciaKm(PuntoGeo o) {
    const r = 6371.0;
    final dLat = _rad(o.lat - lat);
    final dLon = _rad(o.lon - lon);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat)) * math.cos(_rad(o.lat)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _rad(double g) => g * math.pi / 180;
}

// ═════════════════════════ 2. Amenaza ═════════════════════════

enum TipoEvento { sismo, inundacion, huracan, deslizamiento, erupcion, incendio, tsunami, otro }

enum UnidadSeveridad { mmH, kmH, magnitud, metros, otra }

enum Fase { antes, durante, despues }

enum Tendencia { aumenta, estable, disminuye }

class Amenaza {
  const Amenaza({
    required this.meta,
    required this.tipoEvento,
    required this.severidadValor,
    required this.severidadUnidad,
    required this.fase,
    this.ventanaImpactoHoras,
    this.radioAfectacionKm,
    this.poligono,
    this.tendencia = Tendencia.estable,
  });

  final Meta meta;
  final TipoEvento tipoEvento;
  final double severidadValor;
  final UnidadSeveridad severidadUnidad;
  final Fase fase;

  /// 0 = impacto en curso; null = sin pronóstico (p. ej., sismos).
  final double? ventanaImpactoHoras;
  final double? radioAfectacionKm;

  /// Anillo exterior del polígono de impacto.
  final List<PuntoGeo>? poligono;
  final Tendencia tendencia;

  /// Severidad normalizada 0 a 1. Los umbrales son iniciales: calíbralos
  /// con INETER / SINAPRED.
  double get indiceSeveridad {
    final (min, max) = switch (severidadUnidad) {
      UnidadSeveridad.mmH => (10.0, 100.0), // lluvia
      UnidadSeveridad.kmH => (60.0, 250.0), // viento
      UnidadSeveridad.magnitud => (4.0, 8.0), // sismo
      UnidadSeveridad.metros => (0.5, 5.0), // crecida / oleaje
      UnidadSeveridad.otra => (0.0, 1.0),
    };
    return ((severidadValor - min) / (max - min)).clamp(0.0, 1.0);
  }

  /// Urgencia 0 a 1: 1 si el impacto ya ocurre, 0 si falta 24 h o más.
  double get urgencia {
    if (fase == Fase.durante) return 1;
    final h = ventanaImpactoHoras;
    if (h == null) return fase == Fase.despues ? 0.3 : 0.5;
    return 1 - math.min(h, 24) / 24;
  }

  /// ¿El punto está dentro del área de impacto?
  bool contiene(PuntoGeo p, {PuntoGeo? centro}) {
    final pol = poligono;
    if (pol != null && pol.length >= 3) return _puntoEnPoligono(p, pol);
    final r = radioAfectacionKm;
    if (r != null && centro != null) return p.distanciaKm(centro) <= r;
    return false;
  }
}

// ═════════════════════════ 3 y 4. Población y estado ═════════════════════════

enum EstadoUsuario { aSalvo, precaucion, emergencia, sinRespuesta }

class PoblacionZona {
  const PoblacionZona({
    required this.meta,
    required this.totalPersonas,
    this.totalFamilias,
    this.ninos = 0, // 0 a 12 años (Ley 287)
    this.adolescentes = 0, // 13 a 17
    this.adultosMayores = 0, // 60 o más (Ley 720)
    this.personasDiscapacidad = 0,
    this.embarazadas = 0,
    this.personasEvacuadas = 0,
    this.estados = const {},
  });

  final Meta meta;
  final int totalPersonas;
  final int? totalFamilias;
  final int ninos;
  final int adolescentes;
  final int adultosMayores;
  final int personasDiscapacidad;
  final int embarazadas;
  final int personasEvacuadas;

  /// Conteo de miembros registrados por estado (pantalla «Mi comunidad»).
  final Map<EstadoUsuario, int> estados;

  double get tasaEvacuacionPct =>
      totalPersonas == 0 ? 0 : (personasEvacuadas / totalPersonas * 100).clamp(0.0, 100.0);

  /// Puede haber doble conteo, por eso se limita a 1.
  double get proporcionVulnerable => totalPersonas == 0
      ? 0
      : ((ninos + adultosMayores + personasDiscapacidad + embarazadas) / totalPersonas)
          .clamp(0.0, 1.0);

  int get registrados => estados.values.fold(0, (a, b) => a + b);

  /// Proporción de miembros en emergencia o sin respuesta.
  double get proporcionCritica => registrados == 0
      ? 0
      : ((estados[EstadoUsuario.emergencia] ?? 0) +
              (estados[EstadoUsuario.sinRespuesta] ?? 0)) /
          registrados;
}

// ═════════════════════════ 5. Infraestructura ═════════════════════════

enum EstadoVia { transitable, solo4x4, soloAPie, bloqueada, desconocido }

class Via {
  Via({
    required this.id,
    required this.nombre,
    required this.estado,
    required this.trazo,
    required this.capacidadVehiculos,
    this.vehiculosEnRuta = 0,
  });

  final String id;
  final String nombre;
  EstadoVia estado;
  final List<PuntoGeo> trazo; // GeoJSON LineString
  final int capacidadVehiculos;
  int vehiculosEnRuta;

  /// Saturada al 80 % de su capacidad.
  bool get saturada =>
      capacidadVehiculos > 0 && vehiculosEnRuta / capacidadVehiculos >= 0.8;

  bool aptaPara({required bool es4x4}) => switch (estado) {
        EstadoVia.transitable => !saturada,
        EstadoVia.solo4x4 => es4x4 && !saturada,
        _ => false,
      };
}

enum EstadoServicio { operativo, parcial, caido, desconocido }

class Servicios {
  const Servicios({
    this.agua = EstadoServicio.desconocido,
    this.energia = EstadoServicio.desconocido,
    this.telecom = EstadoServicio.desconocido,
    this.coberturaAguaPct,
    this.coberturaEnergiaPct,
    this.coberturaTelecomPct,
  });

  final EstadoServicio agua;
  final EstadoServicio energia;
  final EstadoServicio telecom;
  final double? coberturaAguaPct;
  final double? coberturaEnergiaPct;
  final double? coberturaTelecomPct;

  /// Si las telecomunicaciones fallan, el SOS prioriza SMS y guardado local.
  bool get priorizarSms =>
      telecom == EstadoServicio.caido || telecom == EstadoServicio.parcial;
}

class CentroSalud {
  const CentroSalud({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.operativo,
    required this.camasTotales,
    required this.camasOcupadas,
  });

  final String id;
  final String nombre;
  final PuntoGeo ubicacion;
  final bool operativo;
  final int camasTotales;
  final int camasOcupadas;

  int get camasLibres => operativo ? math.max(0, camasTotales - camasOcupadas) : 0;
}

enum TipoPuntoCritico { gasolinera, puente, subestacion, quimicos, presa, otro }

class PuntoCritico {
  const PuntoCritico({
    required this.tipo,
    required this.nombre,
    required this.ubicacion,
    this.activo = true,
    this.radioSeguridadKm = 0.3,
  });

  final TipoPuntoCritico tipo;
  final String nombre;
  final PuntoGeo ubicacion;
  final bool activo; // representa peligro ahora
  final double radioSeguridadKm;

  bool afectaVia(Via v) =>
      activo && v.trazo.any((p) => p.distanciaKm(ubicacion) <= radioSeguridadKm);
}

// ═════════════════════════ 6. Recursos ═════════════════════════

class Albergue {
  const Albergue({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.capacidad,
    required this.ocupacion,
    this.activo = true,
    this.accesible = false,
  });

  final String id;
  final String nombre;
  final PuntoGeo ubicacion;
  final int capacidad;
  final int ocupacion;
  final bool activo;
  final bool accesible; // apto para personas con discapacidad

  int get cuposLibres => activo ? math.max(0, capacidad - ocupacion) : 0;
}

enum TipoEquipo { bomberos, saludCruzRoja, proteccionCivil, policia, brigadaComunitaria }

enum EstadoEquipo { disponible, enCamino, enSitio, descanso }

class Equipo {
  Equipo({
    required this.id,
    required this.tipo,
    required this.integrantes,
    this.estado = EstadoEquipo.disponible,
    this.es4x4 = false,
    this.reporteAsignado,
    this.viaAsignada,
  });

  final String id;
  final TipoEquipo tipo;
  final int integrantes;
  EstadoEquipo estado;
  final bool es4x4;
  String? reporteAsignado;
  String? viaAsignada;

  bool get ocupado =>
      estado == EstadoEquipo.enCamino || estado == EstadoEquipo.enSitio;
}

class Recursos {
  const Recursos({
    this.albergues = const [],
    this.centrosSalud = const [],
    this.equipos = const [],
    this.ambulanciasActivas = 0,
    this.ambulanciasAsignadas = 0,
    this.maquinariaPesada = 0,
    this.embarcaciones = 0,
    this.racionesAlimento = 0,
    this.litrosAgua = 0,
  });

  final List<Albergue> albergues;
  final List<CentroSalud> centrosSalud;
  final List<Equipo> equipos;
  final int ambulanciasActivas;
  final int ambulanciasAsignadas;
  final int maquinariaPesada;
  final int embarcaciones;
  final int racionesAlimento;
  final double litrosAgua;

  /// Mínimo de las normas Esfera: 15 L por persona al día.
  static const litrosPersonaDia = 15.0;

  int get alberguesActivos => albergues.where((a) => a.activo).length;
  int get capacidadAlbergues =>
      albergues.where((a) => a.activo).fold(0, (s, a) => s + a.capacidad);
  int get ocupacionAlbergues =>
      albergues.where((a) => a.activo).fold(0, (s, a) => s + a.ocupacion);
  int get cuposLibres => albergues.fold(0, (s, a) => s + a.cuposLibres);
  int get camasLibres => centrosSalud.fold(0, (s, c) => s + c.camasLibres);
  int get ambulanciasDisponibles => math.max(0, ambulanciasActivas - ambulanciasAsignadas);

  /// null si no hay nadie albergado (no aplica).
  double? get autonomiaAlimentosDias =>
      ocupacionAlbergues == 0 ? null : racionesAlimento / ocupacionAlbergues;

  double? get autonomiaAguaDias => ocupacionAlbergues == 0
      ? null
      : litrosAgua / (ocupacionAlbergues * litrosPersonaDia);
}

// ═════════════════════════ 7 y 8. Gobernanza y reglas ═════════════════════════

enum NivelAlerta { verde, amarilla, roja }

/// Umbrales configurables (sección 8.3). Ajustarlos con Protección Civil.
class ConfigDecision {
  const ConfigDecision({
    this.pesoSeveridad = 0.30,
    this.pesoVulnerabilidad = 0.25,
    this.pesoAislamiento = 0.15,
    this.pesoUrgencia = 0.15,
    this.pesoRespuesta = 0.15,
    this.saturacionMaxPct = 85,
    this.autonomiaMinDias = 3,
    this.maxSinRespuesta = 10,
  });

  final double pesoSeveridad;
  final double pesoVulnerabilidad;
  final double pesoAislamiento;
  final double pesoUrgencia;
  final double pesoRespuesta;
  final double saturacionMaxPct;
  final double autonomiaMinDias;
  final int maxSinRespuesta;
}

/// Una zona con todo lo necesario para decidir.
class SituacionZona {
  const SituacionZona({
    required this.zonaId,
    required this.amenaza,
    required this.poblacion,
    required this.vias,
    this.reportesMedicosSinAtender = 0,
  });

  final String zonaId;
  final Amenaza amenaza;
  final PoblacionZona poblacion;
  final List<Via> vias;
  final int reportesMedicosSinAtender;

  int get viasTransitables => vias.where((v) => v.estado == EstadoVia.transitable).length;
  int get viasSolo4x4 => vias.where((v) => v.estado == EstadoVia.solo4x4).length;
  int get viasBloqueadas => vias.where((v) => v.estado == EstadoVia.bloqueada).length;

  /// Proporción de vías bloqueadas o solo a pie.
  double get aislamiento {
    if (vias.isEmpty) return 1; // sin vías conocidas = peor caso
    final malas = vias
        .where((v) => v.estado == EstadoVia.bloqueada || v.estado == EstadoVia.soloAPie)
        .length;
    return malas / vias.length;
  }

  /// Índice de prioridad 0 a 100 (sección 8.1).
  double prioridad([ConfigDecision c = const ConfigDecision()]) =>
      100 *
      (c.pesoSeveridad * amenaza.indiceSeveridad +
          c.pesoVulnerabilidad * poblacion.proporcionVulnerable +
          c.pesoAislamiento * aislamiento +
          c.pesoUrgencia * amenaza.urgencia +
          c.pesoRespuesta * poblacion.proporcionCritica);
}

class EvaluacionMunicipal {
  const EvaluacionMunicipal({
    required this.capacidadLocalUsadaPct,
    required this.requiereEscalamiento,
    required this.motivos,
    required this.nivelSugerido,
    required this.zonasPorPrioridad,
  });

  final double capacidadLocalUsadaPct;
  final bool requiereEscalamiento;
  final List<String> motivos;

  /// Solo sugerencia para el coordinador. La alerta oficial la declara la autoridad.
  final NivelAlerta nivelSugerido;
  final List<SituacionZona> zonasPorPrioridad;
}

/// Calcula saturación, escalamiento y orden de zonas (secciones 8.1 a 8.3).
EvaluacionMunicipal evaluar({
  required List<SituacionZona> zonas,
  required Recursos recursos,
  NivelAlerta? alertaOficial,
  ConfigDecision config = const ConfigDecision(),
}) {
  // 8.2 Saturación: el recurso más lleno manda.
  double ratio(int usado, int total) => total == 0 ? 0 : usado / total;
  final camasTot = recursos.centrosSalud
      .where((c) => c.operativo)
      .fold(0, (s, c) => s + c.camasTotales);
  final saturacion = [
        ratio(recursos.ocupacionAlbergues, recursos.capacidadAlbergues),
        ratio(recursos.equipos.where((e) => e.ocupado).length, recursos.equipos.length),
        ratio(camasTot - recursos.camasLibres, camasTot),
      ].reduce(math.max) *
      100;

  // 8.3 Reglas de escalamiento.
  final motivos = <String>[];
  if (saturacion >= config.saturacionMaxPct) {
    motivos.add('Capacidad local al ${saturacion.toStringAsFixed(0)} %');
  }
  final agua = recursos.autonomiaAguaDias;
  if (agua != null && agua < config.autonomiaMinDias) {
    motivos.add('Agua para ${agua.toStringAsFixed(1)} días');
  }
  final comida = recursos.autonomiaAlimentosDias;
  if (comida != null && comida < config.autonomiaMinDias) {
    motivos.add('Alimentos para ${comida.toStringAsFixed(1)} días');
  }
  final medicos = zonas.fold(0, (s, z) => s + z.reportesMedicosSinAtender);
  if (recursos.ambulanciasDisponibles == 0 && medicos > 0) {
    motivos.add('Sin ambulancias y $medicos reporte(s) médico(s) pendientes');
  }
  for (final z in zonas) {
    final sinResp = z.poblacion.estados[EstadoUsuario.sinRespuesta] ?? 0;
    if (sinResp > config.maxSinRespuesta) {
      motivos.add('$sinResp personas sin respuesta en ${z.zonaId}');
    }
    final h = z.amenaza.ventanaImpactoHoras;
    if (alertaOficial == NivelAlerta.roja &&
        h != null &&
        h < 6 &&
        z.poblacion.tasaEvacuacionPct < 50) {
      motivos.add('${z.zonaId}: impacto en < 6 h y evacuación bajo 50 %');
    }
  }

  final ordenadas = [...zonas]
    ..sort((a, b) => b.prioridad(config).compareTo(a.prioridad(config)));
  final maxPrioridad = ordenadas.isEmpty ? 0.0 : ordenadas.first.prioridad(config);

  return EvaluacionMunicipal(
    capacidadLocalUsadaPct: saturacion,
    requiereEscalamiento: motivos.isNotEmpty,
    motivos: motivos,
    nivelSugerido: maxPrioridad >= 70 || motivos.isNotEmpty
        ? NivelAlerta.roja
        : maxPrioridad >= 40
            ? NivelAlerta.amarilla
            : NivelAlerta.verde,
    zonasPorPrioridad: ordenadas,
  );
}

// ═════════════════════════ 8.4 Asignación sin saturar accesos ═════════════════════════

/// Elige la mejor vía para un equipo o devuelve null (esperar en punto de reunión).
Via? elegirVia({
  required Equipo equipo,
  required List<Via> candidatas,
  required List<PuntoCritico> puntosCriticos,
  required List<Equipo> todos,
  required String reporteId,
}) {
  // Evita duplicados: ya va un equipo del mismo tipo a ese reporte.
  final duplicado = todos.any((e) =>
      e.id != equipo.id &&
      e.tipo == equipo.tipo &&
      e.reporteAsignado == reporteId &&
      e.ocupado);
  if (duplicado) return null;

  final aptas = candidatas
      .where((v) => v.aptaPara(es4x4: equipo.es4x4))
      .where((v) => !puntosCriticos.any((p) => p.afectaVia(v)))
      .toList()
    // La menos cargada primero.
    ..sort((a, b) => (a.vehiculosEnRuta / math.max(1, a.capacidadVehiculos))
        .compareTo(b.vehiculosEnRuta / math.max(1, b.capacidadVehiculos)));
  return aptas.isEmpty ? null : aptas.first;
}

/// Registra la asignación y ocupa un lugar en la vía.
void asignar(Equipo e, Via v, String reporteId) {
  e
    ..estado = EstadoEquipo.enCamino
    ..reporteAsignado = reporteId
    ..viaAsignada = v.id;
  v.vehiculosEnRuta++;
}

/// Al llegar o cancelar, libera el lugar en la vía.
void liberarVia(Equipo e, List<Via> vias, {required bool llego}) {
  for (final v in vias.where((v) => v.id == e.viaAsignada)) {
    v.vehiculosEnRuta = math.max(0, v.vehiculosEnRuta - 1);
  }
  e
    ..viaAsignada = null
    ..estado = llego ? EstadoEquipo.enSitio : EstadoEquipo.disponible;
  if (!llego) e.reporteAsignado = null;
}

// ═════════════════════════ utilidades ═════════════════════════

T _enum<T extends Enum>(List<T> values, Object? nombre, T defecto) =>
    values.firstWhere((v) => v.name == nombre, orElse: () => defecto);

bool _puntoEnPoligono(PuntoGeo p, List<PuntoGeo> pol) {
  var dentro = false;
  for (var i = 0, j = pol.length - 1; i < pol.length; j = i++) {
    final a = pol[i], b = pol[j];
    if ((a.lat > p.lat) != (b.lat > p.lat) &&
        p.lon < (b.lon - a.lon) * (p.lat - a.lat) / (b.lat - a.lat) + a.lon) {
      dentro = !dentro;
    }
  }
  return dentro;
}
