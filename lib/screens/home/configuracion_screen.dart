import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/services/datos_service.dart';
import 'package:rally/widgets/comunes.dart';

/// Pestaña Configuración con preferencias guardadas en el teléfono.
class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key, required this.onVerPerfil});
  final VoidCallback onVerPerfil;

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  static const _opciones = <String, bool>{
    'Alertas locales': true,
    'Noticias internacionales': true,
    'Reportes de emergencia': true,
    'Sonido de alerta': false,
    'Notificaciones push': true,
    'Modo silencioso': false,
  };
  static const _tamanos = {'Pequeño': 0.9, 'Estándar': 1.0, 'Grande': 1.2};

  /// Columna de la tabla `preferencias` para cada interruptor.
  static const _columnas = {
    'Alertas locales': 'alertas_locales',
    'Noticias internacionales': 'noticias_internacionales',
    'Reportes de emergencia': 'reportes_emergencia',
    'Sonido de alerta': 'sonido_alerta',
    'Notificaciones push': 'notificaciones_push',
    'Modo silencioso': 'modo_silencioso',
  };
  static const _codigosTamano = {
    'Pequeño': 'pequeno',
    'Estándar': 'estandar',
    'Grande': 'grande',
  };

  final Map<String, bool> _valores = Map.of(_opciones);
  String _busqueda = '';
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _prefs = p;
        for (final k in _opciones.keys) {
          _valores[k] = p.getBool('cfg_$k') ?? _opciones[k]!;
        }
      });
      final escala = p.getDouble('cfg_escala');
      if (escala != null) AppTheme.escalaTexto.value = escala;
    }).catchError((_) {});
    _cargarDeLaNube();
  }

  /// Si hay sesión, las preferencias guardadas en Supabase mandan.
  Future<void> _cargarDeLaNube() async {
    final nube = await DatosService.preferencias();
    if (nube == null || !mounted) return;
    setState(() {
      for (final e in _columnas.entries) {
        final v = nube[e.value];
        if (v is bool) _valores[e.key] = v;
      }
    });
    final tam = _codigosTamano.entries
        .where((e) => e.value == nube['tamano_texto'])
        .map((e) => e.key)
        .firstOrNull;
    if (tam != null) AppTheme.escalaTexto.value = _tamanos[tam]!;
  }

  void _cambiar(String k, bool v) {
    setState(() => _valores[k] = v);
    _prefs?.setBool('cfg_$k', v);
    DatosService.guardarPreferencia(_columnas[k]!, v);
  }

  String get _tamanoActual => _tamanos.entries
      .firstWhere((e) => e.value == AppTheme.escalaTexto.value,
          orElse: () => _tamanos.entries.elementAt(1))
      .key;

  void _siguienteTamano() {
    final claves = _tamanos.keys.toList();
    final sig = claves[(claves.indexOf(_tamanoActual) + 1) % claves.length];
    setState(() => AppTheme.escalaTexto.value = _tamanos[sig]!);
    _prefs?.setDouble('cfg_escala', _tamanos[sig]!);
    DatosService.guardarPreferencia('tamano_texto', _codigosTamano[sig]!);
  }

  bool _coincide(String t) =>
      _busqueda.isEmpty || t.toLowerCase().contains(_busqueda.toLowerCase());

  Future<void> _cerrarSesion() async {
    try {
      await AuthService.cerrarSesion();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(Rutas.emergencia, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    const valorStyle = TextStyle(color: AppTheme.rojo, fontSize: 13);

    return Column(
      children: [
        const EncabezadoSeccion(titulo: 'Configuración'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            children: [
              TextField(
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: InputDecoration(
                  hintText: 'Buscar configuración',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borde),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borde),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Caja(
                titulo: 'Preferencias',
                children: [
                  for (final k in _opciones.keys)
                    if (_coincide(k))
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(k),
                        value: _valores[k]!,
                        activeTrackColor: AppTheme.rojo,
                        onChanged: (v) => _cambiar(k, v),
                      ),
                  if (_coincide('Idioma'))
                    const ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('Idioma'),
                      trailing: Text('Español', style: valorStyle),
                    ),
                  if (_coincide('Tamaño del texto'))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tamaño del texto'),
                      trailing: Text(_tamanoActual, style: valorStyle),
                      onTap: _siguienteTamano,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _Caja(
                titulo: 'Mi cuenta',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.secondary,
                      child: Text(
                        _iniciales(AuthService.nombreCompleto),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(
                      (AuthService.perfil['comunidad'] as String?)
                                  ?.isNotEmpty ==
                              true
                          ? 'Comunidad ${AuthService.perfil['comunidad']}'
                          : 'Comunidad Nunc',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Ver perfil'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onVerPerfil,
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cobertura'),
                    trailing: Text(
                      (AuthService.perfil['municipio'] as String?) ?? '—',
                      style: valorStyle,
                    ),
                  ),
                  if (AuthService.haySesion)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout, color: AppTheme.rojo),
                      title: const Text('Cerrar sesión',
                          style: TextStyle(color: AppTheme.rojo)),
                      onTap: _cerrarSesion,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final s = partes.take(2).map((p) => p[0].toUpperCase()).join();
  return s.isEmpty ? 'NU' : s;
}

class _Caja extends StatelessWidget {
  const _Caja({required this.titulo, required this.children});
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  color: AppTheme.rojo,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          ...children,
        ],
      ),
    );
  }
}
