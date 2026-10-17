import 'package:flutter/material.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/models/models.dart';
import 'package:rally/screens/home/mis_donaciones_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, Supabase;

import 'package:rally/screens/home/editar_perfil.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/widgets/comunes.dart';

/// Datos del perfil ya limpios y tipados, para no leer el Map por toda la UI.
class _DatosPerfil {
  const _DatosPerfil({
    required this.nombre,
    required this.correo,
    required this.oficio,
    required this.zona,
    required this.haySesion,
  });

  factory _DatosPerfil.actual() {
    final p = AuthService.perfil;
    String texto(String clave) => (p[clave] as String?)?.trim() ?? '';

    final zona = [texto('municipio'), texto('departamento')]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return _DatosPerfil(
      nombre: AuthService.nombreCompleto.trim(),
      correo: AuthService.usuario?.email ?? 'Sin sesión iniciada',
      oficio: texto('oficio'),
      zona: zona.isEmpty ? 'Sin definir' : zona,
      haySesion: AuthService.haySesion,
    );
  }

  final String nombre;
  final String correo;
  final String oficio;
  final String zona;
  final bool haySesion;

  String get nombreVisible => nombre.isEmpty ? 'Usuario' : nombre;

  /// Iniciales: "Ana López" → "AL", "Ana" → "A", vacío → "U".
  String get iniciales {
    final partes = nombre.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    if (partes.isEmpty) return 'U';
    return partes.take(2).map((s) => s[0].toUpperCase()).join();
  }
}

/// Pestaña Perfil.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  // ───────────────────────── Acciones ─────────────────────────

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.rojo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    try {
      await AuthService.cerrarSesion();
      if (!context.mounted) return;
      // Limpia la pila para que "atrás" no regrese a pantallas con sesión.
      Navigator.of(context).pushNamedAndRemoveUntil(Rutas.login, (_) => false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar sesión. Intenta de nuevo.')),
      );
    }
  }

  void _historial(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.background,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _HistorialSheet(),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    // Se redibuja cuando cambian los datos de la cuenta (p. ej. al editarlos).
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
    final datos = _DatosPerfil.actual();

    return ListenableBuilder(
      listenable: ReporteService.instancia,
      builder: (context, _) {
        final servicio = ReporteService.instancia;
        final total = servicio.reportes.length;
        final pendientes = servicio.pendientes.length;
        final enviados = total - pendientes;

        return ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const _Encabezado(),
            _TarjetaUsuario(
              datos: datos,
              onLogin: () => Navigator.of(context).pushNamed(Rutas.login),
            ),
            const SizedBox(height: 16),

            // Datos de la cuenta
            const _Titulo('Tu cuenta', 'Información de tu perfil.'),
            _Tarjeta(
              child: Column(
                children: [
                  _FilaDato(icono: Icons.place_outlined, etiqueta: 'Zona', valor: datos.zona),
                  const Divider(height: 1),
                  _FilaDato(
                    icono: Icons.work_outline,
                    etiqueta: 'Oficio',
                    valor: datos.oficio.isEmpty ? 'Sin definir' : datos.oficio,
                  ),
                  const Divider(height: 1),
                  const _FilaDato(
                    icono: Icons.notifications_outlined,
                    etiqueta: 'Alertas',
                    valor: 'Personalizadas',
                  ),
                ],
              ),
            ),

            // Métricas
            const _Titulo('Tu actividad', 'Resumen de tus reportes.'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Metrica(etiqueta: 'Total', valor: total, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  _Metrica(etiqueta: 'Enviados', valor: enviados, color: AppTheme.verde),
                  const SizedBox(width: 8),
                  _Metrica(etiqueta: 'Pendientes', valor: pendientes, color: AppTheme.alerta),
                ],
              ),
            ),

            // Accesos
            const _Titulo('Accesos', null),
            _Tarjeta(
              child: Column(
                children: [
                  _Acceso(
                    icono: Icons.volunteer_activism_outlined,
                    titulo: 'Mis donaciones',
                    sub: 'Seguimiento de tus aportes',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MisDonacionesScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  _Acceso(
                    icono: Icons.history,
                    titulo: 'Historial de reportes',
                    sub: '$total registro(s)',
                    onTap: () => _historial(context),
                  ),
                  const Divider(height: 1),
                  _Acceso(
                    icono: Icons.edit_outlined,
                    titulo: 'Editar mis datos',
                    sub: 'Nombre, teléfono y ubicación',
                    onTap: () => editarDatos(context),
                  ),
                  const Divider(height: 1),
                  _Acceso(
                    icono: Icons.contact_phone_outlined,
                    titulo: 'Contactos de emergencia',
                    sub: 'Reciben tu ubicación si activas el SOS',
                    onTap: () => contactosEmergencia(context),
                  ),
                ],
              ),
            ),

            // Cerrar sesión
            if (datos.haySesion)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: () => _cerrarSesion(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.rojo,
                    side: const BorderSide(color: AppTheme.rojo),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
      },
    );
  }
}

