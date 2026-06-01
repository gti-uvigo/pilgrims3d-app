import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pilgrims_3d/core/config/theme.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/services/api/api_service.dart' as api;
import 'package:pilgrims_3d/data/models/models.dart';

class MapRouteCreatorScreen extends StatefulWidget {
  const MapRouteCreatorScreen({super.key});

  @override
  State<MapRouteCreatorScreen> createState() => _MapRouteCreatorScreenState();
}

class _MapRouteCreatorScreenState extends State<MapRouteCreatorScreen> {
  final MapController _mapController = MapController();
  List<Poi> _poisInRegion = [];
  final List<dynamic> _selectedItems = [];
  bool _isLoading = false;
  Poi? _selectedPoiForDetail;

  // Filtro de categorías (valores normalizados en minúsculas)
  final List<String> _availableCategories = [
    'alojamiento',
    'naturaleza y paisaje',
    'patrimonio e historia',
    'religión y espiritualidad',
    'arte, cultura y ocio',
    'gastronomía y compras',
    'deportes y actividades',
    'salud y bienestar',
    'agroturismo y entorno rural',
    'accesibilidad e inclusión',
    'servicios y transportes',
  ];
  final Set<String> _selectedCategories = {}; // keys en minúsculas

  // Centro inicial del mapa (Santiago de Compostela)
  final LatLng _center = const LatLng(42.8782, -8.5448);
  double _currentZoom = 13.0;

