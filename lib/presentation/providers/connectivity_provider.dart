import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pilgrims_3d/services/api/api_service.dart' as api;
import 'package:pilgrims_3d/services/api/cache_refresh_service.dart';
import 'package:pilgrims_3d/core/config/env.dart';

/// Provider para gestionar el estado de conectividad a Internet
class ConnectivityProvider with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final CacheRefreshService _cacheRefreshService = CacheRefreshService();

  bool _isOnline = true;
  final bool _wasOffline = false; // Track previous offline state
  Timer?
  _forceRefreshTimer; // Timer para desactivar force refresh automáticamente
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  ConnectivityProvider() {
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  /// Verifica que haya conectividad REAL al servidor (no solo interfaz de red).
  /// connectivity_plus solo detecta si hay WiFi/datos conectados, pero no si
  /// hay acceso real a internet. Este método hace un DNS lookup al host del servidor
  /// para confirmar conectividad real antes de activar force refresh.
  Future<bool> _hasRealConnectivity() async {
    if (kIsWeb) return true; // En web no podemos hacer DNS lookup
    try {
      final host = Uri.parse(baseUrl).host;
      final result = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Inicializa y verifica la conectividad actual
  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);

      // Si está online al iniciar, verificar conectividad real antes de activar force refresh
      if (_isOnline) {
        final hasReal = await _hasRealConnectivity();
        if (hasReal) {
          debugPrint(
            '🔄 App iniciada en modo online - activando force refresh',
          );
          api.setForceRefreshMode(true);
          _scheduleForceRefreshDisable();
        } else {
          debugPrint(
            '⚠️ Red detectada pero sin internet real - no se activa force refresh',
          );
        }
      }
    } catch (e) {
      debugPrint('Error al verificar conectividad: $e');
      _isOnline = true; // Asumir online si hay error
      api.setOfflineMode(false);
    }
  }

  /// Actualiza el estado de conectividad
  void _updateConnectionStatus(List<ConnectivityResult> results) async {
    // Si hay algún resultado que no sea "none", hay conexión
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (_isOnline != hasConnection) {
      final previousState = _isOnline;
      _isOnline = hasConnection;

      debugPrint(
        '🌐 Estado de conectividad: ${_isOnline ? "ONLINE" : "OFFLINE"}',
      );

      // Actualizar el modo offline en api_service
      api.setOfflineMode(!_isOnline);
      debugPrint(
        '📡 Modo offline API: ${!_isOnline ? "ACTIVADO" : "DESACTIVADO"}',
      );

      // Si cambiamos de offline a online, verificar conectividad real antes de force refresh
      if (!previousState && _isOnline) {
        final hasReal = await _hasRealConnectivity();
        if (hasReal) {
          debugPrint('🔄 Cambio de OFFLINE a ONLINE - activando force refresh');
          api.setForceRefreshMode(true);
          _scheduleForceRefreshDisable();

          // Opcional: limpiar caché también
          try {
            await _cacheRefreshService.clearRefreshableCache();
          } catch (e) {
            debugPrint('❌ Error limpiando caché en cambio a online: $e');
          }
        } else {
          debugPrint(
            '⚠️ Red detectada pero sin internet real - no se activa force refresh',
          );
        }
      }

      // Si cambiamos de online a offline, desactivar force refresh
      if (previousState && !_isOnline) {
        api.setForceRefreshMode(false);
      }

      notifyListeners();
    }
  }

  /// Verifica manualmente la conectividad
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      return _isOnline;
    } catch (e) {
      debugPrint('Error al verificar conectividad: $e');
      return _isOnline;
    }
  }

  /// Fuerza la limpieza del caché si está online
  /// Útil para refrescar datos manualmente
  Future<void> forceRefreshCache() async {
    if (_isOnline) {
      debugPrint('🔄 Limpieza manual de caché solicitada');
      try {
        api.setForceRefreshMode(true);
        await _cacheRefreshService.clearRefreshableCache();
        debugPrint('✅ Caché limpiado manualmente y force refresh activado');
      } catch (e) {
        debugPrint('❌ Error en limpieza manual de caché: $e');
      }
    } else {
      debugPrint('⚠️ No se puede limpiar caché en modo offline');
    }
  }

  /// Desactiva el modo force refresh
  /// Útil para optimizar después del primer refresh
  void disableForceRefresh() {
    if (_isOnline) {
      api.setForceRefreshMode(false);
      _cancelForceRefreshTimer();
      debugPrint('🔄 Force refresh desactivado');
    }
  }

  /// Programa la desactivación automática del force refresh después de 5 minutos
  void _scheduleForceRefreshDisable() {
    _cancelForceRefreshTimer(); // Cancelar timer previo si existe

    _forceRefreshTimer = Timer(const Duration(minutes: 5), () {
      if (_isOnline) {
        api.setForceRefreshMode(false);
        debugPrint(
          '🔄 Force refresh desactivado automáticamente después de 5 minutos',
        );
      }
    });

    debugPrint('⏰ Force refresh se desactivará automáticamente en 5 minutos');
  }

  /// Cancela el timer del force refresh
  void _cancelForceRefreshTimer() {
    _forceRefreshTimer?.cancel();
    _forceRefreshTimer = null;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _cancelForceRefreshTimer();
    super.dispose();
  }
}
