import 'package:flutter/material.dart';
import 'package:rally/models/models.dart';

/// Datos de muestra para las pantallas que aún no tienen backend.
/// Reemplázalos por consultas a Supabase cuando tengas las tablas.
class DatosEjemplo {
  static final fundaciones = <Fundacion>[
    const Fundacion(
      nombre: 'Fundación Manos Unidas',
      descripcion: 'Apoyo alimentario a familias',
      proyecto: 'Canastas alimentarias',
      progreso: 0.68,
      distancia: 'a 1.2 km',
    ),
    const Fundacion(
      nombre: 'Fundación Sonrisas',
      descripcion: 'Útiles y apoyo escolar',
      proyecto: 'Apoyo educativo',
      progreso: 0.41,
      distancia: 'a 3.5 km',
    ),
    const Fundacion(
      nombre: 'Techo Seguro',
      descripcion: 'Refugio temporal para damnificados',
      proyecto: 'Albergues',
      progreso: 0.23,
      distancia: 'a 6 km',
    ),
  ];

  static final donaciones = <Donacion>[
    Donacion(
      fecha: DateTime(2025, 10, 12),
      monto: 500,
      moneda: r'C$',
      fundacion: 'Fundación Manos Unidas',
      proyecto: 'Canastas alimentarias',
    ),
    Donacion(
      fecha: DateTime(2025, 9, 28),
      monto: 10,
      moneda: r'US$',
      fundacion: 'Fundación Sonrisas',
      proyecto: 'Apoyo educativo',
      etapa: 4,
    ),
  ];

  static const publicaciones = <Publicacion>[
    Publicacion(
      nivel: NivelRiesgo.rojo,
      titulo: 'Calle inundada, familias necesitan evacuar',
      lugar: 'Barrio San José',
      hace: 'hace 12 min',
    ),
    Publicacion(
      nivel: NivelRiesgo.amarillo,
      titulo: 'Grietas en el puente peatonal, eviten pasar',
      lugar: 'Puente El Carmen',
      hace: 'hace 40 min',
    ),
    Publicacion(
      nivel: NivelRiesgo.verde,
      titulo: 'Albergue abierto en la escuela central',
      lugar: 'Escuela Rubén Darío',
      hace: 'hace 1 h',
    ),
  ];

  static const noticiasNacionales = <Noticia>[
    Noticia(
      categoria: 'Clima',
      titulo: 'Lluvias continuarán durante el fin de semana',
      resumen: 'Se recomienda evitar zonas bajas y cauces.',
      region: 'Nacional',
      icono: Icons.cloud_outlined,
    ),
    Noticia(
      categoria: 'Comunidad',
      titulo: 'Brigadas voluntarias se organizan por barrio',
      resumen: 'Cómo sumarte a la brigada de tu comunidad.',
      region: 'Nacional',
      icono: Icons.groups_outlined,
    ),
    Noticia(
      categoria: 'Prevención',
      titulo: 'Arma tu mochila de emergencia',
      resumen: 'Agua, linterna, botiquín y documentos.',
      region: 'Nacional',
      icono: Icons.backpack_outlined,
    ),
  ];

  static const destacadoInternacional = Noticia(
    categoria: 'DESTACADO',
    titulo: 'Cooperación climática: una mirada global',
    resumen:
        'Cómo se coordinan países y comunidades frente al cambio climático.',
    etiquetas: ['Europa', 'Política'],
  );

  static const noticiasInternacionales = <Noticia>[
    Noticia(
      categoria: 'Economía',
      titulo: 'Claves para entender la economía mundial',
      resumen: '',
      region: 'Mundo',
      icono: Icons.trending_up,
    ),
    Noticia(
      categoria: 'Salud',
      titulo: 'Salud: el valor de la cooperación internacional',
      resumen: '',
      region: 'Sociedad',
      icono: Icons.health_and_safety_outlined,
    ),
  ];

  /// Puntos de muestra (solo se usan si no hay conexión con la base).
  static const puntosMapa = <PuntoMapa>[
    PuntoMapa(13.0920, -86.3540, NivelRiesgo.amarillo, 'Árboles caídos', 'Estelí'),
    PuntoMapa(12.9256, -85.9175, NivelRiesgo.rojo, 'Viviendas dañadas', 'Matagalpa'),
    PuntoMapa(12.1364, -86.2514, NivelRiesgo.rojo, 'Familias sin agua', 'Managua'),
    PuntoMapa(12.4379, -86.8780, NivelRiesgo.amarillo, 'Vía obstruida', 'León'),
    PuntoMapa(11.9744, -86.0942, NivelRiesgo.amarillo, 'Sin energía', 'Masaya'),
    PuntoMapa(12.6297, -87.1311, NivelRiesgo.rojo, 'Persona herida', 'Chinandega'),
    PuntoMapa(12.0137, -83.7635, NivelRiesgo.rojo, 'Inundación', 'Bluefields'),
    PuntoMapa(11.9299, -85.9560, NivelRiesgo.amarillo, 'Deslave menor', 'Granada'),
  ];
}
