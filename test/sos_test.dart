// Pruebas del SOS (sin red, sin GPS real).
// Ejecuta: flutter test

import 'package:flutter_test/flutter_test.dart';

import 'package:rally/models/emergencia_models.dart';
import 'package:rally/services/sos_acompanamiento.dart';

class _Ubicador implements Ubicador {
  PuntoGps? siguiente;
  @override
  Future<PuntoGps?> actual({required Duration limite}) async => siguiente;
  @override
  Future<PuntoGps?> ultimaConocida() async => null;
}

class _Almacen implements AlmacenLocal {
  Map<String, dynamic>? guardado;
  @override
  Future<void> guardar(Sos sos) async => guardado = sos.toJson();
  @override
  Future<Map<String, dynamic>?> leer() async => guardado;
}

class _Remoto implements Remoto {
  bool conRed = true;
  final enviados = <Map<String, dynamic>>[];
  @override
  Future<bool> enviar(Map<String, dynamic> datos) async {
    if (!conRed) throw Exception('sin red');
    enviados.add(datos);
    return true;
  }

  @override
  Future<bool> enviarSms(String texto) async => false;
  @override
  Future<void> avisarLiderYContactos(Sos sos) async {}
  @override
  Future<void> derivarACentral(Sos sos) async {}
}

class _Dispositivo implements Dispositivo {
  @override
  Future<int?> bateria() async => 80;
  @override
  Future<Conectividad> conectividad() async => Conectividad.datos;
  @override
  Future<void> alarmaFuerte() async {}
  @override
  Future<void> preguntarSiSigueBien() async {}
}

PuntoGps _punto(double lat, double lon) => PuntoGps(
      punto: PuntoGeo(lat, lon),
      precisionM: 8,
      origen: OrigenUbicacion.gps,
      hora: DateTime.utc(2026, 10, 17, 6),
    );

void main() {
  test('los nombres coinciden con los check de la base (snake_case)', () {
    expect(aSnake(EstadoUsuario.sinRespuesta.name), 'sin_respuesta');
    expect(aSnake(Etapa.avisoLider.name), 'aviso_lider');
    expect(aSnake(OrigenUbicacion.ultimaConocida.name), 'ultima_conocida');
    expect(aSnake(Conectividad.soloSms.name), 'solo_sms');
  });

  test('el SOS se guarda y se recupera igual', () {
    final s = Sos(
      sosId: 'abc',
      usuarioId: 'u1',
      tipo: 'Inundación',
      creado: DateTime.utc(2026, 10, 17),
    )
      ..etapa = Etapa.alarma
      ..estadoUsuario = EstadoUsuario.sinRespuesta
      ..ubicaciones.addAll([_punto(12.1, -86.2), _punto(12.2, -86.3)]);
    final r = Sos.fromJson(s.toJson());
    expect(r.etapa, Etapa.alarma);
    expect(r.estadoUsuario, EstadoUsuario.sinRespuesta);
    expect(r.ultimaUbicacion!.punto.lat, 12.2);
    expect(r.ubicaciones.length, 2);
  });

  test('a quién se llama según el tipo', () {
    expect(NumerosEmergencia.paraTipo('Emergencia médica'), '128');
    expect(NumerosEmergencia.paraTipo('Incendio'), '115');
    expect(NumerosEmergencia.paraTipo('Terremoto'), '118');
  });

  test('activar guarda primero y envía la ubicación', () async {
    final ub = _Ubicador()..siguiente = _punto(12.43, -86.88);
    final almacen = _Almacen();
    final remoto = _Remoto();
    final srv = SosAcompanamiento(
      ubicador: ub,
      almacen: almacen,
      remoto: remoto,
      dispositivo: _Dispositivo(),
    );
    await srv.activar(sosId: 's1', usuarioId: 'u1', tipo: 'Terremoto');
    expect(almacen.guardado, isNotNull);
    expect(srv.sos!.envio, EstadoEnvio.enviado);
    expect(remoto.enviados.last['ultima_ubicacion'], isNotNull);
    await srv.cerrar();
    expect(srv.hayActivo, isFalse);
  });

  test('sin red queda guardado «en espera» y no se pierde', () async {
    final remoto = _Remoto()..conRed = false;
    final almacen = _Almacen();
    final srv = SosAcompanamiento(
      ubicador: _Ubicador()..siguiente = _punto(12.43, -86.88),
      almacen: almacen,
      remoto: remoto,
      dispositivo: _Dispositivo(),
    );
    await srv.activar(sosId: 's2', usuarioId: 'u1', tipo: 'Terremoto');
    expect(srv.sos!.envio, EstadoEnvio.enEspera);
    expect(almacen.guardado!['ultima_ubicacion'], isNotNull);
    await srv.cerrar();
  });

  test('lleva al hospital con camas si es emergencia médica', () {
    const recursos = Recursos(
      centrosSalud: [
        CentroSalud(
          id: 'h1',
          nombre: 'Hospital Escuela',
          ubicacion: PuntoGeo(12.44, -86.88),
          operativo: true,
          camasTotales: 10,
          camasOcupadas: 4,
        ),
      ],
    );
    final d = siguienteDestino(
      yo: const PuntoGeo(12.43, -86.88),
      emergenciaMedica: true,
      necesitaAccesible: false,
      recursos: recursos,
      hayRutaSegura: true,
    );
    expect(d.nombre, 'Hospital Escuela');
  });
}
