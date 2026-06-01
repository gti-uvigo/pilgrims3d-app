import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/env.dart' as env;
import '../../core/errors/exceptions.dart';

/// Servicio para gestionar la autenticación con Firebase
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream del usuario actual
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Usuario actual
  User? get currentUser => _auth.currentUser;

  /// Verifica si hay un usuario logueado
  bool get isAuthenticated => currentUser != null;

  /// Obtiene el ID token del usuario actual
  Future<String?> getIdToken() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final token = await user.getIdToken();
      if (token != null) {
        env.idToken = token;
      }
      return token;
    } catch (e) {
      debugPrint('❌ Error obteniendo ID token: $e');
      return null;
    }
  }

  /// Refresca el ID token
  Future<String?> refreshIdToken() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final token = await user.getIdToken(true); // force refresh
      if (token != null) {
        env.idToken = token;
      }
      debugPrint('🔄 Token actualizado');
      return token;
    } catch (e) {
      debugPrint('❌ Error refrescando token: $e');
      return null;
    }
  }

  /// Login con email y contraseña
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Intentando login con email...');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Guardar datos en Env
      env.email = credential.user?.email ?? email;
      await getIdToken();

      debugPrint('✅ Login exitoso: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error en login: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Error inesperado en login: $e');
      throw AuthException('Error al iniciar sesión');
    }
  }

  /// Registro con email y contraseña
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      debugPrint('📝 Intentando registro...');

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Actualizar nombre de usuario si se proporciona
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
      }

      // Enviar email de verificación
      await credential.user?.sendEmailVerification();

      // Guardar datos en Env
      env.email = credential.user?.email ?? email;
      await getIdToken();

      debugPrint('✅ Registro exitoso: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error en registro: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Error inesperado en registro: $e');
      throw AuthException('Error al crear cuenta');
    }
  }

  /// Login con Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      debugPrint('🔐 Intentando login con Google...');

      // Iniciar el flujo de autenticación
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw AuthException('Login con Google cancelado');
      }

      // Obtener detalles de autenticación
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Crear credencial
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Autenticar con Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // Guardar datos en Env
      env.email = userCredential.user?.email ?? '';
      await getIdToken();

      debugPrint('✅ Login con Google exitoso: ${userCredential.user?.email}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error en login con Google: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Error inesperado en login con Google: $e');
      throw AuthException('Error al iniciar sesión con Google');
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    try {
      debugPrint('👋 Cerrando sesión...');

      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);

      // Limpiar datos en Env
      env.idToken = '';
      env.email = '';

      // Limpiar SharedPreferences para que _checkLoginStatus no lea credenciales obsoletas
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('idToken');
      await prefs.remove('email');

      debugPrint('✅ Sesión cerrada correctamente');
    } catch (e) {
      debugPrint('❌ Error cerrando sesión: $e');
      throw AuthException('Error al cerrar sesión');
    }
  }

  /// Enviar email de recuperación de contraseña
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('📧 Enviando email de recuperación a: $email');

      await _auth.sendPasswordResetEmail(email: email);

      debugPrint('✅ Email de recuperación enviado');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error enviando email: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Error inesperado: $e');
      throw AuthException('Error al enviar email de recuperación');
    }
  }

  /// Actualizar contraseña
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException('No hay usuario autenticado');
      }

      debugPrint('🔑 Actualizando contraseña...');

      await user.updatePassword(newPassword);

      debugPrint('✅ Contraseña actualizada');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error actualizando contraseña: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Error inesperado: $e');
      throw AuthException('Error al actualizar contraseña');
    }
  }

  /// Eliminar cuenta
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException('No hay usuario autenticado');
      }

      debugPrint('🗑️ Eliminando cuenta...');

      await user.delete();

      // Limpiar datos en Env
      env.idToken = '';
      env.email = '';

      debugPrint('✅ Cuenta eliminada');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error eliminando cuenta: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Error inesperado: $e');
      throw AuthException('Error al eliminar cuenta');
    }
  }

  /// Reautenticar usuario (necesario antes de operaciones sensibles)
  Future<void> reauthenticateWithPassword(String password) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        throw AuthException('No hay usuario autenticado');
      }

      debugPrint('🔐 Reautenticando usuario...');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      debugPrint('✅ Reautenticación exitosa');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error en reautenticación: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ Error inesperado: $e');
      throw AuthException('Error al reautenticar');
    }
  }

  /// Maneja excepciones de Firebase Auth y las convierte a mensajes legibles
  AuthException _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthException('No existe una cuenta con este email');
      case 'wrong-password':
        return AuthException('Contraseña incorrecta');
      case 'email-already-in-use':
        return AuthException('Este email ya está registrado');
      case 'invalid-email':
        return AuthException('Email inválido');
      case 'weak-password':
        return AuthException('La contraseña es muy débil');
      case 'user-disabled':
        return AuthException('Esta cuenta ha sido deshabilitada');
      case 'too-many-requests':
        return AuthException('Demasiados intentos. Intenta más tarde');
      case 'operation-not-allowed':
        return AuthException('Operación no permitida');
      case 'requires-recent-login':
        return AuthException(
          'Debes iniciar sesión nuevamente para esta operación',
        );
      default:
        return AuthException('Error de autenticación: ${e.message}');
    }
  }
}
