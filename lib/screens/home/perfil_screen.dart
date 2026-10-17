import 'package:flutter/material.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/models/models.dart';
import 'package:rally/screens/home/mis_donaciones_screen.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/widgets/comunes.dart';

/// Pestaña Perfil.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  void _historial(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.background,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ListenableBuilder(
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
                        label: Text(
                            'Reintentar ${s.pendientes.length} pendiente(s)'),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthService.perfil;
    final nombre = AuthService.nombreCompleto;
    final correo = AuthService.usuario?.email ?? 'Sin sesión iniciada';
    const etiqueta = TextStyle(color: AppTheme.rojo, fontSize: 12);
    const valor = TextStyle(fontWeight: FontWeight.w700, fontSize: 13);

    return ListenableBuilder(
      listenable: ReporteService.instancia,
      builder: (context, _) {
        final reportes = ReporteService.instancia.reportes.length;
        return ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const Padding(
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
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borde),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.secondary,
                      child: Text(
                        nombre.isEmpty ? 'NU' : nombre[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          Text(correo,
                              style: const TextStyle(
                                  color: AppTheme.grisTexto, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (!AuthService.haySesion)
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed(Rutas.login),
                        child: const Text('Iniciar sesión'),
                      )
                    else if ((p['oficio'] as String?)?.isNotEmpty == true)
                      Pildora(p['oficio'] as String,
                          fondo: const Color(0xFFFFF0CC),
                          color: AppTheme.rojo),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _Titulo('Actividad y accesos', 'Datos y actividad de tu cuenta.'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Zona', style: etiqueta),
                        Text(
                          [p['municipio'], p['departamento']]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(', ')
                              .ifEmpty('Sin definir'),
                          style: valor,
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alertas', style: etiqueta),
                        Text('Personalizadas', style: valor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _Titulo('Accesos relevantes', null),
            _Acceso(
              titulo: 'Mis donaciones',
              sub: 'Seguimiento de tus aportes',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MisDonacionesScreen()),
              ),
            ),
            _Acceso(
              titulo: 'Editar mis datos',
              sub: 'Nombre y ubicación',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Próximamente.')),
              ),
            ),
            _Acceso(
              titulo: 'Historial de reportes',
              sub: '$reportes registro(s)',
              onTap: () => _historial(context),
            ),
            const _Titulo('Métricas', null),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reportes', style: etiqueta),
                        Text('$reportes', style: valor),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pendientes', style: etiqueta),
                        Text('${ReporteService.instancia.pendientes.length}',
                            style: valor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

extension on String {
  String ifEmpty(String otro) => isEmpty ? otro : this;
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.titulo, this.sub);
  final String titulo;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
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
                style:
                    const TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({required this.titulo, required this.sub, required this.onTap});
  final String titulo;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub,
          style: const TextStyle(color: AppTheme.grisTexto, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
