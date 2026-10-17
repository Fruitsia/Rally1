import 'package:flutter/material.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/services/datos_service.dart';

/// Pide iniciar sesión antes de editar algo de la cuenta.
bool _pedirSesion(BuildContext context) {
  if (AuthService.haySesion) return false;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: const Text('Inicia sesión para guardar tus datos.'),
    action: SnackBarAction(
      label: 'Iniciar sesión',
      onPressed: () => Navigator.of(context).pushNamed(Rutas.login),
    ),
  ));
  return true;
}

InputDecoration _deco(String etiqueta) => InputDecoration(
      labelText: etiqueta,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

// ═════════════════════════ Editar mis datos ═════════════════════════

Future<void> editarDatos(BuildContext context) async {
  if (_pedirSesion(context)) return;
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.background,
    showDragHandle: true,
    builder: (_) => const _EditarDatos(),
  );
  if (guardado == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos actualizados.')),
    );
  }
}

class _EditarDatos extends StatefulWidget {
  const _EditarDatos();

  @override
  State<_EditarDatos> createState() => _EditarDatosState();
}

class _EditarDatosState extends State<_EditarDatos> {
  final _form = GlobalKey<FormState>();
  static const _campos = {
    'nombre': 'Nombre',
    'apellidos': 'Apellidos',
    'telefono': 'Teléfono',
    'departamento': 'Departamento',
    'municipio': 'Municipio',
    'comunidad': 'Comunidad / barrio',
  };
  late final _controles = {
    for (final k in _campos.keys)
      k: TextEditingController(
        text: (AuthService.perfil[k] as String?)?.trim() ?? '',
      ),
  };
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in _controles.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await AuthService.actualizarPerfil({
        for (final e in _controles.entries) e.key: e.value.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo guardar. Revisa tu conexión.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + teclado),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Editar mis datos',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text(
                'Tu municipio y comunidad sirven para mostrarte reportes, '
                'albergues y alertas de tu zona.',
                style: TextStyle(color: AppTheme.grisTexto, fontSize: 13),
              ),
              const SizedBox(height: 14),
              for (final e in _campos.entries) ...[
                TextFormField(
                  controller: _controles[e.key],
                  decoration: _deco(e.value),
                  keyboardType: e.key == 'telefono'
                      ? TextInputType.phone
                      : TextInputType.text,
                  textInputAction: TextInputAction.next,
                  validator: e.key == 'nombre'
                      ? (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe tu nombre'
                          : null
                      : null,
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════ Contactos de emergencia ═════════════════════════

Future<void> contactosEmergencia(BuildContext context) async {
  if (_pedirSesion(context)) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.background,
    showDragHandle: true,
    builder: (_) => const _Contactos(),
  );
}

class _Contactos extends StatefulWidget {
  const _Contactos();

  @override
  State<_Contactos> createState() => _ContactosState();
}

class _ContactosState extends State<_Contactos> {
  static const _maximo = 3;
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _parentesco = TextEditingController();
  final _form = GlobalKey<FormState>();

  List<Map<String, dynamic>> _lista = const [];
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _parentesco.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final l = await DatosService.contactos();
      if (!mounted) return;
      setState(() {
        _lista = l;
        _cargando = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar tus contactos. Revisa tu conexión.';
      });
    }
  }

  Future<void> _agregar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await DatosService.agregarContacto(
        nombre: _nombre.text.trim(),
        telefono: _telefono.text.trim(),
        parentesco: _parentesco.text.trim(),
      );
      _nombre.clear();
      _telefono.clear();
      _parentesco.clear();
      await _cargar();
    } catch (_) {
      _aviso('No se pudo guardar el contacto.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar(String id) async {
    final antes = _lista;
    setState(() => _lista = _lista.where((c) => c['id'] != id).toList());
    try {
      await DatosService.borrarContacto(id);
    } catch (_) {
      if (mounted) setState(() => _lista = antes);
      _aviso('No se pudo borrar el contacto.');
    }
  }

  void _aviso(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    final lleno = _lista.length >= _maximo;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + teclado),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Contactos de emergencia',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Si activas el SOS y no hay internet, te preparamos un mensaje '
              'con tu ubicación para ellos. Máximo 3.',
              style: TextStyle(color: AppTheme.grisTexto, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: AppTheme.alerta))
            else if (_lista.isEmpty)
              const Text('Aún no tienes contactos.')
            else
              for (final c in _lista)
                Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.person, color: AppTheme.primary),
                    title: Text('${c['nombre']}'),
                    subtitle: Text([
                      '${c['telefono']}',
                      if ((c['parentesco'] as String?)?.isNotEmpty ?? false)
                        '${c['parentesco']}',
                    ].join(' · ')),
                    trailing: IconButton(
                      tooltip: 'Borrar',
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.alerta),
                      onPressed: () => _borrar('${c['id']}'),
                    ),
                  ),
                ),
            if (!_cargando && _error == null && !lleno) ...[
              const SizedBox(height: 12),
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nombre,
                      decoration: _deco('Nombre'),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe el nombre'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _telefono,
                      decoration: _deco('Teléfono'),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final d = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                        return d.length < 8 ? 'Teléfono no válido' : null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _parentesco,
                      decoration: _deco('Parentesco (opcional)'),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _agregar,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Agregar contacto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
