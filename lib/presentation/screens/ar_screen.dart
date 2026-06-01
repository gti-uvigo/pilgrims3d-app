// Automatic FlutterFlow imports
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pilgrims_3d/services/model3d/model_cache_service.dart';

class ARScreen extends StatefulWidget {
  // Permite pasar la URL del modelo; si no se pasa, se usa la fija actual
  const ARScreen({super.key, this.width, this.height, this.modelUrl});

  final double? width;
  final double? height;
  final String? modelUrl;

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];
  double nodeScale = 5.0; // Escala muy grande para visibilidad
  ARNode? selectedNode;
  Vector3? selectedNodePosition;
  String? cachedModelPath;
  String?
  cachedModelRelativePath; // Ruta relativa (p.ej., "models/downloaded_model.glb")
  String? cachedModelFileUri; // URI con esquema file:// de la ruta absoluta
  bool isLoadingModel = false;
  double? downloadProgress; // 0.0 - 1.0 durante la descarga
  DateTime? _lastProgressUiUpdate;
  Timer? _scaleDebounceTimer;
  int? _cachedFileSize;

  // Variables para auto-colocación
  bool autoPlacementEnabled = true;
  bool hasDetectedPlane = false;
  ARPlaneAnchor? lastDetectedPlane;

  // Variables de UI
  bool showControls = true;
  bool isPlacingModel = false;
  bool? arCoreAvailable; // null = comprobando, true/false = resultado

  final ModelCacheService _modelCache =
      ModelCacheService(); // Usar el mismo servicio de caché

  static const String _modelUrl =
      "https://zenodo.org/api/files/c5aedabd-c5ff-4f4c-bdfa-09dd09cf7121/ad13d72f8726429a8a2054524d6564ee.glb";

  String get _resolvedModelUrl => widget.modelUrl ?? _modelUrl;

  // ELIMINADO: static const String _localAssetPath = "data3D/prueba.glb";

  @override
  void initState() {
    super.initState();
    debugPrint("[AR INIT] initState llamado");
    _checkARCoreAvailability();
  }

  Future<void> _checkARCoreAvailability() async {
    // ARCore no está disponible en Quest 2 ni en la mayoría de tablets sin cámara AR
    // Intentamos inicializar y capturamos el error
    try {
      // Si el plugin no puede inicializar ARCore lanza una PlatformException
      // Lo detectamos intentando crear una sesión de prueba; si no podemos,
      // mostramos el fallback de visor 3D.
      // Por ahora usamos una heurística: en Quest los fallos llegan en onARViewCreated
      // así que marcamos como disponible y capturamos el error allí.
      setState(() { arCoreAvailable = true; });
    } catch (_) {
      setState(() { arCoreAvailable = false; });
    }
  }

  @override
  void dispose() {
    _scaleDebounceTimer?.cancel();
    super.dispose();
    arSessionManager?.dispose();
  }

  Future<String> _getCachedModelPath() async {
    debugPrint("[AR] Obteniendo modelo desde URL usando ModelCacheService...");

    if (isLoadingModel) {
      debugPrint("[AR] Carga ya en progreso, esperando...");
      // Espera activa (con límite) a que termine la carga en curso
      for (int i = 0; i < 150; i++) {
        if (!isLoadingModel && cachedModelPath != null) {
          debugPrint(
            "[AR] Carga en curso finalizada, usando path: $cachedModelPath",
          );
          return cachedModelPath!;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // Si sigue cargando después de 15s, lanza error
      if (isLoadingModel) {
        throw Exception("Timeout esperando carga de modelo en progreso");
      }
    }

    // Si ya está descargado, devolverlo (en memoria)
    if (cachedModelPath != null) {
      final file = File(cachedModelPath!);
      if (file.existsSync()) {
        debugPrint(
          "[AR] Usando modelo ya descargado (memoria): $cachedModelPath",
        );
        return cachedModelPath!;
      }
    }

    // Usar ModelCacheService para obtener el modelo (compartido con visor 3D)
    isLoadingModel = true;
    if (mounted) setState(() {});

    try {
      debugPrint(
        "[AR] Solicitando modelo a ModelCacheService: $_resolvedModelUrl",
      );

      final modelPath = await _modelCache.getModelPath(_resolvedModelUrl, (
        progress,
      ) {
        // Actualizar progreso en la UI de AR
        final now = DateTime.now();
        if (_lastProgressUiUpdate == null ||
            now.difference(_lastProgressUiUpdate!).inMilliseconds > 100) {
          downloadProgress = progress;
          _lastProgressUiUpdate = now;
          if (mounted) setState(() {});
        }
      });

      // Cachear la ruta obtenida
      cachedModelPath = modelPath;

      // Si es un archivo local, generar las variantes necesarias para AR
      if (!modelPath.startsWith('http')) {
        final file = File(modelPath);
        if (file.existsSync()) {
          cachedModelFileUri = 'file://$modelPath';

          // Para AR, intentar generar ruta relativa desde el directorio de documentos
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final appDirPath = appDir.path;

            if (modelPath.startsWith(appDirPath)) {
              // Generar ruta relativa desde el directorio de documentos
              cachedModelRelativePath = modelPath.substring(
                appDirPath.length + 1,
              );
              debugPrint(
                "[AR] Ruta relativa generada: $cachedModelRelativePath",
              );

              // También intentar copiar a un nombre estándar para AR si es necesario
              final modelsDir = Directory('$appDirPath/models');
              if (!await modelsDir.exists()) {
                await modelsDir.create(recursive: true);
              }

              // Si el archivo no está ya en models/, copiarlo ahí
              if (!modelPath.contains('/models/')) {
                // Usar nombre basado en la URL para evitar colisiones entre modelos
                final urlSegment = Uri.parse(
                  _resolvedModelUrl,
                ).pathSegments.lastWhere(
                  (s) => s.isNotEmpty,
                  orElse: () => 'ar_model.glb',
                );
                final standardName =
                    urlSegment.endsWith('.glb')
                        ? urlSegment
                        : 'ar_model_${urlSegment.hashCode.abs()}.glb';
                final standardPath = '${modelsDir.path}/$standardName';

                // Siempre sobreescribir para asegurar que el modelo es el correcto
                await file.copy(standardPath);
                debugPrint(
                  "[AR] Modelo copiado a ruta estándar: $standardPath",
                );

                // Actualizar las rutas para usar la copia estándar
                cachedModelPath = standardPath;
                cachedModelRelativePath = 'models/$standardName';
                cachedModelFileUri = 'file://$standardPath';
              }
            }
          } catch (e) {
            debugPrint("[AR] No se pudo generar ruta relativa: $e");
          }

          _cachedFileSize = await file.length();
        }
      }

      debugPrint("[AR] ✅ Modelo obtenido exitosamente: $modelPath");
      return modelPath;
    } catch (e) {
      debugPrint("[AR] ❌ Error obteniendo modelo: $e");
      throw Exception("No se pudo cargar el modelo: $e");
    } finally {
      isLoadingModel = false;
      downloadProgress = null;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fallback: ARCore no disponible (Quest 2, emulador, etc.)
    if (arCoreAvailable == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('AR no disponible')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.view_in_ar, size: 72, color: Colors.grey),
                const SizedBox(height: 24),
                const Text(
                  'Este dispositivo no soporta ARCore',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Quest 2 no tiene soporte ARCore. Usa el visor 3D o el modo VR/AR web.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver al visor 3D'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text('AR Viewer', style: TextStyle(color: Colors.white)),
            const Spacer(),
            // Indicador de estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasDetectedPlane ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hasDetectedPlane
                    ? 'Superficie detectada'
                    : 'Buscando superficie...',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Vista AR
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // Overlay de carga
          if (isLoadingModel || isPlacingModel)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: downloadProgress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white24,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isPlacingModel
                          ? 'Colocando modelo...'
                          : downloadProgress != null
                          ? 'Descargando... ${(downloadProgress! * 100).toStringAsFixed(0)}%'
                          : 'Cargando modelo...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Controles inferiores
          if (showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Control de escala
                    if (selectedNode != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tamaño',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${(nodeScale * 20).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: Colors.blue,
                                inactiveTrackColor: Colors.grey[300],
                                thumbColor: Colors.blue,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 12,
                                ),
                                trackHeight: 6,
                              ),
                              child: Slider(
                                value: nodeScale,
                                min: 1.0,
                                max: 15.0,
                                divisions: 28,
                                onChanged: (value) {
                                  setState(() {
                                    nodeScale = value;
                                    _updateSelectedNodeScale();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Botón de auto-colocación
                        _buildActionButton(
                          icon:
                              autoPlacementEnabled
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                          label: autoPlacementEnabled ? 'Manual' : 'Auto',
                          color:
                              autoPlacementEnabled
                                  ? Colors.orange
                                  : Colors.green,
                          onPressed: () {
                            setState(() {
                              autoPlacementEnabled = !autoPlacementEnabled;
                            });
                            _showMessage(
                              autoPlacementEnabled
                                  ? 'Modo automático activado'
                                  : 'Modo manual activado - toca para colocar',
                            );
                          },
                        ),

                        // Botón de colocar/recolocar
                        if (hasDetectedPlane)
                          _buildActionButton(
                            icon:
                                selectedNode != null
                                    ? Icons.refresh
                                    : Icons.add_circle_outline,
                            label:
                                selectedNode != null ? 'Recolocar' : 'Colocar',
                            color: Colors.blue,
                            onPressed: _placeOrReplaceModel,
                          ),

                        // Botón de eliminar
                        if (selectedNode != null)
                          _buildActionButton(
                            icon: Icons.delete_outline,
                            label: 'Eliminar',
                            color: Colors.red,
                            onPressed: _deleteSelectedNode,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Indicador de superficie
          if (!hasDetectedPlane && !isLoadingModel)
            Positioned(
              top: 120,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.camera_alt, color: Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Mueve el dispositivo lentamente para detectar superficies planas',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: onPressed,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    debugPrint("[AR] onARViewCreated llamado");
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    // Capturar errores de ARCore (Quest 2, dispositivos sin soporte)
    this.arSessionManager!.onError = (error) {
      debugPrint("[AR] Error de sesión ARCore: $error");
      if (error.contains('ARCore') ||
           error.contains('UNAVAILABLE') ||
           error.contains('not supported')) {
        if (mounted) setState(() => arCoreAvailable = false);
      }
    };

    debugPrint("[AR] Llamando onInitialize...");
    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true, // Mostrar planos para mejor visualización
      showWorldOrigin: false,
    );
    this.arObjectManager!.onInitialize();

    debugPrint("[AR] Asignando callbacks...");

    // Configurar detección de planos
    this.arSessionManager!.onPlaneDetected = (plane) {
      // Detección básica sin auto-colocación por ahora
      if (!hasDetectedPlane) {
        setState(() {
          hasDetectedPlane = true;
        });
      }
    };

    // Callback para toque (manual y auto-colocación)
    this.arSessionManager!.onPlaneOrPointTap = (
      List<ARHitTestResult> hitResults,
    ) {
      if (hitResults.isNotEmpty) {
        if (autoPlacementEnabled && selectedNode == null && hasDetectedPlane) {
          // Auto-colocación: colocar inmediatamente cuando se toca una superficie
          _placeModelManually(hitResults);
        } else if (!autoPlacementEnabled) {
          // Modo manual: solo cuando está deshabilitado el auto
          _placeModelManually(hitResults);
        }
      }
    };

    this.arObjectManager!.onNodeTap = onNodeTapped;
    debugPrint("[AR] ✓ AR inicializado correctamente");
  }

  Future<void> onRemoveEverything() async {
    // ... (onRemoveEverything sin cambios)
    for (var anchor in anchors) {
      arAnchorManager!.removeAnchor(anchor);
    }
    anchors = [];
    nodes = [];
    selectedNode = null;
    setState(() {});
  }

  Future<void> onNodeTapped(List<String> tappedNodes) async {
    // ... (onNodeTapped sin cambios)
    if (tappedNodes.isEmpty) return;

    final nodeName = tappedNodes.first;
    final tappedNode = nodes.firstWhere((node) => node.name == nodeName);

    setState(() {
      selectedNode = tappedNode;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Nodo seleccionado - Arrastra para mover"),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateSelectedNodeScale() {
    if (selectedNode != null && arObjectManager != null && nodes.isNotEmpty) {
      debugPrint("[AR] Escala movida a: $nodeScale");

      // Actualizar la escala en el objeto
      selectedNode!.scale = Vector3(nodeScale, nodeScale, nodeScale);

      // Cancelar el timer anterior si existe
      _scaleDebounceTimer?.cancel();

      // Crear nuevo timer - solo redibuja si el usuario deja de mover el slider
      _scaleDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        debugPrint("[AR] Redibujando nodo después de pausa en slider...");
        _redrawSelectedNode();
      });
    }
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  // Devuelve la URI preferida para el modelo, probando múltiples formatos
  String _preferredModelUri(String absolutePath) {
    // Orden de preferencia para AR:
    // 1. Ruta relativa (suele funcionar mejor en AR)
    if (cachedModelRelativePath != null) {
      debugPrint("[AR] Usando ruta relativa: $cachedModelRelativePath");
      return cachedModelRelativePath!;
    }

    // 2. URI con esquema file:// (funciona en algunos casos)
    if (cachedModelFileUri != null) {
      debugPrint("[AR] Usando file:// URI: $cachedModelFileUri");
      return cachedModelFileUri!;
    }

    // 3. Fallback: ruta absoluta
    debugPrint("[AR] Usando ruta absoluta: $absolutePath");
    return absolutePath;
  }

  Future<void> _clearCachedModel() async {
    try {
      // Limpiar caché local de AR
      if (cachedModelPath != null) {
        final f = File(cachedModelPath!);
        if (await f.exists()) {
          // No eliminar el archivo físico ya que puede estar siendo usado por ModelCacheService
          debugPrint('[AR] Limpiando referencia de caché local: ${f.path}');
        }
      }

      // Limpiar variables locales de AR
      cachedModelPath = null;
      cachedModelRelativePath = null;
      cachedModelFileUri = null;
      _cachedFileSize = null;

      if (mounted) setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caché local de AR limpiada')),
      );
    } catch (e) {
      debugPrint('[AR] Error limpiando caché: $e');
      _showError('Error', 'No se pudo limpiar la caché: $e');
    }
  }

  // Colocar modelo automáticamente cuando se detecta una superficie
  Future<void> _placeModelAutomatically() async {
    if (lastDetectedPlane == null || isPlacingModel || selectedNode != null) {
      return;
    }

    setState(() {
      isPlacingModel = true;
    });

    debugPrint("[AR] Colocando modelo automáticamente...");

    try {
      await _placeModelAtAnchor(lastDetectedPlane!);
      _showMessage('Modelo colocado automáticamente');
    } catch (e) {
      debugPrint("[AR] Error en colocación automática: $e");
      _showError("Error", "No se pudo colocar el modelo automáticamente");
    } finally {
      setState(() {
        isPlacingModel = false;
      });
    }
  }

  // Colocar modelo manualmente cuando el usuario toca
  Future<void> _placeModelManually(List<ARHitTestResult> hitResults) async {
    if (isPlacingModel) return;

    setState(() {
      isPlacingModel = true;
    });

    try {
      var hitResult = hitResults.firstWhere(
        (result) => result.type == ARHitTestResultType.plane,
        orElse: () => hitResults.first,
      );

      var anchor = ARPlaneAnchor(transformation: hitResult.worldTransform);
      await _placeModelAtAnchor(anchor);
      _showMessage('Modelo colocado');
    } catch (e) {
      debugPrint("[AR] Error en colocación manual: $e");
      _showError("Error", "No se pudo colocar el modelo");
    } finally {
      setState(() {
        isPlacingModel = false;
      });
    }
  }

  // Colocar o reemplazar el modelo
  Future<void> _placeOrReplaceModel() async {
    if (isPlacingModel) return;

    // Si ya hay un modelo, eliminarlo primero
    if (selectedNode != null) {
      await _deleteSelectedNode();
    }

    // Colocar nuevo modelo
    if (hasDetectedPlane && lastDetectedPlane != null) {
      await _placeModelAutomatically();
    } else {
      _showError("Error", "No se ha detectado ninguna superficie");
    }
  }

  // Método común para colocar modelo en un anchor
  Future<void> _placeModelAtAnchor(ARPlaneAnchor anchor) async {
    // Añadir anchor
    bool? didAddAnchor = await arAnchorManager!.addAnchor(anchor);
    if (didAddAnchor != true) {
      throw Exception("No se pudo crear el anchor");
    }

    anchors.add(anchor);

    try {
      // Obtener modelo
      String modelPath = await _getCachedModelPath();
      String uri = _preferredModelUri(modelPath);

      // Crear nodo
      var newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLTF2,
        uri: uri,
        scale: Vector3(nodeScale, nodeScale, nodeScale),
        rotation: Vector4(0, 1, 0, 0),
        position: Vector3(0, 0, 0),
        name: "model_${DateTime.now().millisecondsSinceEpoch}",
      );

      // Añadir nodo
      bool? didAddNode = await arObjectManager!.addNode(
        newNode,
        planeAnchor: anchor,
      );

      if (didAddNode == true) {
        nodes.add(newNode);
        setState(() {
          selectedNode = newNode;
        });
        debugPrint("[AR] ✓ Modelo colocado exitosamente");
      } else {
        // Intentar estrategias alternativas
        await _tryAlternativeNodePlacement(newNode, anchor, modelPath);
      }
    } catch (e) {
      // Limpiar anchor si falla
      await arAnchorManager!.removeAnchor(anchor);
      anchors.remove(anchor);
      rethrow;
    }
  }

  // Intentar colocación alternativa con diferentes URIs
  Future<void> _tryAlternativeNodePlacement(
    ARNode originalNode,
    ARPlaneAnchor anchor,
    String modelPath,
  ) async {
    List<String> alternatives = [
      modelPath,
      'file://$modelPath',
      modelPath.split('/').last,
    ];

    for (String uri in alternatives) {
      var testNode = ARNode(
        type: NodeType.fileSystemAppFolderGLTF2,
        uri: uri,
        scale: originalNode.scale,
        rotation: Vector4(
          0,
          1,
          0,
          0,
        ), // Usar Vector4 en lugar de originalNode.rotation
        position: originalNode.position,
        name: originalNode.name,
      );

      bool? success = await arObjectManager!.addNode(
        testNode,
        planeAnchor: anchor,
      );
      if (success == true) {
        nodes.add(testNode);
        setState(() {
          selectedNode = testNode;
        });
        debugPrint("[AR] ✓ Modelo colocado con URI alternativa: $uri");
        return;
      }
    }

    throw Exception("No se pudo colocar el modelo con ninguna URI");
  }

  // Mostrar mensaje al usuario
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ===== CAMBIO AQUÍ =====
  // La función ahora es async para poder llamar a _getCachedModelPath
  Future<void> _redrawSelectedNode() async {
    if (selectedNode == null || arObjectManager == null) return;

    try {
      // ===== CAMBIO AQUÍ =====
      // Obtener la ruta del modelo cacheado
      final String modelPath = await _getCachedModelPath();
      String? modelRelativePath = cachedModelRelativePath;

      final nodeToRedraw = selectedNode!;
      final nodeIndex = nodes.indexOf(nodeToRedraw);

      if (nodeIndex < 0 || nodeIndex >= anchors.length) {
        debugPrint("[AR] Índice del nodo inválido");
        return;
      }

      debugPrint("[AR] Redibujando nodo con nueva escala...");

      // Remover el nodo actual
      try {
        await arObjectManager?.removeNode(nodeToRedraw);
        debugPrint("[AR] Nodo removido para redibujarlo");
      } catch (e) {
        debugPrint("[AR] Error removiendo nodo: $e");
      }

      // Crear un nuevo nodo con la escala actualizada
      // Elegir URI preferida: en Android intentamos primero con file:// absoluta
      final String initialUri = _preferredModelUri(modelPath);
      debugPrint('[AR] URI inicial para redibujar: $initialUri');

      var redrawNode = ARNode(
        // ===== CAMBIO AQUÍ =====
        type: NodeType.fileSystemAppFolderGLTF2,
        uri: initialUri, // Preferir file:// en Android
        scale: Vector3(nodeScale, nodeScale, nodeScale),
        rotation: Vector4(0, 1, 0, 0),
        position: Vector3(0, 0, 0),
        // Asignar el mismo nombre para que onNodeTapped funcione
        name: nodeToRedraw.name,
      );

      // Añadir el nodo redibujado (con reintentos)
      bool? didAddNode = await arObjectManager!.addNode(
        redrawNode,
        planeAnchor: anchors[nodeIndex] as ARPlaneAnchor?,
      );

      if (didAddNode == true) {
        // Reemplazar el nodo en la lista
        nodes[nodeIndex] = redrawNode;
        selectedNode = redrawNode;

        debugPrint("[AR] ✓ Nodo redibujado con escala $nodeScale");
      } else {
        debugPrint(
          "[AR] Error redibujando nodo con ruta relativa (${modelRelativePath ?? 'null'}). Reintentando con ruta absoluta...",
        );
        // Intento 2: usar ruta absoluta
        var redrawNodeAbs = ARNode(
          type: NodeType.fileSystemAppFolderGLTF2,
          uri: modelPath,
          scale: Vector3(nodeScale, nodeScale, nodeScale),
          rotation: Vector4(0, 1, 0, 0),
          position: Vector3(0, 0, 0),
          name: nodeToRedraw.name,
        );
        didAddNode = await arObjectManager!.addNode(
          redrawNodeAbs,
          planeAnchor: anchors[nodeIndex] as ARPlaneAnchor?,
        );

        if (didAddNode == true) {
          nodes[nodeIndex] = redrawNodeAbs;
          selectedNode = redrawNodeAbs;
          debugPrint("[AR] ✓ Nodo redibujado con ruta absoluta");
        } else {
          // Intento 3: mover el archivo a la raíz del directorio de la app y usar solo el nombre
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final target = File('${appDir.path}/downloaded_model.glb');
            if (File(modelPath).path != target.path) {
              await File(modelPath).copy(target.path);
              debugPrint("[AR] Copiado modelo a raíz: ${target.path}");
            }
            modelRelativePath = 'downloaded_model.glb';
            var redrawNodeRoot = ARNode(
              type: NodeType.fileSystemAppFolderGLTF2,
              uri: modelRelativePath,
              scale: Vector3(nodeScale, nodeScale, nodeScale),
              rotation: Vector4(0, 1, 0, 0),
              position: Vector3(0, 0, 0),
              name: nodeToRedraw.name,
            );
            didAddNode = await arObjectManager!.addNode(
              redrawNodeRoot,
              planeAnchor: anchors[nodeIndex] as ARPlaneAnchor?,
            );
            if (didAddNode == true) {
              nodes[nodeIndex] = redrawNodeRoot;
              selectedNode = redrawNodeRoot;
              cachedModelPath = target.path;
              cachedModelRelativePath = modelRelativePath;
              debugPrint(
                "[AR] ✓ Nodo redibujado usando nombre de archivo en raíz: $modelRelativePath",
              );
            } else {
              // Intento 4: ruta absoluta con esquema file://
              final fileUri = 'file://$modelPath';
              var redrawNodeFileUri = ARNode(
                type: NodeType.fileSystemAppFolderGLTF2,
                uri: fileUri,
                scale: Vector3(nodeScale, nodeScale, nodeScale),
                rotation: Vector4(0, 1, 0, 0),
                position: Vector3(0, 0, 0),
                name: nodeToRedraw.name,
              );
              didAddNode = await arObjectManager!.addNode(
                redrawNodeFileUri,
                planeAnchor: anchors[nodeIndex] as ARPlaneAnchor?,
              );
              if (didAddNode == true) {
                nodes[nodeIndex] = redrawNodeFileUri;
                selectedNode = redrawNodeFileUri;
                debugPrint("[AR] ✓ Nodo redibujado con file:// URI");
              } else {
                debugPrint("[AR] Error redibujando nodo tras reintentos");
                selectedNode = nodeToRedraw; // restaurar referencia
              }
            }
          } catch (e) {
            debugPrint("[AR] Error en reintento de redibujado: $e");
            selectedNode = nodeToRedraw;
          }
        }
      }
    } catch (e) {
      debugPrint("[AR] Error en _redrawSelectedNode: $e");
      _showError(
        "Error redibujando",
        "No se pudo cargar el modelo cacheado: $e",
      );
    }
  }

  Future<void> _deleteSelectedNode() async {
    if (selectedNode != null) {
      debugPrint("[AR] Eliminando nodo seleccionado...");

      try {
        // Encontrar el índice del nodo
        final nodeIndex = nodes.indexOf(selectedNode!);

        // Eliminar el anchor correspondiente
        if (nodeIndex >= 0 && nodeIndex < anchors.length) {
          debugPrint("[AR] Eliminando anchor en índice $nodeIndex");
          await arAnchorManager?.removeAnchor(anchors[nodeIndex]);
          anchors.removeAt(nodeIndex);
        }

        // Eliminar el nodo de ARObjectManager
        try {
          debugPrint("[AR] Eliminando nodo de ARObjectManager...");
          await arObjectManager?.removeNode(selectedNode!);
          debugPrint("[AR] Nodo eliminado de ARObjectManager");
        } catch (e) {
          debugPrint("[AR] removeNode no disponible o error: $e");
        }

        // Eliminar de la lista local
        nodes.remove(selectedNode!);
        selectedNode = null;

        setState(() {});
        _showMessage('Modelo eliminado');
        debugPrint("[AR] ✓ Nodo eliminado exitosamente");
      } catch (e) {
        debugPrint("[AR] ✗ Error eliminando nodo: $e");
        _showError("Error", "No se pudo eliminar el modelo: $e");
      }
    }
  }

  Future<void> onPlaneOrPointTapped(
    List<ARHitTestResult> hitTestResults,
  ) async {
    debugPrint(
      "[AR] onPlaneOrPointTapped llamado con ${hitTestResults.length} resultados",
    );

    // ✅ LIMITE: solo permitir 1 objeto máximo
    if (nodes.isNotEmpty) {
      debugPrint("[AR] Ya hay un objeto en la escena. Máximo 1 permitido.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Solo puedes tener 1 objeto. Elimina el actual para añadir otro.",
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (hitTestResults.isEmpty) {
      debugPrint("[AR] Sin resultados de hit test");
      return;
    }

    var singleHitTestResult = hitTestResults.firstWhere(
      (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane,
      orElse: () => hitTestResults.first,
    );

    debugPrint("[AR] Creando nuevo anchor...");
    var newAnchor = ARPlaneAnchor(
      transformation: singleHitTestResult.worldTransform,
    );
    bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);

    debugPrint("[AR] Anchor añadido: $didAddAnchor");

    if (didAddAnchor == true) {
      anchors.add(newAnchor);

      // Cargar modelo - la primera vez tarda, las siguientes son instantáneas
      debugPrint("[AR] Obteniendo ruta del modelo...");
      String modelPath;
      try {
        modelPath = await _getCachedModelPath();
        debugPrint("[AR] Usando modelo: $modelPath");
        try {
          final f = File(modelPath);
          _cachedFileSize = await f.length();
          if (mounted) setState(() {});
        } catch (_) {}
      } catch (e) {
        debugPrint("[AR] ✗ Error al obtener modelo: $e");
        _showError(
          "Error de Modelo",
          "No se pudo descargar o encontrar el modelo: $e",
        );
        // Si falla la descarga, eliminar el anchor recién creado
        await arAnchorManager!.removeAnchor(newAnchor);
        anchors.remove(newAnchor);
        return;
      }

      // Verificar que el archivo existe
      final modelFile = File(modelPath);
      final fileExists = modelFile.existsSync();
      debugPrint(
        "[AR] Archivo existe: $fileExists, tamaño: ${fileExists ? modelFile.lengthSync() : 0} bytes",
      );

      if (!fileExists) {
        _showError(
          "Error de Archivo",
          "El archivo del modelo no se encontró en la caché.",
        );
        await arAnchorManager!.removeAnchor(newAnchor);
        anchors.remove(newAnchor);
        return;
      }

      debugPrint("[AR] Añadiendo nodo al anchor...");
      debugPrint("[AR] Datos del anchor: ${newAnchor.transformation}");
      if (cachedModelRelativePath != null) {
        debugPrint(
          "[AR] URI relativa para NodeType.fileSystemAppFolderGLTF2: $cachedModelRelativePath",
        );
      } else {
        debugPrint(
          "[AR] Advertencia: ruta relativa no establecida, usando absoluta",
        );
      }

      // ✅ Crear nodo con posición, escala y rotación explícitas
      // Elegir URI preferida: en Android intentamos primero con file:// absoluta
      final String initialUri = _preferredModelUri(modelPath);
      debugPrint('[AR] URI inicial para addNode: $initialUri');

      var newNode = ARNode(
        // ===== CAMBIO AQUÍ =====
        type:
            NodeType
                .fileSystemAppFolderGLTF2, // Usar fileSystemAppFolderGLTF2 para archivos del dispositivo
        uri: initialUri, // Preferir file:// en Android
        scale: Vector3(nodeScale, nodeScale, nodeScale),
        rotation: Vector4(0, 1, 0, 0),
        position: Vector3(0, 0, 0),
        // Darle un nombre único para poder seleccionarlo
        name: "node_${nodes.length}",
      );

      debugPrint("[AR] Nodo creado: tipo=${newNode.type}, uri=${newNode.uri}");
      debugPrint(
        "[AR] Position: (0,0,0), Scale: $nodeScale, Rotation: (0,1,0,0)",
      );
      debugPrint(
        "[AR] Tamaño del archivo: ${_cachedFileSize != null ? '${_cachedFileSize! ~/ 1024}KB' : 'desconocido'}",
      );

      // Verificar que el archivo existe antes de añadir el nodo
      if (!await modelFile.exists()) {
        debugPrint("[AR] ❌ ERROR: El archivo del modelo no existe: $modelPath");
        _showError(
          "Error de Archivo",
          "El archivo del modelo no se encontró: $modelPath",
        );
        await arAnchorManager!.removeAnchor(newAnchor);
        anchors.remove(newAnchor);
        return;
      }

      final fileSize = await modelFile.length();
      debugPrint(
        "[AR] ✅ Archivo verificado: ${fileSize ~/ 1024}KB en $modelPath",
      );

      // Intentar añadir con anchor
      bool? didAddNodeToAnchor = await arObjectManager!.addNode(
        newNode,
        planeAnchor: newAnchor,
      );
      debugPrint("[AR] addNode retornó: $didAddNodeToAnchor");

      if (didAddNodeToAnchor == true) {
        nodes.add(newNode);
        setState(() {
          selectedNode = newNode;
        });
        debugPrint("[AR] ✓ Nodo añadido exitosamente con URI: ${newNode.uri}");
        debugPrint("[AR] Total de nodos en escena: ${nodes.length}");
      } else {
        debugPrint("[AR] ✗ Fallo inicial. Reintentando con ruta absoluta...");

        // Reintento 2: usar ruta absoluta
        var newNodeAbs = ARNode(
          type: NodeType.fileSystemAppFolderGLTF2,
          uri: modelPath,
          scale: Vector3(nodeScale, nodeScale, nodeScale),
          rotation: Vector4(0, 1, 0, 0),
          position: Vector3(0, 0, 0),
          name: "node_${nodes.length}",
        );
        debugPrint("[AR] Reintento con URI absoluta: $modelPath");

        didAddNodeToAnchor = await arObjectManager!.addNode(
          newNodeAbs,
          planeAnchor: newAnchor,
        );
        debugPrint("[AR] addNode (absoluta) retornó: $didAddNodeToAnchor");

        if (didAddNodeToAnchor == true) {
          nodes.add(newNodeAbs);
          setState(() {
            selectedNode = newNodeAbs;
          });
          debugPrint("[AR] ✓ Nodo añadido con ruta absoluta");
        } else {
          debugPrint(
            "[AR] ✗ Fallo con absoluta. Reintentando con file:// URI...",
          );

          // Reintento 3: usar file:// URI
          var newNodeFileUri = ARNode(
            type: NodeType.fileSystemAppFolderGLTF2,
            uri: 'file://$modelPath',
            scale: Vector3(nodeScale, nodeScale, nodeScale),
            rotation: Vector4(0, 1, 0, 0),
            position: Vector3(0, 0, 0),
            name: "node_${nodes.length}",
          );
          debugPrint("[AR] Reintento con file:// URI: file://$modelPath");

          didAddNodeToAnchor = await arObjectManager!.addNode(
            newNodeFileUri,
            planeAnchor: newAnchor,
          );
          debugPrint("[AR] addNode (file://) retornó: $didAddNodeToAnchor");

          if (didAddNodeToAnchor == true) {
            nodes.add(newNodeFileUri);
            setState(() {
              selectedNode = newNodeFileUri;
            });
            debugPrint("[AR] ✓ Nodo añadido con file:// URI");
          } else {
            // Reintento 4: copiar archivo a nombre estándar en raíz
            try {
              final appDir = await getApplicationDocumentsDirectory();
              final target = File('${appDir.path}/ar_model.glb');
              if (File(modelPath).path != target.path) {
                await File(modelPath).copy(target.path);
                debugPrint("[AR] Copiado modelo a raíz: ${target.path}");
              }
              final rootRelative = 'ar_model.glb';
              var newNodeRoot = ARNode(
                type: NodeType.fileSystemAppFolderGLTF2,
                uri: rootRelative,
                scale: Vector3(nodeScale, nodeScale, nodeScale),
                rotation: Vector4(0, 1, 0, 0),
                position: Vector3(0, 0, 0),
                name: "node_${nodes.length}",
              );
              debugPrint(
                "[AR] Reintento final con nombre estándar: $rootRelative",
              );

              didAddNodeToAnchor = await arObjectManager!.addNode(
                newNodeRoot,
                planeAnchor: newAnchor,
              );
              debugPrint(
                "[AR] addNode (nombre estándar) retornó: $didAddNodeToAnchor",
              );

              if (didAddNodeToAnchor == true) {
                nodes.add(newNodeRoot);
                cachedModelPath = target.path;
                cachedModelRelativePath = rootRelative;
                setState(() {
                  selectedNode = newNodeRoot;
                });
                debugPrint("[AR] ✓ Nodo añadido usando nombre en raíz");
              } else {
                // Reintento 4: ruta absoluta con file://
                final fileUri = 'file://$modelPath';
                var newNodeFileUri = ARNode(
                  type: NodeType.fileSystemAppFolderGLTF2,
                  uri: fileUri,
                  scale: Vector3(nodeScale, nodeScale, nodeScale),
                  rotation: Vector4(0, 1, 0, 0),
                  position: Vector3(0, 0, 0),
                  name: "node_${nodes.length}",
                );
                didAddNodeToAnchor = await arObjectManager!.addNode(
                  newNodeFileUri,
                  planeAnchor: newAnchor,
                );
                debugPrint(
                  "[AR] addNode (file://) retornó: $didAddNodeToAnchor",
                );

                if (didAddNodeToAnchor == true) {
                  nodes.add(newNodeFileUri);
                  setState(() {
                    selectedNode = newNodeFileUri;
                  });
                  debugPrint("[AR] ✓ Nodo añadido con file:// URI");
                } else {
                  _showError("Error", "No se pudo añadir el modelo 3D.");
                  debugPrint("[AR] ✗ Error: addNode falló tras reintentos");
                  // Limpiar anchor si falla la adición del nodo
                  await arAnchorManager!.removeAnchor(newAnchor);
                  anchors.remove(newAnchor);
                }
              }
            } catch (e) {
              _showError("Error", "No se pudo añadir el modelo 3D: $e");
              debugPrint(
                "[AR] ✗ Error: excepción durante reintentos de addNode: $e",
              );
              await arAnchorManager!.removeAnchor(newAnchor);
              anchors.remove(newAnchor);
            }
          }
        }
      }
    } else {
      _showError("Error", "No se pudo crear el ancla");
      debugPrint("[AR] Error al crear anchor");
    }
  }
}
