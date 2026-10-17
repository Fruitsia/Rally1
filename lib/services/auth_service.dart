import 'package:supabase_flutter/supabase_flutter.dart';

/// Datos que se recogen en los 3 pasos de registro.
class DatosRegistro {
  String nombre = '';
  String apellidos = '';
  String edad = '';
  String genero = '';
  String oficio = '';
  String paisResidencia = '';
  String paisProcedencia = '';
  String region = '';
  String municipio = '';
  String departamento = '';
  String comunidad = '';
  String telefono = '';
  String correo = '';
  String clave = '';

  Map<String, dynamic> aMetadata() => {
        'nombre': nombre,
        'apellidos': apellidos,
        'edad': edad,
        'genero': genero,
        'oficio': oficio,
        'pais_residencia': paisResidencia,
        'pais_procedencia': paisProcedencia,
        'region': region,
        'municipio': municipio,
        'departamento': departamento,
        'comunidad': comunidad,
        'telefono': telefono,
      };
}

/// Autenticación con Supabase (correo + contraseña).
class AuthService {
  static SupabaseClient get _cliente => Supabase.instance.client;

  static User? get usuario => _cliente.auth.currentUser;
  static bool get haySesion => usuario != null;

  static Map<String, dynamic> get perfil => usuario?.userMetadata ?? const {};

  static String get nombreCompleto {
    final n = '${perfil['nombre'] ?? ''} ${perfil['apellidos'] ?? ''}'.trim();
    return n.isEmpty ? (usuario?.email ?? 'Invitado') : n;
  }

  static Future<void> iniciarSesion(String correo, String clave) async {
    await _cliente.auth.signInWithPassword(
      email: correo.trim(),
      password: clave,
    );
  }

  /// Devuelve `true` si quedó con sesión iniciada; `false` si Supabase pide
  /// confirmar el correo antes de entrar.
  static Future<bool> registrar(DatosRegistro d) async {
    final res = await _cliente.auth.signUp(
      email: d.correo.trim(),
      password: d.clave,
      data: d.aMetadata(),
    );
    return res.session != null;
  }

  static Future<void> cerrarSesion() => _cliente.auth.signOut();

  /// Actualiza los datos del perfil (se guardan en la cuenta de Supabase).
  static Future<void> actualizarPerfil(Map<String, dynamic> datos) async {
    await _cliente.auth
        .updateUser(UserAttributes(data: {...perfil, ...datos}))
        .timeout(const Duration(seconds: 12));
  }

  /// Traduce los errores más comunes de Supabase al español.
  static String mensajeError(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid login')) return 'Correo o contraseña incorrectos.';
      if (m.contains('already registered')) {
        return 'Ese correo ya tiene una cuenta.';
      }
      if (m.contains('email not confirmed')) {
        return 'Confirma tu correo antes de iniciar sesión.';
      }
      if (m.contains('password')) {
        return 'La contraseña debe tener al menos 6 caracteres.';
      }
      if (m.contains('email')) return 'Revisa el correo electrónico.';
      return e.message;
    }
    return 'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.';
  }
}
