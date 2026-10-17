import 'package:flutter/material.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/models/models.dart';

/// Rutas de imágenes del proyecto.
class Img {
  static const isoRojo = 'assets/images/logo/iso_rojo.png';
  static const isoBlanco = 'assets/images/logo/iso_blanco.png';
  static const logoRojo = 'assets/images/logo/logo_rojo.png';
  static const logoBlanco = 'assets/images/logo/logo_blanco.png';
  static const navInicio = 'assets/images/icon_nav/inicio.png';
  static const navNoticias = 'assets/images/icon_nav/noticias.png';
  static const navAjustes = 'assets/images/icon_nav/ajustes.png';
  static const navPerfil = 'assets/images/icon_nav/perfil.png';
}

/// Imagen de logo con tamaño de caché reducido (los PNG originales son muy
/// grandes y gastarían mucha memoria).
class Logo extends StatelessWidget {
  const Logo(this.ruta, {super.key, this.alto, this.ancho});
  final String ruta;
  final double? alto;
  final double? ancho;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      ruta,
      height: alto,
      width: ancho,
      fit: BoxFit.contain,
      cacheHeight: alto != null ? (alto! * dpr).round() : null,
      cacheWidth: alto == null && ancho != null ? (ancho! * dpr).round() : null,
    );
  }
}

/// Encabezado de las pestañas: isotipo + título + acción a la derecha.
class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion({super.key, required this.titulo, this.accion});
  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const Logo(Img.isoRojo, alto: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          ),
          ?accion,
        ],
      ),
    );
  }
}

/// Botón cuadrado amarillo del encabezado (mapa, carrito).
class BotonIcono extends StatelessWidget {
  const BotonIcono({
    super.key,
    required this.icono,
    required this.onTap,
    this.resaltado = false,
    this.tooltip,
  });
  final IconData icono;
  final VoidCallback onTap;
  final bool resaltado;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: resaltado ? AppTheme.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icono, color: AppTheme.primary, size: 30),
          ),
        ),
      ),
    );
  }
}

/// Botón redondo amarillo con "X" para cerrar.
class BotonCerrar extends StatelessWidget {
  const BotonCerrar({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cerrar',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppTheme.secondary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'X',
            style: TextStyle(
              fontFamily: 'Impact',
              color: AppTheme.primary,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón amarillo grande ("CONTINUAR", "REGISTRAR").
class BotonAmarillo extends StatelessWidget {
  const BotonAmarillo({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
  });
  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.secondary,
          disabledBackgroundColor: AppTheme.secondary.withValues(alpha: 0.7),
          foregroundColor: AppTheme.primary,
          elevation: 4,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: cargando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : Text(
                texto,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

/// Campo blanco con etiqueta encima, para los paneles rojos.
class CampoPanel extends StatelessWidget {
  const CampoPanel({
    super.key,
    required this.etiqueta,
    required this.controller,
    this.oculto = false,
    this.teclado,
    this.validator,
    this.etiquetaGrande = false,
    this.textInputAction = TextInputAction.next,
  });

  final String etiqueta;
  final TextEditingController controller;
  final bool oculto;
  final TextInputType? teclado;
  final String? Function(String?)? validator;
  final bool etiquetaGrande;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            color: Colors.white,
            fontSize: etiquetaGrande ? 18 : 15,
            fontWeight: etiquetaGrande ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: oculto,
          keyboardType: teclado,
          validator: validator,
          textInputAction: textInputAction,
          style: const TextStyle(color: AppTheme.texto, fontSize: 15),
          decoration: decoracionPanel(),
        ),
      ],
    );
  }
}

InputDecoration decoracionPanel({String? pista}) => InputDecoration(
      hintText: pista,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      errorStyle: const TextStyle(color: AppTheme.secondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );

String? requerido(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

/// Panel rojo con esquinas superiores redondeadas (login / registro).
class PanelRojo extends StatelessWidget {
  const PanelRojo({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.rojo,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: child,
    );
  }
}

/// Título en cursiva tipo "REGISTRAR" / "INICIAR SESIÓN".
class TituloPanel extends StatelessWidget {
  const TituloPanel(this.texto, {super.key, this.centrado = true});
  final String texto;
  final bool centrado;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      textAlign: centrado ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        letterSpacing: 1,
      ),
    );
  }
}

/// Píldora pequeña (EN PROCESO, DESTACADO, Economía...).
class Pildora extends StatelessWidget {
  const Pildora(
    this.texto, {
    super.key,
    this.fondo = AppTheme.secondary,
    this.color = AppTheme.primary,
  });
  final String texto;
  final Color fondo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Tarjeta "Tu reporte" usada en las pantallas de envío.
class TarjetaReporte extends StatelessWidget {
  const TarjetaReporte({super.key, required this.reporte});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    const gris = TextStyle(color: AppTheme.grisTexto, fontSize: 13);
    final refs = [
      if (reporte.referencia.isNotEmpty) reporte.referencia,
      'Ubicación manual',
    ].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        border: Border.all(color: AppTheme.borde),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Tu reporte')),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: reporte.nivel.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(reporte.nivel.etiqueta, style: gris),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(iconoTipo(reporte.tipo), size: 20, color: AppTheme.grisTexto),
              const SizedBox(width: 10),
              Expanded(
                child: Text(reporte.tipo, style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
          if (reporte.direccion.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined,
                    size: 20, color: AppTheme.grisTexto),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reporte.direccion,
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(refs, style: gris),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Caja gris "¿Necesitas atención inmediata?".
class CajaAtencionInmediata extends StatelessWidget {
  const CajaAtencionInmediata({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.grisCaja,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.phone_outlined, size: 20, color: AppTheme.grisTexto),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Necesitas atención inmediata?'),
                SizedBox(height: 4),
                Text(
                  'Contacta al servicio local de emergencias por un medio '
                  'disponible.',
                  style: TextStyle(color: AppTheme.grisTexto, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra superior "← Emergencias ........ SOS".
class BarraEmergencias extends StatelessWidget {
  const BarraEmergencias({super.key, this.onAtras});
  final VoidCallback? onAtras;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borde)),
      ),
      child: Row(
        children: [
          if (onAtras != null)
            IconButton(
              onPressed: onAtras,
              icon: const Icon(Icons.arrow_back, color: AppTheme.texto),
            )
          else
            const SizedBox(width: 12, height: 48),
          const Expanded(
            child: Text('Emergencias', style: TextStyle(fontSize: 16)),
          ),
          const Text(
            'SOS',
            style: TextStyle(
              color: AppTheme.alerta,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

String fechaCorta(DateTime f) {
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  return '${f.day} ${meses[f.month - 1]}. ${f.year}';
}
