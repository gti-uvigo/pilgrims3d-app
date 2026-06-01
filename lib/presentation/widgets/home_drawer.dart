import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:go_router/go_router.dart';
import 'package:pilgrims_3d/services/api/api_service.dart' as api;
import 'package:provider/provider.dart';

import 'package:pilgrims_3d/data/repositories/auth_repository.dart';
import 'package:pilgrims_3d/presentation/providers/theme_provider.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/core/config/routes.dart';

// Widget para el menú lateral, con un diseño "premium" y elegante.
class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  // --- Lógica de SOS ---
  Future<void> _showSosDialog(BuildContext context) async {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    await HapticService().warning();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(localeProvider.translate('sos_confirm_title')),
            content: Text(localeProvider.translate('sos_confirm_content')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(localeProvider.translate('cancel')),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(localeProvider.translate('confirm')),
              ),
            ],
          ),
    );

    if (confirm == true) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      final result = await api.send_notification_sos();

      if (result == 0) {
        await HapticService().success();
        if (context.mounted) {
          final overlay = Overlay.of(context);
          late OverlayEntry overlayEntry;

          overlayEntry = OverlayEntry(
            builder:
                (context) => Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              localeProvider.translate('sos_sent'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          );

          overlay.insert(overlayEntry);

          Future.delayed(const Duration(seconds: 4), () {
            overlayEntry.remove();
          });
        }
      } else if (result == 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localeProvider.translate('sos_no_users')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localeProvider.translate('sos_error')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final isGuest = AppRouter.guestMode;

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: Column(
        children: [
          // --- Cabecera con menú de configuración ---
          _DrawerHeader(theme: theme),

          // --- Lista de Opciones con scroll ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              children: <Widget>[
                // --- Grupo de Funcionalidades ---
                _SectionHeader(title: localeProvider.translate('features')),
                if (!isGuest)
                  _DrawerItem(
                    child: ListTile(
                      leading: const Icon(Icons.add_location_alt_outlined),
                      title: Text(localeProvider.translate('add_poi')),
                      onTap: () => context.push('/create_poi'),
                    ),
                  ),
                if (!isGuest)
                  _DrawerItem(
                    child: ListTile(
                      leading: const Icon(Icons.list_alt_outlined),
                      title: Text(localeProvider.translate('my_pois')),
                      onTap: () => context.push('/my_pois'),
                    ),
                  ),
                _DrawerItem(
                  child: ListTile(
                    leading: const Icon(Icons.star_border),
                    title: Text(localeProvider.translate('relevant_pois')),
                    onTap: () => context.push('/relevant_pois'),
                  ),
                ),
                if (!isGuest)
                  _DrawerItem(
                    child: ListTile(
                      leading: const Icon(Icons.add_road_outlined),
                      title: Text(localeProvider.translate('create_own_route')),
                      onTap: () => context.push('/create_route'),
                    ),
                  ),
                if (!isGuest)
                  _DrawerItem(
                    child: ListTile(
                      leading: const Icon(Icons.route_outlined),
                      title: Text(localeProvider.translate('routes_list')),
                      onTap: () => context.push('/my_routes'),
                    ),
                  ),

                _DrawerItem(
                  child: ListTile(
                    leading: const Icon(Icons.audiotrack),
                    title: Text(localeProvider.translate('inmersive_routes')),
                    onTap: () {
                      HapticService().medium();
                      Navigator.pop(context);
                      context.go('/audios');
                    },
                  ),
                ),

                // --- Grupo de Emergencia (condicional) ---
                if (!kIsWeb && !isGuest) ...[
                  _SectionHeader(title: localeProvider.translate('emergency')),
                  _DrawerItem(
                    tileColor: theme.colorScheme.errorContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.sos,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      title: Text(
                        localeProvider.translate('SOS'),
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _showSosDialog(context),
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Padding para la barra de navegación del sistema
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// La cabecera con menú de configuración
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: 180 + topPadding,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 20),
      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spacer para empujar el contenido hacia abajo
          const Spacer(),

          // Row con icono de la app y botón de configuración
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono de la app en un contenedor
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.hiking,
                  size: 32,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              // Botón de configuración (menú popup)
              _SettingsMenuButton(theme: theme),
            ],
          ),
          const SizedBox(height: 16),
          // Nombre de la App
          Text(
            'Pilgrims 3D',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de configuración en la cabecera con menú popup
class _SettingsMenuButton extends StatelessWidget {
  const _SettingsMenuButton({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final authRepository = context.read<AuthRepository>();

    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.settings,
          color: theme.colorScheme.onSecondaryContainer,
          size: 24,
        ),
      ),
      color: theme.colorScheme.surface,
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder:
          (BuildContext context) => [
            // Opción de Modo Oscuro/Claro
            PopupMenuItem<String>(
              value: 'theme',
              enabled: false,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        themeProvider.isDarkMode
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localeProvider.translate('dark_mode'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Switch(
                      value: themeProvider.isDarkMode,
                      activeThumbColor: theme.colorScheme.primary,
                      onChanged: (value) {
                        HapticService().selection();
                        themeProvider.toggleTheme(value);
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuDivider(height: 12),
            // Opción de Idioma
            PopupMenuItem<String>(
              value: 'language',
              enabled: false,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.language,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localeProvider.translate('language'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: DropdownButton<String>(
                        value: localeProvider.currentIso,
                        underline: const SizedBox(),
                        isDense: true,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(
                              'English',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'es',
                            child: Text(
                              'Español',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'fr',
                            child: Text(
                              'Français',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'de',
                            child: Text(
                              'Deutsch',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'it',
                            child: Text(
                              'Italiano',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'pt',
                            child: Text(
                              'Português',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'ca',
                            child: Text(
                              'Català',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'gl',
                            child: Text(
                              'Galego',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            HapticService().selection();
                            localeProvider.setLocaleByIso(value);
                            Future.delayed(
                              const Duration(milliseconds: 100),
                              () {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuDivider(height: 12),
            // Opción About Us
            PopupMenuItem<String>(
              value: 'about',
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localeProvider.translate('about'),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () {
                HapticService().light();
                context.push('/about');
              },
            ),
            PopupMenuDivider(height: 12),
            // Opción Logout
            PopupMenuItem<String>(
              value: 'logout',
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.exit_to_app,
                        color: theme.colorScheme.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localeProvider.translate('logout'),
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () async {
                await HapticService().medium();
                AppRouter.guestMode = false;
                // Detener el servicio de tracking si estaba activo
                if (!kIsWeb) {
                  final service = FlutterBackgroundService();
                  if (await service.isRunning()) {
                    service.invoke('stopService');
                  }
                }
                await authRepository.signOut();
                if (context.mounted) {
                  context.go('/');
                }
              },
            ),
          ],
    );
  }
}

// --- WIDGETS AUXILIARES PARA UN DISEÑO LIMPIO ---

/// Un título de sección para agrupar elementos.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Un contenedor "pill-shaped" para cada elemento del menú.
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.child, this.tileColor});
  final Widget child;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color:
              tileColor ??
              Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          child: child,
        ),
      ),
    );
  }
}
