import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pilgrims_3d/presentation/dialogs/generic_dialogs.dart';
import 'package:provider/provider.dart'; // Necesitarás el paquete provider

import 'package:pilgrims_3d/presentation/providers/auth_provider.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:pilgrims_3d/core/config/theme.dart';
import 'package:pilgrims_3d/presentation/widgets/sponsors_logos.dart';
import 'package:pilgrims_3d/core/config/routes.dart';
import 'package:pilgrims_3d/presentation/screens/home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // Envoltorio para manejar la lógica post-autenticación
  Future<String?> _authHandler(
    BuildContext context,
    Future<String?> Function() authCall,
  ) async {
    final haptic = HapticService();

    final String? error = await authCall();

    if (error == null) {
      await haptic.success();
      // Mostramos el aviso y solo después navegamos a la home.
      await showDisclaimerDialog(context);
      HomeScreen.pendingRateCheck = true;
      context.go('/');
      return null;
    } else {
      await haptic.error();
      return error;
    }
  }

  @override
  Widget build(BuildContext context) {
    // El AuthProvider debe ser instanciado en un nivel superior del árbol
    // de widgets, por ejemplo en tu `main.dart` usando `ChangeNotifierProvider`.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: true);

    return Theme(
      data: AppTheme.lightTheme, // Usamos el tema desde el archivo de config
      child: Scaffold(
        backgroundColor: AppTheme.lightTheme.primaryColor,
        body: Column(
          children: [
            Expanded(
              child: FlutterLogin(
                title: 'Pilgrim\'s 3D',
                logo: const AssetImage('images/logo.png'),
                onLogin:
                    (data) => _authHandler(
                      context,
                      () => authProvider.signInWithEmail(
                        data.name,
                        data.password,
                      ),
                    ),
                onSignup:
                    (data) => _authHandler(
                      context,
                      () => authProvider.signUpWithEmail(
                        data.name!,
                        data.password!,
                      ),
                    ),
                onRecoverPassword:
                    (name) => _authHandler(
                      context,
                      () => authProvider.recoverPassword(name),
                    ),
                loginProviders: <LoginProvider>[
                  LoginProvider(
                    icon: FontAwesomeIcons.google,
                    label: 'Google',
                    callback:
                        () => _authHandler(
                          context,
                          authProvider.signInWithGoogle,
                        ),
                  ),
                ],
                theme: LoginTheme(
                  primaryColor: AppTheme.lightTheme.primaryColor,
                  buttonTheme: LoginButtonTheme(
                    backgroundColor: AppTheme.lightTheme.colorScheme.secondary,
                    highlightColor: AppTheme.lightTheme.colorScheme.tertiary,
                    splashColor: AppTheme.lightTheme.colorScheme.tertiary,
                  ),
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                  bodyStyle: TextStyle(
                    color: AppTheme.lightTheme.colorScheme.secondary,
                  ),
                  switchAuthTextColor:
                      AppTheme.lightTheme.colorScheme.secondary,
                ),
                userType: LoginUserType.email,
                messages: LoginMessages(
                  userHint: localeProvider.translate('email'),
                  passwordHint: localeProvider.translate('password'),
                  loginButton: localeProvider.translate('sign_in'),
                  signupButton: localeProvider.translate('sign_up'),
                  forgotPasswordButton: localeProvider.translate(
                    'forgot_password',
                  ),
                ),
              ), // FlutterLogin
            ), // Expanded FlutterLogin
            // Botón para entrar como invitado
            TextButton.icon(
              icon: const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                localeProvider.translate('guest_login'),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 12,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                await HapticService().selection();
                await showDisclaimerDialog(context);
                AppRouter.guestMode = true;
                if (context.mounted) context.go('/');
              },
            ),
            const SponsorLogos(),
          ],
        ),
      ),
    );
  }
}
