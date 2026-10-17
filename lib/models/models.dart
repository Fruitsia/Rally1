import 'package:flutter/material.dart';
import 'package:rally/core/theme.dart';

/// Tríada del semáforo.
enum NivelRiesgo { verde, amarillo, rojo }

extension NivelRiesgoX on NivelRiesgo {
  String get etiqueta => switch (this) {
        NivelRiesgo.verde => 'Estoy a salvo',
        NivelRiesgo.amarillo => 'Estado de precaución',
        NivelRiesgo.rojo => 'Emergencia',
      };

  Color get color => switch (this) {
        NivelRiesgo.verde => AppTheme.verde,
        NivelRiesgo.amarillo => AppTheme.amarillo,
        NivelRiesgo.rojo => AppTheme.alerta,
      };
}

const tiposEmergencia = <String>[
  'Terremoto',
  'Inundación',
  'Emergencia médica',
  'Incendio',
  'Deslizamiento de tierra',
  'Huracán / tormenta',
  'Persona atrapada',
  'Otro',
];

/// Código que se guarda en la columna `reportes.tipo` de Supabase.
String codigoTipo(String tipo) => switch (tipo) {
      'Terremoto' => 'terremoto',
      'Inundación' => 'inundacion',
      'Emergencia médica' => 'emergencia_medica',
      'Incendio' => 'incendio',
      'Deslizamiento de tierra' => 'deslizamiento',
      'Huracán / tormenta' => 'huracan',
      'Persona atrapada' => 'persona_atrapada',
      'Estoy a salvo' || 'Estado de precaución' => 'estado_personal',
      _ => 'otro',
    };

/// Texto para mostrar a partir del código de la base.
String etiquetaCodigo(String codigo, NivelRiesgo nivel) => codigo ==
        'estado_personal'
    ? nivel.etiqueta
    : tiposEmergencia.firstWhere((t) => codigoTipo(t) == codigo,
        orElse: () => 'Otro');

IconData iconoTipo(String tipo) => switch (tipo) {
      'Terremoto' => Icons.landslide_outlined,
      'Inundación' => Icons.water_outlined,
      'Emergencia médica' => Icons.medical_services_outlined,
      'Incendio' => Icons.local_fire_department_outlined,
      'Deslizamiento de tierra' => Icons.terrain_outlined,
      'Huracán / tormenta' => Icons.storm_outlined,
      'Persona atrapada' => Icons.person_search_outlined,
      _ => Icons.report_outlined,
    };

