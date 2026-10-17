import 'package:flutter/material.dart';

import 'package:rally/core/theme.dart';
import 'package:rally/models/models.dart';
import 'package:rally/screens/emergencia/alerta_screen.dart';
import 'package:rally/screens/home/mis_donaciones_screen.dart';
import 'package:rally/services/datos_service.dart';
import 'package:rally/services/reporte_service.dart';
import 'package:rally/widgets/comunes.dart';

/// Pestaña Donaciones: "Ayuda cerca de ti".
class DonacionesScreen extends StatefulWidget {
  const DonacionesScreen({super.key, required this.activa});

  /// true cuando esta pestaña es la visible (para mostrar el aviso de ayuda).
  final bool activa;

  @override
  State<DonacionesScreen> createState() => _DonacionesScreenState();
}

class _DonacionesScreenState extends State<DonacionesScreen> {
  String _ubicacion = 'Cerca de mí';
  late Future<List<Fundacion>> _fundaciones = DatosService.fundaciones();

  @override
  void didUpdateWidget(covariant DonacionesScreen old) {
    super.didUpdateWidget(old);
    if (widget.activa && !old.activa && ReporteService.instancia.alertaActiva) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mostrarAvisoAyuda(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EncabezadoSeccion(
          titulo: 'Donaciones',
          accion: BotonIcono(
            icono: Icons.shopping_cart_outlined,
            tooltip: 'Mis donaciones',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MisDonacionesScreen()),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() => _fundaciones = DatosService.fundaciones());
              await _fundaciones;
            },
            child: FutureBuilder<List<Fundacion>>(
              future: _fundaciones,
              builder: (context, snap) {
                final lista = snap.data ?? const <Fundacion>[];
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  children: [
                    const Text('Ayuda cerca de ti',
                        style: AppTheme.tituloImpact),
                    const SizedBox(height: 14),
                    _SelectorUbicacion(
                      valor: _ubicacion,
                      onChanged: (v) => setState(() => _ubicacion = v),
                    ),
                    const SizedBox(height: 16),
                    if (snap.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (lista.isEmpty)
                      const Text('No hay fundaciones activas por ahora.')
                    else ...[
                      _TarjetaFundacion(fundacion: lista.first),
                      if (lista.length > 1) ...[
                        const SizedBox(height: 22),
                        const Text(
                          'Otras fundaciones cerca de ti',
                          style: TextStyle(
                            color: AppTheme.rojo,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final f in lista.skip(1))
                          Card(
                            color: Colors.white,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppTheme.borde),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.volunteer_activism,
                                  color: AppTheme.rojo),
                              title: Text(f.nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                [f.descripcion, f.distancia]
                                    .where((t) => t.isNotEmpty)
                                    .join(' · '),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => donar(context, f),
                            ),
                          ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectorUbicacion extends StatelessWidget {
  const _SelectorUbicacion({required this.valor, required this.onChanged});
  final String valor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: Colors.white,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'Cerca de mí', child: Text('Cerca de mí')),
        PopupMenuItem(value: 'Mi municipio', child: Text('Mi municipio')),
        PopupMenuItem(value: 'Todo el país', child: Text('Todo el país')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDDE1E4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Text('Ubicación',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(valor,
                  style: const TextStyle(color: AppTheme.grisTexto)),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _TarjetaFundacion extends StatelessWidget {
  const _TarjetaFundacion({required this.fundacion});
  final Fundacion fundacion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.rojo,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.volunteer_activism,
                  color: AppTheme.secondary, size: 64),
              Spacer(),
              Icon(Icons.shield, color: Colors.white, size: 22),
            ],
          ),
          const SizedBox(height: 8),
          Text(fundacion.nombre,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          Text(fundacion.descripcion,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fundacion.progreso,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(fundacion.progreso * 100).round()}% recaudado',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => donar(context, fundacion),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('DONAR AHORA',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja para elegir el monto y registrar la donación en Supabase.
Future<void> donar(BuildContext context, Fundacion f) async {
  final simbolo = simboloMoneda(f.moneda);
  final montos = f.moneda == 'USD' ? const [5, 10, 25, 50] : const [100, 250, 500, 1000];
  final monto = await showModalBottomSheet<num>(
    context: context,
    backgroundColor: AppTheme.background,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Donar a ${f.nombre}',
                style: Theme.of(context).textTheme.titleLarge),
            Text('Proyecto: ${f.proyecto}',
                style: const TextStyle(color: AppTheme.grisTexto)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in montos)
                  ActionChip(
                    label: Text('$simbolo $m'),
                    backgroundColor: Colors.white,
                    onPressed: () => Navigator.pop(context, m),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (monto == null || !context.mounted) return;

  final avisos = ScaffoldMessenger.of(context);
  try {
    await DatosService.donar(f, monto);
    avisos.showSnackBar(SnackBar(
      content: Text('¡Gracias! Registramos tu donación de $simbolo $monto.'),
    ));
  } catch (e) {
    final texto = e.toString().replaceFirst('Exception: ', '');
    avisos.showSnackBar(SnackBar(
      content: Text(texto.contains('sesión') || texto.contains('Sin conexión')
          ? texto
          : 'No se pudo registrar la donación. Inténtalo de nuevo.'),
    ));
  }
}
