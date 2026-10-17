import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/widgets/comunes.dart';

/// Pantalla "¿Está ocurriendo una emergencia ahora mismo?"
class EmergenciaScreen extends StatelessWidget {
  const EmergenciaScreen({super.key});

  static const Color _grisBoton = Color(0xFFD9D9D9);

  void _onSos(BuildContext context) {
    Navigator.of(context).pushNamed(Rutas.estado);
  }

  void _onContinuar(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(
      AuthService.haySesion ? Rutas.home : Rutas.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Logo(Img.isoRojo, alto: 52),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Esta ocurriendo una\nemergencia ahora mismo?',
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Súbela',
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _BotonSos(onPressed: () => _onSos(context)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: TextButton(
                  onPressed: () => _onContinuar(context),
                  style: TextButton.styleFrom(
                    backgroundColor: _grisBoton,
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                    shadowColor: Colors.black38,
                  ),
                  child: Text(
                    'No, déjame continuar',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonSos extends StatelessWidget {
  const _BotonSos({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primary,
      elevation: 6,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: double.infinity,
          height: 72,
          child: Center(
            child: Text(
              'SOS',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 36,
                    letterSpacing: 1,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