class Reporte {
  Reporte({
    String? id,
    required this.nivel,
    required this.tipo,
    this.direccion = '',
    this.referencia = '',
    DateTime? creado,
    this.enviado = false,
    this.latitud,
    this.longitud,
    this.precisionM,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        creado = creado ?? DateTime.now();

  final String id;
  final NivelRiesgo nivel;
  final String tipo;
  final String direccion;
  final String referencia;
  final DateTime creado;
  bool enviado;

  /// Ubicación automática (GPS). null si no se pudo obtener.
  final double? latitud;
  final double? longitud;
  final double? precisionM;

  bool get tieneGps => latitud != null && longitud != null;

  Reporte copiarCon({
    String? tipo,
    String? direccion,
    String? referencia,
    double? latitud,
    double? longitud,
    double? precisionM,
  }) =>
      Reporte(
        id: id,
        nivel: nivel,
        tipo: tipo ?? this.tipo,
        direccion: direccion ?? this.direccion,
        referencia: referencia ?? this.referencia,
        creado: creado,
        latitud: latitud ?? this.latitud,
        longitud: longitud ?? this.longitud,
        precisionM: precisionM ?? this.precisionM,
      );

  /// Fila para la tabla `reportes` de Supabase (ver supabase/esquema.sql).
  /// `usuario_id` no se manda: Supabase lo pone solo (null si no hay sesión).
  Map<String, dynamic> aSupabase(Map<String, dynamic> perfil) => {
        'id_local': id,
        'nivel': nivel.name,
        'tipo': codigoTipo(tipo),
        'direccion': direccion,
        'referencia': referencia,
        'departamento': perfil['departamento'],
        'municipio': perfil['municipio'],
        'comunidad': perfil['comunidad'],
        'latitud': latitud,
        'longitud': longitud,
        'creado_en': creado.toUtc().toIso8601String(),
      };

  Map<String, dynamic> aJson() => {
        'id': id,
        'nivel': nivel.name,
        'tipo': tipo,
        'direccion': direccion,
        'referencia': referencia,
        'creado': creado.toIso8601String(),
        'enviado': enviado,
        'latitud': latitud,
        'longitud': longitud,
        'precision_m': precisionM,
      };

  factory Reporte.desdeJson(Map<String, dynamic> j) => Reporte(
        id: j['id'] as String,
        nivel: NivelRiesgo.values.byName(j['nivel'] as String),
        tipo: j['tipo'] as String,
        direccion: j['direccion'] as String? ?? '',
        referencia: j['referencia'] as String? ?? '',
        creado: DateTime.parse(j['creado'] as String),
        enviado: j['enviado'] as bool? ?? false,
        latitud: (j['latitud'] as num?)?.toDouble(),
        longitud: (j['longitud'] as num?)?.toDouble(),
        precisionM: (j['precision_m'] as num?)?.toDouble(),
      );
}

enum EstadoDonacion { enProceso, entregada }

/// Símbolo para mostrar a partir del código guardado en la base (NIO / USD).
String simboloMoneda(String codigo) => codigo == 'USD' ? r'US$' : r'C$';

class Donacion {
  Donacion({
    required this.fecha,
    required this.monto,
    required this.moneda,
    required this.fundacion,
    required this.proyecto,
    this.etapa = 1,
  });

  final DateTime fecha;
  final num monto;
  final String moneda; // 'C$' o 'US$'
  final String fundacion;
  final String proyecto;

  /// 1 recibida · 2 fondos asignados · 3 ayuda en camino · 4 entregada
  final int etapa;

  EstadoDonacion get estado =>
      etapa >= 4 ? EstadoDonacion.entregada : EstadoDonacion.enProceso;

  /// Fila de `donaciones` con `fundaciones(nombre, proyecto)` embebida.
  factory Donacion.desdeMapa(Map<String, dynamic> m) {
    final f = (m['fundaciones'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Donacion(
      fecha: DateTime.parse(m['creado_en'] as String).toLocal(),
      monto: m['monto'] as num,
      moneda: simboloMoneda(m['moneda'] as String? ?? 'NIO'),
      fundacion: f['nombre'] as String? ?? 'Fundación',
      proyecto: f['proyecto'] as String? ?? '',
      etapa: (m['etapa'] as num?)?.toInt() ?? 1,
    );
  }
}

class Fundacion {
  const Fundacion({
    this.id,
    this.moneda = 'NIO',
    required this.nombre,
    required this.descripcion,
    required this.proyecto,
    required this.progreso,
    required this.distancia,
  });

  final String? id; // null en los datos de ejemplo
  final String moneda; // NIO / USD
  final String nombre;
  final String descripcion;
  final String proyecto;
  final double progreso; // 0..1
  final String distancia;

  factory Fundacion.desdeMapa(Map<String, dynamic> m) {
    final meta = (m['meta'] as num?)?.toDouble() ?? 0;
    final rec = (m['recaudado'] as num?)?.toDouble() ?? 0;
    return Fundacion(
      id: m['id'] as String,
      moneda: m['moneda'] as String? ?? 'NIO',
      nombre: m['nombre'] as String,
      descripcion: m['descripcion'] as String? ?? '',
      proyecto: m['proyecto'] as String? ?? '',
      progreso: meta > 0 ? (rec / meta).clamp(0.0, 1.0) : 0,
      distancia: [m['municipio'], m['departamento']]
          .whereType<String>()
          .toSet()
          .join(', '),
    );
  }
}

class Noticia {
  const Noticia({
    required this.categoria,
    required this.titulo,
    required this.resumen,
    this.etiquetas = const [],
    this.region = 'Mundo',
    this.icono = Icons.public,
  });

  final String categoria;
  final String titulo;
  final String resumen;
  final List<String> etiquetas;
  final String region;
  final IconData icono;

  factory Noticia.desdeMapa(Map<String, dynamic> m) {
    final categoria = m['categoria'] as String? ?? 'General';
    return Noticia(
      categoria: categoria,
      titulo: m['titulo'] as String,
      resumen: m['resumen'] as String? ?? '',
      etiquetas: ((m['etiquetas'] as List?) ?? const []).cast<String>(),
      region: m['region'] as String? ?? 'Mundo',
      icono: switch (categoria.toLowerCase()) {
        'clima' => Icons.cloud_outlined,
        'comunidad' => Icons.groups_outlined,
        'prevención' || 'prevencion' => Icons.backpack_outlined,
        'economía' || 'economia' => Icons.trending_up,
        'salud' => Icons.health_and_safety_outlined,
        'ambiente' => Icons.eco_outlined,
        _ => Icons.public,
      },
    );
  }
}

/// Publicación de la comunidad en el feed nacional ("Pasó esto en ...").
class Publicacion {
  const Publicacion({
    required this.nivel,
    required this.titulo,
    required this.lugar,
    required this.hace,
  });

  final NivelRiesgo nivel;
  final String titulo;
  final String lugar;
  final String hace;
}

/// Punto afectado en el mapa (coordenadas reales).
class PuntoMapa {
  const PuntoMapa(
    this.lat,
    this.lon,
    this.nivel,
    this.titulo,
    this.lugar, {
    this.creado,
    this.esMio = false,
  });
  final double lat;
  final double lon;
  final NivelRiesgo nivel;
  final String titulo;
  final String lugar;
  final DateTime? creado;
  final bool esMio;
}
