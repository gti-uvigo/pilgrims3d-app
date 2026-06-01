import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:pilgrims_3d/services/model3d/model_cache_service.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pilgrims_3d/core/config/env.dart';

class ModelViewerScreen extends StatefulWidget {
  final String modelUrl;

  const ModelViewerScreen({super.key, required this.modelUrl});

  @override
  State<ModelViewerScreen> createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends State<ModelViewerScreen> {
  bool _isLoading = true;
  String? _localModelPath;
  String? _errorMessage;
  double _downloadProgress = 0.0;
  final ModelCacheService _cacheService = ModelCacheService();

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _downloadProgress = 0.0;
      });

      // Obtener el modelo desde la caché o descargarlo
      final localPath = await _cacheService.getModelPath(widget.modelUrl, (
        progress,
      ) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      });

      if (mounted) {
        setState(() {
          _localModelPath = localPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar el modelo: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We'll use localized strings via LocaleProvider when available
    // ignore: unused_local_variable
    // final localeProvider = context.read<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visor de Modelo 3D'),
        centerTitle: true,
        actions: [
          if (_localModelPath != null && !_isLoading)
            IconButton(
              tooltip: 'Abrir en visor 3D Rooom',
              icon: const Icon(Icons.threed_rotation),
              onPressed: () async {
                final uri = Uri.parse(
                  'https://$rooomViewerHost$rooomViewerPath'
                  '?middleware=dlf/embedded3dviewer'
                  '&model=${Uri.encodeComponent(widget.modelUrl)}'
                  '&viewer',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Mostrar el modelo solo si está cargado
          if (_localModelPath != null && !_isLoading)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: ModelViewer(
                // En web usar la URL directamente, en nativo usar file://
                src:
                    _localModelPath!.startsWith('http')
                        ? _localModelPath!
                        : 'file://$_localModelPath',
                alt: 'Un modelo',
                ar: false,
                autoRotate: false,
                cameraControls: true,
                backgroundColor: Colors.grey[200]!,
                loading: Loading.eager,
              ),
            ),

          // Mostrar error si hay alguno
          if (_errorMessage != null && !_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadModel,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Mostrar indicador de carga
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value:
                                _downloadProgress > 0
                                    ? _downloadProgress
                                    : null,
                            strokeWidth: 6,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        if (_downloadProgress > 0)
                          Text(
                            '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _cacheService.isModelCached(widget.modelUrl)
                          ? 'Cargando modelo desde caché...'
                          : 'Descargando modelo 3D...',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget? _buildFab(BuildContext context) {
    if (_localModelPath == null || _isLoading) return null;

    // ── Web: botón WebXR AR para HoloLens 2 / Edge ────────────────────────
    if (kIsWeb) {
      return FloatingActionButton.extended(
        heroTag: 'btnWebXR',
        onPressed: () async {
          // Uri.base da la URL absoluta actual; resolve() construye la URL completa
          final uri = Uri.base.resolve(
            'ar_viewer.html?modelUrl=${Uri.encodeComponent(widget.modelUrl)}',
          );
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        },
        backgroundColor: Colors.indigo[700],
        icon: const Icon(Icons.view_in_ar),
        label: const Text('Ver en AR'),
      );
    }

    // ── Mobile: botones Rooom + AR nativo ─────────────────────────────────
    if (!Platform.isAndroid && !Platform.isIOS) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'btnRooom',
          onPressed: () async {
            HapticService().light();
            final uri = Uri.parse(
              'https://$rooomViewerHost$rooomViewerPath'
              '?middleware=dlf/embedded3dviewer'
              '&model=${Uri.encodeComponent(widget.modelUrl)}'
              '&viewer',
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          backgroundColor: Colors.blue[700],
          child: const Icon(Icons.threed_rotation),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'btnAR',
          onPressed: () {
            HapticService().light();
            context.push(
              '/arScreen?modelUrl=${Uri.encodeComponent(widget.modelUrl)}',
            );
          },
          backgroundColor: Colors.green[700],
          child: const Icon(Icons.view_in_ar),
        ),
      ],
    );
  }
}
