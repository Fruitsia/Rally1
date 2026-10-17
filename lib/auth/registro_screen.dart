import 'package:flutter/material.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/core/theme.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/widgets/comunes.dart';

/// Registro en 3 pasos: datos personales → ubicación → contacto y cuenta.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _datos = DatosRegistro();
  final _forms = List.generate(3, (_) => GlobalKey<FormState>());
  int _paso = 0;
  bool _cargando = false;

  // Paso 1
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _edad = TextEditingController();
  String? _genero;
  String? _oficio;
  // Paso 2
  final _paisResidencia = TextEditingController(text: 'Nicaragua');
  final _paisProcedencia = TextEditingController();
  final _region = TextEditingController();
  final _municipio = TextEditingController();
  final _departamento = TextEditingController();
  final _comunidad = TextEditingController();
  // Paso 3
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();

  List<TextEditingController> get _todos => [
        _nombre, _apellidos, _edad, _paisResidencia, _paisProcedencia,
        _region, _municipio, _departamento, _comunidad, _telefono, _correo,
        _clave, _clave2,
      ];

  @override
  void dispose() {
    for (final c in _todos) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _continuar() async {
    if (!_forms[_paso].currentState!.validate()) return;
    if (_paso == 0 && _oficio == null) {
      _aviso('Elige tu oficio.');
      return;
    }
    if (_paso < 2) {
      setState(() => _paso++);
      return;
    }

    _datos
      ..nombre = _nombre.text.trim()
      ..apellidos = _apellidos.text.trim()
      ..edad = _edad.text.trim()
      ..genero = _genero ?? ''
      ..oficio = _oficio ?? ''
      ..paisResidencia = _paisResidencia.text.trim()
      ..paisProcedencia = _paisProcedencia.text.trim()
      ..region = _region.text.trim()
      ..municipio = _municipio.text.trim()
      ..departamento = _departamento.text.trim()
      ..comunidad = _comunidad.text.trim()
      ..telefono = _telefono.text.trim()
      ..correo = _correo.text.trim()
      ..clave = _clave.text;

    setState(() => _cargando = true);
    try {
      final conSesion = await AuthService.registrar(_datos);
      if (!mounted) return;
      if (conSesion) {
        Navigator.of(context).pushNamedAndRemoveUntil(Rutas.home, (_) => false);
      } else {
        _aviso('Cuenta creada. Revisa tu correo para confirmarla y luego '
            'inicia sesión.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _aviso(AuthService.mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _aviso(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _atras() {
    if (_paso > 0) setState(() => _paso--);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paso == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _atras();
      },
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
                  child: Column(
                    children: [
                      const Logo(Img.logoRojo, ancho: 260),
                      const SizedBox(height: 14),
                      Text(
                        'Informa a tu comunidad y al mundo de lo que '
                        'esta pasando',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              PanelRojo(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TituloPanel('REGISTRAR'),
                    const SizedBox(height: 6),
                    _IndicadorPasos(paso: _paso),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: KeyedSubtree(
                        key: ValueKey(_paso),
                        child: switch (_paso) {
                          0 => _paso1(),
                          1 => _paso2(),
                          _ => _paso3(),
                        },
                      ),
                    ),
                    const SizedBox(height: 26),
                    BotonAmarillo(
                      texto: _paso < 2 ? 'CONTINUAR' : 'REGISTRAR',
                      cargando: _cargando,
                      onPressed: _continuar,
                    ),
                    if (_paso > 0)
                      Center(
                        child: TextButton(
                          onPressed: _atras,
                          child: const Text('Volver',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fila(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 14),
          Expanded(child: b),
        ],
      );

  Widget _seccion(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _paso1() => Form(
        key: _forms[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fila(
              CampoPanel(
                etiqueta: 'Nombre',
                etiquetaGrande: true,
                controller: _nombre,
                validator: requerido,
              ),
              CampoPanel(
                etiqueta: 'Apellidos',
                etiquetaGrande: true,
                controller: _apellidos,
                validator: requerido,
              ),
            ),
            const SizedBox(height: 14),
            _fila(
              CampoPanel(
                etiqueta: 'Edad',
                etiquetaGrande: true,
                controller: _edad,
                teclado: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1 || n > 120) ? 'Edad no válida' : null;
                },
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Género',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _genero,
                    isExpanded: true,
                    decoration: decoracionPanel(),
                    items: const [
                      'Femenino',
                      'Masculino',
                      'Otro',
                      'Prefiero no decir',
                    ]
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (g) => setState(() => _genero = g),
                    validator: (v) => v == null ? 'Elige una opción' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _seccion('OFICIO'),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final o in const ['Trabajador', 'Estudiante', 'Otro']) ...[
                  Expanded(
                    child: _ChipOficio(
                      texto: o,
                      seleccionado: _oficio == o,
                      onTap: () => setState(() => _oficio = o),
                    ),
                  ),
                  if (o != 'Otro') const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      );

  Widget _paso2() => Form(
        key: _forms[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _seccion('PAÍS'),
            _fila(
              CampoPanel(
                etiqueta: 'País de residencia',
                controller: _paisResidencia,
                validator: requerido,
              ),
              CampoPanel(
                etiqueta: 'País de procedencia',
                controller: _paisProcedencia,
                validator: requerido,
              ),
            ),
            const SizedBox(height: 12),
            _seccion('PAÍS'),
            _fila(
              CampoPanel(etiqueta: 'Región', controller: _region),
              CampoPanel(
                etiqueta: 'Municipio',
                controller: _municipio,
                validator: requerido,
              ),
            ),
            const SizedBox(height: 14),
            _fila(
              CampoPanel(
                etiqueta: 'Departamento',
                controller: _departamento,
                validator: requerido,
              ),
              CampoPanel(
                etiqueta: 'Comunidad',
                controller: _comunidad,
                validator: requerido,
              ),
            ),
          ],
        ),
      );

  Widget _paso3() => Form(
        key: _forms[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _seccion('CONTACTO'),
            const SizedBox(height: 4),
            CampoPanel(
              etiqueta: 'Número de teléfono',
              controller: _telefono,
              teclado: TextInputType.phone,
              validator: (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 8)
                  ? 'Teléfono no válido'
                  : null,
            ),
            const SizedBox(height: 14),
            CampoPanel(
              etiqueta: 'Correo',
              controller: _correo,
              teclado: TextInputType.emailAddress,
              validator: (v) => (v == null || !RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim()))
                  ? 'Escribe un correo válido'
                  : null,
            ),
            const SizedBox(height: 14),
            CampoPanel(
              etiqueta: 'Contraseña',
              controller: _clave,
              oculto: true,
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
            ),
            const SizedBox(height: 14),
            CampoPanel(
              etiqueta: 'Confirmar contraseña',
              controller: _clave2,
              oculto: true,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  v != _clave.text ? 'Las contraseñas no coinciden' : null,
            ),
          ],
        ),
      );
}

class _ChipOficio extends StatelessWidget {
  const _ChipOficio({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
  });
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? AppTheme.secondary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          texto,
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 13,
            fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _IndicadorPasos extends StatelessWidget {
  const _IndicadorPasos({required this.paso});
  final int paso;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == paso ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= paso
                  ? AppTheme.secondary
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
