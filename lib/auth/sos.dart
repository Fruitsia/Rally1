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
    final textTheme = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallDevice = constraints.maxHeight < 650;
              final double horizontalPadding = constraints.maxWidth > 500 ? 48.0 : 24.0;
              final double sosHeight = (constraints.maxHeight * 0.1).clamp(64.0, 84.0);

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Encabezado / Logo superior
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(top: isSmallDevice ? 8 : 16),
                              child: Logo(Img.isoRojo, alto: isSmallDevice ? 44 : 52),
                            ),
                          ),

                          // Contenedor Central (Título + SOS)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Spacer(flex: 2),
                                Text(
                                  '¿Está ocurriendo una\nemergencia ahora mismo?',
                                  textAlign: TextAlign.center,
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallDevice ? 22 : 26,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Repórtala',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: isSmallDevice ? 20 : 32),
                                _BotonSos(
                                  height: sosHeight,
                                  onPressed: () => _onSos(context),
                                ),
                                const Spacer(flex: 3),
                              ],
                            ),
                          ),

                          // Botón secundario inferior
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: isSmallDevice ? 16 : 32,
                              top: 12,
                            ),
                            child: Center(
                              child: TextButton(
                                onPressed: () => _onContinuar(context),
                                style: TextButton.styleFrom(
                                  backgroundColor: _grisBoton,
                                  foregroundColor: AppTheme.primary,
                                  minimumSize: const Size(220, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: const StadiumBorder(),
                                  elevation: 2,
                                  shadowColor: Colors.black.withAlpha(66),
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BotonSos extends StatelessWidget {
  const _BotonSos({
    required this.onPressed,
    required this.height,
  });

  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: AppTheme.primary,
        elevation: 6,
        shadowColor: AppTheme.primary.withAlpha(102),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Center(
              child: Text(
                'SOS',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: (height * 0.45).clamp(28.0, 38.0),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}