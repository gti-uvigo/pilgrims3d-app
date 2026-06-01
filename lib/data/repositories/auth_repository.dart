import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// AuthRepository maneja toda la lógica de comunicación con los servicios de
/// autenticación como Firebase, Google y Apple.
/// La UI no sabe cómo se hace el login, solo llama a estos métodos.
class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Inicia sesión con email y contraseña.
  /// Devuelve el User de Firebase si tiene éxito, si no, lanza una excepción.
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  /// Registra un nuevo usuario con email y contraseña.
  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  /// Envía un correo para recuperar la contraseña.
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Inicia sesión con Google.
  Future<User?> signInWithGoogle() async {
    UserCredential userCredential;

    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});
      userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
    } else {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Inicio de sesión con Google cancelado.');
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      userCredential = await _firebaseAuth.signInWithCredential(credential);
    }
    return userCredential.user;
  }

  /// Inicia sesión con Apple.
  Future<User?> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions: WebAuthenticationOptions(
        clientId: 'com.example.yourapp.signin', // <-- USA TU SERVICE ID DE APPLE
        redirectUri: Uri.parse(
          'https://camino-57345.firebaseapp.com/__/auth/handler',
        ),
      ),
    );

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: credential.identityToken,
      accessToken: credential.authorizationCode,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);
    return userCredential.user;
  }

  /// Cierra la sesión del usuario actual.
  /// Intenta cerrar sesión en todos los proveedores.
  Future<void> signOut() async {
    try {
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      // Asegurarse de que al menos Firebase cierre sesión
      await _firebaseAuth.signOut();
      rethrow;
    }
  }
  
  /// Obtiene el usuario actual si existe
  User? get currentUser => _firebaseAuth.currentUser;
  
  /// Stream del estado de autenticación
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

}
