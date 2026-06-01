import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pilgrims_3d/data/repositories/auth_repository.dart';
import 'package:pilgrims_3d/core/utils/crypto.dart';
import 'package:pilgrims_3d/core/config/env.dart' as env;
import 'package:pilgrims_3d/services/api/api_service.dart' as api;
import 'package:shared_preferences/shared_preferences.dart';

// Este provider actuaría como intermediario entre la UI y el Repositorio.
// Se puede usar con cualquier gestor de estado (Provider, Riverpod, BLoC).
// Aquí un ejemplo simple con ChangeNotifier.
class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;

  AuthProvider(this._authRepository);

  /// Método genérico para manejar el flujo de login/signup.
  Future<String?> _handleAuth(
    Future<void> Function() authFunction,
    String userEmail,
  ) async {
    try {
      // Lógica que se repite en todos los métodos de autenticación
      env.idToken = (await getEmailSha256(userEmail)) ?? "";
      env.email = userEmail;
      
      // Guardar en SharedPreferences para persistencia
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('idToken', env.idToken);
      await prefs.setString('email', env.email);
      
      print(
        "Globales actualizados y guardados: idToken ${env.idToken} y email ${env.email}",
      );
      await api.registerUser();
      await authFunction();

      return null; // Éxito
    } catch (e) {
      // Devolvemos un mensaje de error legible para la UI.
      if (e is FirebaseException) {
        return 'Error: ${e.message}';
      }
      return 'Ha ocurrido un error inesperado: ${e.toString()}';
    }
  }
  
  /// Cargar credenciales guardadas al iniciar la app
  Future<void> loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      env.idToken = prefs.getString('idToken') ?? '';
      env.email = prefs.getString('email') ?? '';
    } catch (e) {
      print("Error cargando credenciales: $e");
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    return _handleAuth(
      () => _authRepository.signInWithEmailAndPassword(email, password),
      email,
    );
  }

  Future<String?> signUpWithEmail(String email, String password) async {
    return _handleAuth(
      () => _authRepository.signUpWithEmailAndPassword(email, password),
      email,
    );
  }

  Future<String?> signInWithGoogle() async {
    final user = await _authRepository.signInWithGoogle();
    if (user != null && user.email != null) {
      return _handleAuth(() async {}, user.email!);
    }
    return "No se pudo obtener el email de Google.";
  }

  Future<String?> signInWithApple() async {
    final user = await _authRepository.signInWithApple();
    if (user != null && user.email != null) {
      return _handleAuth(() async {}, user.email!);
    }
    return "No se pudo obtener el email de Apple.";
  }

  Future<String?> recoverPassword(String email) async {
    try {
      await _authRepository.sendPasswordResetEmail(email);
      return null;
    } catch (e) {
      if (e is FirebaseException) {
        return 'Error: ${e.message}';
      }
      return 'Ha ocurrido un error inesperado.';
    }
  }
}
