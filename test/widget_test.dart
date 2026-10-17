// Pruebas de la lógica de decisiones (sin red ni Supabase).
// Ejecuta: flutter test

import 'package:flutter_test/flutter_test.dart';

import 'package:rally/models/emergencia_models.dart';

Meta _meta() => Meta(
      id: 'z1',
      eventoId: 'e1',
      municipioId: 'leon',
      actualizadoEn: DateTime.now().toUtc(),
      fuente: Fuente.liderComunidad,
    );

void main() {
  group('Amenaza', () {
    test('normaliza la severidad entre 0 y 1', () {
      final a = Amenaza(
        meta: _meta(),
        tipoEvento: TipoEvento.sismo,
        severidadValor: 6,
        severidadUnidad: UnidadSeveridad.magnitud,
        fase: Fase.durante,
      );
      expect(a.indiceSeveridad, closeTo(0.5, 0.001));
      expect(a.urgencia, 1);
    });

    test('detecta si un punto está dentro del polígono', () {
      final a = Amenaza(
        meta: _meta(),
        tipoEvento: TipoEvento.inundacion,
        severidadValor: 50,
        severidadUnidad: UnidadSeveridad.mmH,
        fase: Fase.antes,
        poligono: const [
          PuntoGeo(0, 0),
          PuntoGeo(0, 1),
          PuntoGeo(1, 1),
          PuntoGeo(1, 0),
        ],
      );
      expect(a.contiene(const PuntoGeo(0.5, 0.5)), isTrue);
      expect(a.contiene(const PuntoGeo(2, 2)), isFalse);
    });
  });

  group('Población', () {
    test('calcula evacuación y proporción vulnerable', () {
      final p = PoblacionZona(
        meta: _meta(),
        totalPersonas: 1000,
        ninos: 250,
        adultosMayores: 150,
        personasEvacuadas: 300,
      );
      expect(p.tasaEvacuacionPct, 30);
      expect(p.proporcionVulnerable, closeTo(0.4, 0.001));
    });

    test('sin personas no divide entre cero', () {
      final p = PoblacionZona(meta: _meta(), totalPersonas: 0);
      expect(p.tasaEvacuacionPct, 0);
      expect(p.proporcionVulnerable, 0);
    });
  });

  group('Recursos', () {
    test('autonomía de agua con 15 L por persona al día', () {
      const r = Recursos(
        albergues: [
          Albergue(
            id: 'a1',
            nombre: 'Escuela',
            ubicacion: PuntoGeo(12.4, -86.9),
            capacidad: 100,
            ocupacion: 50,
          ),
        ],
        litrosAgua: 1500,
      );
      expect(r.autonomiaAguaDias, closeTo(2, 0.001));
      expect(r.cuposLibres, 50);
    });
  });

  group('Vías', () {
    test('no asigna una vía saturada ni bloqueada', () {
      final llena = Via(
        id: 'v1',
        nombre: 'Llena',
        estado: EstadoVia.transitable,
        trazo: const [PuntoGeo(0, 0)],
        capacidadVehiculos: 5,
        vehiculosEnRuta: 4,
      );
      final bloqueada = Via(
        id: 'v2',
        nombre: 'Bloqueada',
        estado: EstadoVia.bloqueada,
        trazo: const [PuntoGeo(0, 0)],
        capacidadVehiculos: 5,
      );
      final libre = Via(
        id: 'v3',
        nombre: 'Libre',
        estado: EstadoVia.transitable,
        trazo: const [PuntoGeo(0, 0)],
        capacidadVehiculos: 5,
      );
      final equipo = Equipo(id: 'e1', tipo: TipoEquipo.bomberos, integrantes: 4);

      final elegida = elegirVia(
        equipo: equipo,
        candidatas: [llena, bloqueada, libre],
        puntosCriticos: const [],
        todos: [equipo],
        reporteId: 'r1',
      );
      expect(elegida?.id, 'v3');

      asignar(equipo, libre, 'r1');
      expect(libre.vehiculosEnRuta, 1);
      liberarVia(equipo, [libre], llego: true);
      expect(libre.vehiculosEnRuta, 0);
    });
  });

  group('Escalamiento', () {
    test('pide apoyo cuando los albergues están casi llenos', () {
      final zona = SituacionZona(
        zonaId: 'Sutiaba',
        amenaza: Amenaza(
          meta: _meta(),
          tipoEvento: TipoEvento.inundacion,
          severidadValor: 80,
          severidadUnidad: UnidadSeveridad.mmH,
          fase: Fase.durante,
        ),
        poblacion: PoblacionZona(meta: _meta(), totalPersonas: 500),
        vias: const [],
      );
      const recursos = Recursos(
        albergues: [
          Albergue(
            id: 'a1',
            nombre: 'Escuela',
            ubicacion: PuntoGeo(12.4, -86.9),
            capacidad: 100,
            ocupacion: 95,
          ),
        ],
        litrosAgua: 100000,
        racionesAlimento: 10000,
      );
      final ev = evaluar(zonas: [zona], recursos: recursos);
      expect(ev.capacidadLocalUsadaPct, closeTo(95, 0.001));
      expect(ev.requiereEscalamiento, isTrue);
      expect(ev.motivos.first, contains('95'));
    });
  });
}