// ───────────────────────── Widgets privados ─────────────────────────

class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Logo(Img.isoRojo, alto: 52),
          SizedBox(width: 12),
          Text('Tu perfil',
              style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 20)),
        ],
      ),
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  const _TarjetaUsuario({required this.datos, required this.onLogin});
  final _DatosPerfil datos;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.secondary,
            child: Text(
              datos.iniciales,
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(datos.nombreVisible,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                Text(datos.correo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.grisTexto, fontSize: 12)),
                if (datos.oficio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Pildora(datos.oficio,
                      fondo: const Color(0xFFFFF0CC), color: AppTheme.rojo),
                ],
              ],
            ),
          ),
          if (!datos.haySesion)
            TextButton(onPressed: onLogin, child: const Text('Iniciar sesión')),
        ],
      ),
    );
  }
}

/// Contenedor blanco con borde, usado por todas las secciones.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borde),
        ),
        child: child,
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.titulo, this.sub);
  final String titulo;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          if (sub != null)
            Text(sub!,
                style: const TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.icono, required this.etiqueta, required this.valor});
  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icono, size: 20, color: AppTheme.rojo),
          const SizedBox(width: 12),
          Text(etiqueta,
              style: const TextStyle(color: AppTheme.grisTexto, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(valor,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({required this.etiqueta, required this.valor, required this.color});
  final String etiqueta;
  final int valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borde),
        ),
        child: Column(
          children: [
            Text('$valor',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 22)),
            const SizedBox(height: 2),
            Text(etiqueta,
                style: const TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({
    required this.icono,
    required this.titulo,
    required this.sub,
    required this.onTap,
  });
  final IconData icono;
  final String titulo;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icono, color: AppTheme.primary),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub,
          style: const TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _HistorialSheet extends StatelessWidget {
  const _HistorialSheet();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ReporteService.instancia,
      builder: (context, _) {
        final s = ReporteService.instancia;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text('Historial de reportes',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (s.pendientes.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final n = await s.reintentarPendientes();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(n > 0
                              ? 'Se enviaron $n reporte(s).'
                              : 'Sigue sin conexión.'),
                        ));
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text('Reintentar ${s.pendientes.length} pendiente(s)'),
                    ),
                  ),
                if (s.reportes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Todavía no has enviado reportes.'),
                  ),
                for (final r in s.reportes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.circle, color: r.nivel.color),
                    title: Text(r.tipo),
                    subtitle: Text(
                      '${fechaCorta(r.creado)} · '
                      '${r.direccion.isEmpty ? 'Sin dirección' : r.direccion}',
                    ),
                    trailing: Text(
                      r.enviado ? 'Enviado' : 'En espera',
                      style: TextStyle(
                        color: r.enviado ? AppTheme.verde : AppTheme.alerta,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
