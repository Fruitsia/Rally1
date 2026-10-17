import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rally/auth/login_screen.dart';
import 'package:rally/auth/registro_screen.dart';
import 'package:rally/auth/sos.dart';
import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/screens/carga_inicio_screen.dart';
import 'package:rally/screens/emergencia/alerta_screen.dart';
import 'package:rally/screens/emergencia/estado_screen.dart';
import 'package:rally/screens/emergencia/reportar_emergencia_screen.dart';
import 'package:rally/screens/emergencia/sos_activo_screen.dart';
import 'package:rally/screens/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En paralelo: conexión con Supabase y tamaño de texto guardado.
  await Future.wait([
    Supabase.initialize(
      url: 'https://tuxbartanbqplyjimpkx.supabase.co',
      publishableKey: 'sb_publishable_GedcGtOtnCaEGWaS2FAYjA_b2Tg9bMe',
    ),
    _cargarEscalaTexto(),
  ]);

  runApp(const MyApp());
}

Future<void> _cargarEscalaTexto() async {
  try {
    final p = await SharedPreferences.getInstance();
    final e = p.getDouble('cfg_escala');
    if (e != null) AppTheme.escalaTexto.value = e;
  } catch (_) {}
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppTheme.escalaTexto,
      builder: (context, escala, _) => MaterialApp(
        title: 'NUNC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(escala),
          ),
          child: child!,
        ),
        initialRoute: Rutas.inicio,
        routes: {
          Rutas.inicio: (_) => const CargaInicioScreen(),
          Rutas.emergencia: (_) => const EmergenciaScreen(),
          Rutas.login: (_) => const LoginScreen(),
          Rutas.registro: (_) => const RegistroScreen(),
          Rutas.home: (_) => const HomeShell(),
          Rutas.estado: (_) => const EstadoScreen(),
          Rutas.reportar: (_) => const ReportarEmergenciaScreen(),
          Rutas.alerta: (_) => const AlertaScreen(),
          Rutas.sosActivo: (_) => const SosActivoScreen(),
        },
      ),
    );
  }
}
