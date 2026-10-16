import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/screens/carga_inicio_screen.dart';
import 'package:rally/auth/sos.dart';

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
    return MaterialApp(
      title: 'NUNC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => const CargaInicioScreen(),
        '/emergencia': (context) => const EmergenciaScreen(),
        // '/home': (context) => const HomeScreen(),
      },
    );
  }
}