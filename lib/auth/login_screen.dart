import 'package:flutter/material.dart';

import 'package:rally/core/rutas.dart';
import 'package:rally/services/auth_service.dart';
import 'package:rally/widgets/comunes.dart';

/// Pantalla "INICIAR SESIÓN".
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await AuthService.iniciarSesion(_correo.text, _clave.text);
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Rutas.home, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.mensajeError(e))),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Logo(Img.isoRojo, alto: 190),
                        ),
                      ),
                    ),
                  ),
                  PanelRojo(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TituloPanel('INICIAR SESIÓN', centrado: false),
                          const SizedBox(height: 18),
                          CampoPanel(
                            etiqueta: 'Correo electrónico',
                            controller: _correo,
                            teclado: TextInputType.emailAddress,
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Escribe un correo válido'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          CampoPanel(
                            etiqueta: 'Contraseña',
                            controller: _clave,
                            oculto: true,
                            validator: requerido,
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: 22),
                          BotonAmarillo(
                            texto: 'INGRESAR',
                            cargando: _cargando,
                            onPressed: _ingresar,
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context)
                                  .pushNamed(Rutas.registro),
                              child: const Text.rich(
                                TextSpan(
                                  text: '¿No tienes cuenta? ',
                                  style: TextStyle(color: Colors.white),
                                  children: [
                                    TextSpan(
                                      text: 'REGISTRAR',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
