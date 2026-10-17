import 'package:flutter/material.dart';
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
import 'package:rally/screens/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tuxbartanbqplyjimpkx.supabase.co',
    publishableKey: 'sb_publishable_GedcGtOtnCaEGWaS2FAYjA_b2Tg9bMe',
  );

  runApp(const MyApp());
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
        },
      ),
    );
  }
}
