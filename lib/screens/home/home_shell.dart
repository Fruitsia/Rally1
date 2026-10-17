import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/screens/home/configuracion_screen.dart';
import 'package:rally/screens/home/donaciones_screen.dart';
import 'package:rally/screens/home/feed_screen.dart';
import 'package:rally/screens/home/perfil_screen.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/services/sos_adaptadores.dart';
import 'package:rally/widgets/nav_bar.dart';

/// Contenedor principal con la barra inferior y el botón rojo "!".
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  /// Las pestañas se crean la primera vez que se abren (no todas al inicio),
  /// así la app arranca más rápido y no hace consultas que nadie ve.
  final _abiertas = <int>{0};

  void _alLlegarAlerta(Map<String, dynamic> alerta) {
    final depAlerta = alerta['departamento'] as String?;
    final miDep = AuthService.perfil['departamento'] as String?;
    final meToca = depAlerta == null ||
        depAlerta.isEmpty ||
        miDep == null ||
        miDep.isEmpty ||
        depAlerta.toLowerCase() == miDep.toLowerCase();
    if (meToca && mounted) Navigator.of(context).pushNamed(Rutas.alerta);
  }

  @override
  void initState() {
    super.initState();
    final servicio = ReporteService.instancia;

    // Reintenta en silencio los reportes que quedaron sin enviar.
    servicio.reintentarPendientes().then((n) {
      if (n > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Se enviaron $n reporte(s) pendientes.')),
        );
      }
    });

    // Alertas en tiempo real desde la tabla `alertas` de Supabase.
    // Solo se muestran las nacionales o las del departamento del usuario.
    servicio.escucharAlertas(_alLlegarAlerta);
  }

  @override
  void dispose() {
    ReporteService.instancia.dejarDeEscuchar(_alLlegarAlerta);
    super.dispose();
  }

  void _ir(int i) => setState(() {
        _indice = i;
        _abiertas.add(i);
      });

  Widget _pestana(int i, Widget Function() crear) =>
      _abiertas.contains(i) ? crear() : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _indice,
          children: [
            const FeedScreen(),
            _pestana(1, () => DonacionesScreen(activa: _indice == 1)),
            _pestana(2, () => ConfiguracionScreen(onVerPerfil: () => _ir(3))),
            _pestana(3, () => const PerfilScreen()),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: BotonAlerta(
          onTap: () => Navigator.of(context).pushNamed(
            SosApp.servicio.hayActivo ? Rutas.sosActivo : Rutas.estado,
          ),
          // Mantener presionado: simula la llegada de una alerta (demo).
          onLongPress: () {
            ReporteService.instancia.alertaActiva = true;
            Navigator.of(context).pushNamed(Rutas.alerta);
          },
        ),
      ),
      bottomNavigationBar: NuncNavBar(indice: _indice, onTap: _ir),
      ),
    );
  }
}