  // Variables para debounce de carga de POIs
  DateTime? _lastLoadTime;
  LatLng? _lastLoadCenter;
  static const _loadDebounceSeconds = 2;
  static const _minDistanceToReload = 0.05; // ~5km en grados

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPoisInCurrentRegion();
    });
  }

  void _onMapMoved(LatLng? newCenter) {
    if (newCenter == null) return;

    // Verificar si ha pasado suficiente tiempo desde la última carga
    final now = DateTime.now();
    if (_lastLoadTime != null) {
      final timeDiff = now.difference(_lastLoadTime!);
      if (timeDiff.inSeconds < _loadDebounceSeconds) {
        return; // Muy pronto para recargar
      }
    }

    // Verificar si nos hemos movido lo suficiente
    if (_lastLoadCenter != null) {
      final latDiff = (newCenter.latitude - _lastLoadCenter!.latitude).abs();
      final lonDiff = (newCenter.longitude - _lastLoadCenter!.longitude).abs();
      if (latDiff < _minDistanceToReload && lonDiff < _minDistanceToReload) {
        return; // No nos hemos movido lo suficiente
      }
    }

    // Cargar POIs
    _loadPoisInCurrentRegion();
    _lastLoadTime = now;
    _lastLoadCenter = newCenter;
  }

  Future<void> _loadPoisInCurrentRegion() async {
    setState(() {
      _isLoading = true;
    });

    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    try {
      final bounds = _mapController.camera.visibleBounds;
      final languageId = localeProvider.currentLangId;

      print('📍 Cargando POIs en región...');
      print(
        '   Bounds: N:${bounds.north}, S:${bounds.south}, E:${bounds.east}, W:${bounds.west}',
      );
      print('   Language: $languageId');

      // Obtener POIs en la región visible usando la API
      final pois = await api.getPoisInRegion(
        north: bounds.north,
        south: bounds.south,
        east: bounds.east,
        west: bounds.west,
        languageId: languageId,
      );

      print('✅ POIs recibidos: ${pois.length}');

      if (mounted) {
        setState(() {
          _poisInRegion =
              pois.map((json) {
                final poi = Poi.fromJson(json);
                print(
                  '   📍 POI: ${poi.title} (ID: "${poi.poiId}") - category: ${poi.iconCategory}',
                );
                return poi;
              }).toList();
          _isLoading = false;
        });

        print('✅ POIs parseados y mostrados: ${_poisInRegion.length}');
      }
    } catch (e) {
      print('❌ Error cargando POIs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localeProvider.translate('error_loading_pois')}: $e',
            ),
          ),
        );
      }
    }
  }

  void _togglePoiSelection(Poi poi) {
    print('🔄 Toggle POI: ${poi.title} (ID: ${poi.poiId})');
    setState(() {
      final index = _selectedItems.indexWhere(
        (item) => item is Poi && item.poiId == poi.poiId,
      );
      print('   Index encontrado: $index');
      if (index >= 0) {
        print('   ✅ Removiendo POI de la selección');
        _selectedItems.removeAt(index);
      } else {
        print('   ✅ Añadiendo POI a la selección');
        _selectedItems.add(poi);
      }
      print(
        '   Total seleccionados: ${_selectedItems.whereType<Poi>().length}',
      );
    });
  }

  bool _isPoiSelected(Poi poi) {
    return _selectedItems.any((item) => item is Poi && item.poiId == poi.poiId);
  }

  int? _getPoiOrder(Poi poi) {
    int poiCount = 0;
    for (var item in _selectedItems) {
      if (item is Poi) {
        poiCount++;
        if (item.poiId == poi.poiId) {
          return poiCount;
        }
      }
    }
    return null;
  }

  IconData _iconForCategory(String? category) {
    if (category == null) return Icons.place;
    final c = category.toLowerCase();
    if (c.contains('aloj')) return Icons.hotel;
    if (c.contains('natur') || c.contains('paisaj')) return Icons.park;
    if (c.contains('patr') || c.contains('hist')) return Icons.museum;
    if (c.contains('relig') || c.contains('espirit'))
      return Icons.account_balance;
    if (c.contains('arte') || c.contains('cultur') || c.contains('ocio'))
      return Icons.palette;
    if (c.contains('gastr') || c.contains('compr')) return Icons.restaurant;
    if (c.contains('deport') || c.contains('activid')) return Icons.sports;
    if (c.contains('salud') || c.contains('bienestar'))
      return Icons.local_hospital;
    if (c.contains('agrot') || c.contains('rural')) return Icons.agriculture;
    if (c.contains('acces') || c.contains('inclus'))
      return Icons.accessibility_new;
    if (c.contains('servic') || c.contains('transport'))
      return Icons.directions_bus;
    return Icons.place;
  }

  String _normalizeCategory(String? c) {
    if (c == null) return '';
    return c.toLowerCase().trim();
  }

  void _showCategoryFilterSheet() {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final temp = Set<String>.from(_selectedCategories);
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localeProvider.translate('filter_by_category'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _availableCategories.map((display) {
                            final key = _normalizeCategory(display);
                            final selected = temp.contains(key);
                            return FilterChip(
                              label: Text(
                                display,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: selected,
                              onSelected:
                                  (v) => modalSetState(
                                    () =>
                                        selected
                                            ? temp.remove(key)
                                            : temp.add(key),
                                  ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            modalSetState(() => temp.clear());
                          },
                          child: Text(localeProvider.translate('clear_filter')),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _selectedCategories
                                  ..clear()
                                  ..addAll(temp);
                              });
                            }
                            Navigator.of(context).pop();
                          },
                          child: Text(localeProvider.translate('apply')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _reorderSelectedItem(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _selectedItems.removeAt(oldIndex);
      _selectedItems.insert(newIndex, item);
    });
  }

  void _addStageBreak(int afterIndex) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    setState(() {
      _selectedItems.insert(
        afterIndex + 1,
        StageBreak(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: localeProvider.translate('stage_break'),
        ),
      );
    });
    // Si estamos en el modal, forzamos la reconstrucción
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      _showSelectedItemsList();
    }
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
    // Si borramos el último item y estamos en el modal, actualizamos
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      _showSelectedItemsList();
    }
  }

  int _getSelectedPoisCount() {
    return _selectedItems.whereType<Poi>().length;
  }

  // --- UI COMPONENTS ---

  void _showSaveRouteDialog() {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final nameController = TextEditingController();
    final shortDescriptionController = TextEditingController();
    final longDescriptionController = TextEditingController();
    final customRouteTypeController = TextEditingController();
    final customSubtypeController = TextEditingController();
    Uint8List? imageBytes;
    String? selectedRouteTypeId;
    String? selectedSubtype = 'default'; // Valor por defecto
    bool useCustomRouteType = true; // Usar custom por defecto
    bool useCustomSubtype = false;
    final ImagePicker picker = ImagePicker();
    List<RouteType> routeTypes = [];

    // Establecer "private" como valor por defecto
    customRouteTypeController.text = 'private';

    // Cargar tipos de ruta
    api
        .getRouteTypes()
        .then((types) {
          routeTypes = types.map((json) => RouteType.fromJson(json)).toList();
        })
        .catchError((e) {
          print('Error cargando tipos de ruta: $e');
        });

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              final selectedRouteType = routeTypes.firstWhere(
                (rt) => rt.id == selectedRouteTypeId,
                orElse: () => RouteType(id: '', name: '', subtypes: []),
              );

              if (selectedSubtype == null &&
                  selectedRouteType.subtypes.isNotEmpty &&
                  !useCustomSubtype) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      selectedSubtype = selectedRouteType.subtypes.first;
                    });
                  }
                });
              }

              // Ajuste móvil: Usamos MediaQuery para el ancho
              final double dialogWidth =
                  MediaQuery.of(context).size.width * 0.9;

              return AlertDialog(
                title: Text(localeProvider.translate('save_route')),
                contentPadding: const EdgeInsets.all(16),
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                content: SizedBox(
                  width: dialogWidth,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: localeProvider.translate(
                              'route_name_label',
                            ),
                            hintText: 'Ej: Camino Santiago - Etapa 1',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Tipo de ruta
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (useCustomRouteType)
                              TextField(
                                controller: customRouteTypeController,
                                decoration: InputDecoration(
                                  labelText: localeProvider.translate(
                                    'route_type_custom_label',
                                  ),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                initialValue:
                                    routeTypes.any(
                                          (rt) => rt.id == selectedRouteTypeId,
                                        )
                                        ? selectedRouteTypeId
                                        : null,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: localeProvider.translate(
                                    'route_type_label',
                                  ),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items:
                                    routeTypes.map((rt) {
                                      return DropdownMenuItem(
                                        value: rt.id,
                                        child: Text(
                                          rt.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedRouteTypeId = value;
                                    final newRouteType = routeTypes.firstWhere(
                                      (rt) => rt.id == value,
                                      orElse:
                                          () => RouteType(
                                            id: '',
                                            name: '',
                                            subtypes: [],
                                          ),
                                    );
                                    selectedSubtype =
                                        newRouteType.subtypes.isNotEmpty
                                            ? newRouteType.subtypes.first
                                            : null;
                                  });
                                },
                              ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: Icon(
                                  useCustomRouteType ? Icons.list : Icons.edit,
                                  size: 16,
                                ),
                                label: Text(
                                  useCustomRouteType
                                      ? localeProvider.translate(
                                        'select_from_list',
                                      )
                                      : localeProvider.translate('customize'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () {
                                  setState(() {
                                    useCustomRouteType = !useCustomRouteType;
                                    if (!useCustomRouteType)
                                      customRouteTypeController.clear();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        // Subtipo
                        if (!useCustomRouteType &&
                            selectedRouteType.subtypes.isNotEmpty)
                          Column(
                            children: [
                              if (useCustomSubtype)
                                TextField(
                                  controller: customSubtypeController,
                                  decoration: InputDecoration(
                                    labelText: localeProvider.translate(
                                      'subtype_custom_label',
                                    ),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                )
                              else
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      selectedRouteType.subtypes.contains(
                                            selectedSubtype,
                                          )
                                          ? selectedSubtype
                                          : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: localeProvider.translate(
                                      'subtype_label',
                                    ),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items:
                                      selectedRouteType.subtypes.map((st) {
                                        return DropdownMenuItem(
                                          value: st,
                                          child: Text(
                                            st,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                  onChanged:
                                      (value) => setState(
                                        () => selectedSubtype = value,
                                      ),
                                ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: Icon(
                                    useCustomSubtype ? Icons.list : Icons.edit,
                                    size: 16,
                                  ),
                                  label: Text(
                                    useCustomSubtype
                                        ? localeProvider.translate(
                                          'select_from_list',
                                        )
                                        : localeProvider.translate('customize'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      useCustomSubtype = !useCustomSubtype;
                                      if (!useCustomSubtype)
                                        customSubtypeController.clear();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 8),
                        TextField(
                          controller: shortDescriptionController,
                          decoration: InputDecoration(
                            labelText: localeProvider.translate(
                              'short_description',
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: longDescriptionController,
                          decoration: InputDecoration(
                            labelText: localeProvider.translate(
                              'long_description',
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Imagen
                        GestureDetector(
                          onTap: () async {
                            try {
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1920,
                                maxHeight: 1080,
                                imageQuality: 85,
                              );
                              if (image != null) {
                                final bytes = await image.readAsBytes();
                                setState(() {
                                  imageBytes = bytes;
                                });
                              }
                            } catch (e) {
                              // Handle error
                            }
                          },
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child:
                                imageBytes != null
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        imageBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                    : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.add_a_photo,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          localeProvider.translate(
                                            'tap_to_add_image',
                                          ),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                        if (imageBytes != null)
                          TextButton.icon(
                            onPressed:
                                () => setState(() {
                                  imageBytes = null;
                                }),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: Text(
                              localeProvider.translate('remove_image'),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(localeProvider.translate('cancel')),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Validación básica
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localeProvider.translate('route_name_required'),
                            ),
                          ),
                        );
                        return;
                      }

                      if (shortDescriptionController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localeProvider.translate(
                                'short_description_required',
                              ),
                            ),
                          ),
                        );
                        return;
                      }

                      if (longDescriptionController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localeProvider.translate(
                                'long_description_required',
                              ),
                            ),
                          ),
                        );
                        return;
                      }

                      final poiIds =
                          _selectedItems
                              .whereType<Poi>()
                              .map((p) => p.poiId)
                              .toList();
                      if (poiIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localeProvider.translate(
                                'select_at_least_one_poi',
                              ),
                            ),
                          ),
                        );
                        return;
                      }

                      if (poiIds.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localeProvider.translate(
                                'select_at_least_two_pois',
                              ),
                            ),
                          ),
                        );
                        return;
                      }

                      // Determinar tipo y subtipo
                      final routeType =
                          useCustomRouteType
                              ? customRouteTypeController.text
                              : (routeTypes
                                  .firstWhere(
                                    (rt) => rt.id == selectedRouteTypeId,
                                    orElse:
                                        () => RouteType(
                                          id: '',
                                          name: '',
                                          subtypes: [],
                                        ),
                                  )
                                  .name);

                      final subtype =
                          useCustomSubtype
                              ? customSubtypeController.text
                              : selectedSubtype;

                      if (routeType.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localeProvider.translate('route_type_required'),
                            ),
                          ),
                        );
                        return;
                      }

                      // Preparar datos de la ruta
                      try {
                        final localeProvider = Provider.of<LocaleProvider>(
                          context,
                          listen: false,
                        );
                        final languageId = localeProvider.currentLangId;

                        // Convertir imagen a base64 para enviar al backend
                        final imageBase64 =
                            imageBytes != null
                                ? base64Encode(imageBytes!)
                                : null;

                        // Obtener índices de los stage breaks
                        final stageBreaks = <int>[];
                        for (int i = 0; i < _selectedItems.length; i++) {
                          if (_selectedItems[i] is StageBreak) {
                            stageBreaks.add(i);
                          }
                        }

                        // Llamar a la API para crear la ruta
                        await api.createRoute(
                          name: nameController.text,
                          shortDescription: shortDescriptionController.text,
                          longDescription: longDescriptionController.text,
                          routeType: routeType,
                          subtype: subtype,
                          poiIds: poiIds,
                          stageBreaks:
                              stageBreaks.isNotEmpty ? stageBreaks : null,
                          languageId: languageId,
                          imageBase64: imageBase64,
                        );

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                localeProvider.translate(
                                  'route_saved_successfully',
                                ),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() => _selectedItems.clear());
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${localeProvider.translate('error_saving_route')}: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(localeProvider.translate('save')),
                  ),
                ],
              );
            },
          ),
    );
  }

  // Bottom Sheet para ver y reordenar la lista
  void _showSelectedItemsList() {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.25,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${localeProvider.translate('your_route')} (${_getSelectedPoisCount()} POIs)',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedItems.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showSaveRouteDialog();
                              },
                              icon: const Icon(Icons.save, size: 18),
                              label: Text(localeProvider.translate('save')),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child:
                          _selectedItems.isEmpty
                              ? Center(
                                child: Text(
                                  localeProvider.translate(
                                    'select_points_on_map',
                                  ),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              )
                              : ReorderableListView.builder(
                                itemCount: _selectedItems.length,
                                onReorder: _reorderSelectedItem,
                                itemBuilder: (context, index) {
                                  final item = _selectedItems[index];

                                  if (item is StageBreak) {
                                    return Card(
                                      key: ValueKey(item.id),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      color: Colors.orange.shade50,
                                      elevation: 1,
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(
                                          Icons.flag,
                                          color: Colors.orange.shade700,
                                        ),
                                        title: Text(
                                          item.name,
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _removeItem(index),
                                        ),
                                      ),
                                    );
                                  }

                                  final poi = item as Poi;
                                  final poiOrder = _getPoiOrder(poi);

                                  return Card(
                                    key: ValueKey(poi.poiId),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    elevation: 2,
                                    child: ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppTheme.primaryGreen,
                                        child: Text(
                                          '$poiOrder',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        poi.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed:
                                            () => _togglePoiSelection(poi),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                    // Botón cambio de etapa al final de la lista
                    if (_selectedItems.isNotEmpty && _selectedItems.last is Poi)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                () => _addStageBreak(_selectedItems.length - 1),
                            icon: const Icon(Icons.flag),
                            label: Text(
                              localeProvider.translate('add_stage_end'),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade700,
                              side: BorderSide(color: Colors.orange.shade700),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos Stack para capas en lugar de Row
      body: Stack(
        children: [
          // 1. CAPA DEL MAPA (Fondo)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _currentZoom,
              maxZoom: 18.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _currentZoom = position.zoom;
                  _onMapMoved(position.center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rurallure.pilgrims',
              ),
              MarkerLayer(
                markers:
                    _poisInRegion
                        .where((poi) {
                          final poiCat = _normalizeCategory(poi.iconCategory);
                          if (_selectedCategories.isEmpty) return true;
                          return _selectedCategories.any(
                            (sel) =>
                                poiCat.contains(sel) || sel.contains(poiCat),
                          );
                        })
                        .map((poi) {
                          final isSelected = _isPoiSelected(poi);
                          final order = _getPoiOrder(poi);

                          // Marcadores un poco más grandes para dedos
                          return Marker(
                            point: LatLng(poi.latitude, poi.longitude),
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPoiForDetail = poi;
                                });
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (isSelected ||
                                      _selectedPoiForDetail?.poiId == poi.poiId)
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: (isSelected
                                                ? AppTheme.primaryGreen
                                                : Colors.blue)
                                            .withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? AppTheme.primaryGreen
                                              : AppTheme.darkGray,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child:
                                        order != null
                                            ? Center(
                                              child: Text(
                                                '$order',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                            : Icon(
                                              _iconForCategory(
                                                poi.iconCategory,
                                              ),
                                              color: Colors.white,
                                            ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(),
              ),
            ],
          ),

          // 2. CAPA SUPERIOR (Botones y Tarjetas)
          SafeArea(
            child: Column(
              children: [
                // Cabecera transparente con botones
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botón de atrás (si es necesario) o título pequeño
                      Row(
                        children: [
                          if (_isLoading)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox.shrink(),
                    ],
                  ),
                ),

                const Spacer(), // Empuja todo lo demás hacia abajo
                // Tarjeta de Detalle del POI (Si hay uno seleccionado para ver)
                if (_selectedPoiForDetail != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              // Imagen header
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: Container(
                                  height: 120,
                                  width: double.infinity,
                                  color: Colors.grey[200],
                                  child:
                                      _selectedPoiForDetail!.imageId != null
                                          ? FutureBuilder<Image>(
                                            future: api.fetchImage(
                                              _selectedPoiForDetail!.imageId!,
                                            ),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return snapshot.data!;
                                              }
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            },
                                          )
                                          : const Icon(
                                            Icons.image,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                ),
                              ),
                              // Botón cerrar
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  radius: 14,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    onPressed:
                                        () => setState(
                                          () => _selectedPoiForDetail = null,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedPoiForDetail!.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedPoiForDetail!.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _togglePoiSelection(
                                        _selectedPoiForDetail!,
                                      );
                                      // Opcional: Cerrar detalle después de añadir
                                      // setState(() => _selectedPoiForDetail = null);
                                    },
                                    icon: Icon(
                                      _isPoiSelected(_selectedPoiForDetail!)
                                          ? Icons.remove
                                          : Icons.add,
                                    ),
                                    label: Builder(
                                      builder: (ctx) {
                                        final lp = Provider.of<LocaleProvider>(
                                          ctx,
                                          listen: false,
                                        );
                                        return Text(
                                          _isPoiSelected(_selectedPoiForDetail!)
                                              ? lp.translate('remove')
                                              : lp.translate('add_to_route'),
                                        );
                                      },
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          _isPoiSelected(_selectedPoiForDetail!)
                                              ? Colors.red.shade100
                                              : AppTheme.primaryGreen,
                                      foregroundColor:
                                          _isPoiSelected(_selectedPoiForDetail!)
                                              ? Colors.red
                                              : Colors.white,
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Botón flotante grande para ver la lista (Si no hay tarjeta de detalle)
                // Si estás dentro de un Stack, usa Positioned.
                // Si estás dentro de un Column, asegúrate de tener un Spacer() antes.
                if (_selectedPoiForDetail == null)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: 24 + MediaQuery.of(context).padding.bottom,
                      left: 16,
                      right: 16,
                    ),
                    child: Align(
                      alignment:
                          Alignment.bottomCenter, // <--- ESTO ES LO IMPORTANTE
                      child: FloatingActionButton.extended(
                        heroTag: 'list_btn',
                        onPressed: _showSelectedItemsList,
                        backgroundColor: AppTheme.darkGray,
                        elevation: 4, // Sombra suave
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        icon: const Icon(
                          Icons.map,
                          color: Colors.white,
                        ), // Icono más representativo
                        label: Builder(
                          builder: (ctx) {
                            final lp = Provider.of<LocaleProvider>(
                              ctx,
                              listen: false,
                            );
                            return Text(
                              '${lp.translate('view_route')} (${_getSelectedPoisCount()})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                // (Filter button moved out of Column to avoid ParentDataWidget errors)
              ],
            ),
          ),
          // Botón de filtro de categorías - abajo a la derecha (posicionado sobre el Stack)
          Positioned(
            right: 16,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  heroTag: 'filter_btn',
                  onPressed: _showCategoryFilterSheet,
                  backgroundColor: AppTheme.primaryGreen,
                  child: const Icon(Icons.filter_list, color: Colors.white),
                ),
                if (_selectedCategories.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          '${_selectedCategories.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
