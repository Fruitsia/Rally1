import 'package:flutter/material.dart';

import 'package:rally/core/theme.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/services/datos_service.dart';
import 'package:rally/models/models.dart';
import 'package:rally/widgets/comunes.dart';

/// "Mis Donaciones" con estado y seguimiento.
class MisDonacionesScreen extends StatefulWidget {
  const MisDonacionesScreen({super.key});

  @override
  State<MisDonacionesScreen> createState() => _MisDonacionesScreenState();
}

class _MisDonacionesScreenState extends State<MisDonacionesScreen> {
  late Future<List<Donacion>> _donaciones = DatosService.misDonaciones();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EncabezadoSeccion(
              titulo: 'Donaciones',
              accion: BotonIcono(
                icono: Icons.shopping_cart_outlined,
                resaltado: true,
                tooltip: 'Volver',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() => _donaciones = DatosService.misDonaciones());
                  await _donaciones;
                },
                child: FutureBuilder<List<Donacion>>(
                  future: _donaciones,
                  builder: (context, snap) {
                    final lista = snap.data ?? const <Donacion>[];
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        const Text('Mis Donaciones',
                            style: AppTheme.tituloImpact),
                        const SizedBox(height: 12),
                        if (snap.connectionState != ConnectionState.done)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (lista.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Text(
                              AuthService.haySesion
                                  ? 'Aún no tienes donaciones.'
                                  : 'Inicia sesión para ver tus donaciones.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        for (final d in lista) _TarjetaDonacion(donacion: d),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaDonacion extends StatelessWidget {
  const _TarjetaDonacion({required this.donacion});
  final Donacion donacion;

  void _seguimiento(BuildContext context) {
    final pasos = [
      ('Donación recibida', donacion.etapa >= 1),
      ('Fondos asignados al proyecto', donacion.etapa >= 2),
      ('Ayuda en camino', donacion.etapa >= 3),
      ('Entregada a las familias', donacion.etapa >= 4),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.background,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seguimiento',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final (t, hecho) in pasos)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    hecho ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: hecho ? AppTheme.verde : AppTheme.grisTexto,
                  ),
                  title: Text(t),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entregada = donacion.estado == EstadoDonacion.entregada;
    final monto = donacion.monto % 1 == 0
        ? donacion.monto.toInt().toString()
        : donacion.monto.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(fechaCorta(donacion.fecha))),
              Text(
                '${donacion.moneda} $monto',
                style: const TextStyle(
                  fontFamily: 'Impact',
                  color: AppTheme.rojo,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.shield, color: AppTheme.rojo, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(donacion.fundacion,
                        style: const TextStyle(
                            color: AppTheme.rojo,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    Text('Proyecto: ${donacion.proyecto}',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Pildora(entregada ? 'ENTREGADA' : 'EN PROCESO'),
          const Divider(height: 28, color: AppTheme.borde),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _seguimiento(context),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('VER SEGUIMIENTO',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
