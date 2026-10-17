import 'package:flutter/material.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/widgets/comunes.dart';

/// Barra inferior amarilla con los 4 íconos; el seleccionado sube.
class NuncNavBar extends StatelessWidget {
  const NuncNavBar({super.key, required this.indice, required this.onTap});

  final int indice;
  final ValueChanged<int> onTap;

  static const _iconos = [
    (Img.navInicio, 'Inicio'),
    (Img.navNoticias, 'Donaciones'),
    (Img.navAjustes, 'Configuración'),
    (Img.navPerfil, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return SizedBox(
      height: 92 + abajo,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 52 + abajo,
            child: const ColoredBox(color: AppTheme.secondary),
          ),
          Positioned.fill(
            bottom: abajo,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < _iconos.length; i++)
                  Semantics(
                    button: true,
                    selected: i == indice,
                    label: _iconos[i].$2,
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.only(bottom: i == indice ? 26 : 10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            _iconos[i].$1,
                            width: 58,
                            height: 58,
                            cacheWidth: (58 * dpr).round(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón rojo redondo con "!" para reportar el estado.
class BotonAlerta extends StatelessWidget {
  const BotonAlerta({super.key, required this.onTap, this.onLongPress});
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reportar cómo te encuentras',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 66,
          height: 66,
          decoration: const BoxDecoration(
            color: AppTheme.alerta,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '!',
            style: TextStyle(
              fontFamily: 'Impact',
              color: Colors.white,
              fontSize: 44,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
