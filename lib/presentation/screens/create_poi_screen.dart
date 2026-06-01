import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:pilgrims_3d/core/config/theme.dart';
import 'package:pilgrims_3d/core/utils/location_helper.dart';
import 'package:pilgrims_3d/presentation/dialogs/generic_dialogs.dart';
import 'package:pilgrims_3d/presentation/screens/map_picker_screen.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';

class CreatePOIScreen extends StatefulWidget {
  const CreatePOIScreen({super.key});

  @override
  State<CreatePOIScreen> createState() => _CreatePOIScreenState();
}

class _CreatePOIScreenState extends State<CreatePOIScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _chooseImageSource() async {
    final localeProvider = context.read<LocaleProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(localeProvider.translate('take_photo')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(localeProvider.translate('choose_from_gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await determinePosition();
      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lonController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      final localeProvider = context.read<LocaleProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${localeProvider.translate('error_getting_location')}: $e')),
      );
    }
  }

  Future<void> _pickLocationFromMap() async {
    final currentLat = _latController.text.isNotEmpty ? double.parse(_latController.text) : null;
    final currentLon = _lonController.text.isNotEmpty ? double.parse(_lonController.text) : null;

    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLat: currentLat,
          initialLon: currentLon,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latController.text = result['latitude']!.toStringAsFixed(6);
        _lonController.text = result['longitude']!.toStringAsFixed(6);
      });
    }
  }

  Widget _buildImagePreview() {
    if (_imageFile == null) {
      final localeProvider = context.read<LocaleProvider>();
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text(localeProvider.translate('tap_to_upload_photo')),
          ],
        ),
      );
    }
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: _imageFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else {
      return Image.file(File(_imageFile!.path), fit: BoxFit.cover);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        title: Text(localeProvider.translate('new_interest_point')),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Imagen pequeña en la parte superior
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _chooseImageSource,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: _imageFile == null
                        ? LinearGradient(
                            colors: [AppTheme.lightAccent.withOpacity(0.5), AppTheme.lightAccent],
                          )
                        : null,
                    color: _imageFile == null ? null : AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: _imageFile == null
                        ? Border.all(color: AppTheme.primaryGreen, width: 2, style: BorderStyle.solid)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImagePreview(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Título
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: localeProvider.translate('title_label'),
                hintText: localeProvider.translate('title_label'),
                prefixIcon: const Icon(Icons.title_outlined, color: AppTheme.primaryGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.secondaryGreen),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 20),

            // Descripción (mismo tamaño que título)
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: localeProvider.translate('description_label'),
                hintText: localeProvider.translate('description_label'),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: const Icon(Icons.description_outlined, color: AppTheme.primaryGreen),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.secondaryGreen),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // Coordenadas en fila pequeña
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Lat',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.primaryGreen),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.secondaryGreen),
                      ),
                      filled: true,
                      fillColor: AppTheme.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lonController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Lon',
                      prefixIcon: const Icon(Icons.explore_outlined, color: AppTheme.primaryGreen),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.secondaryGreen),
                      ),
                      filled: true,
                      fillColor: AppTheme.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Botones de ubicación bonitos
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _getCurrentLocation,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.my_location, color: Colors.white, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              localeProvider.translate('use_current_location'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _pickLocationFromMap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryGreen, const Color.fromARGB(255, 117, 98, 70)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentBrown.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map_outlined, color: Colors.white, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              localeProvider.translate('select_from_map'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Espacio flexible (rellena todo el espacio disponible)
            const Expanded(child: SizedBox.expand()),

            // Botón de envío
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (_titleController.text.isEmpty ||
                      _latController.text.isEmpty ||
                      _lonController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localeProvider.translate('fill_all_fields_and_image')),
                        backgroundColor: AppTheme.accentBrown,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }
                  creatingPoiDialog(context);
                  try {
                    final name = _titleController.text;
                    final description = _descriptionController.text;
                    final latitude = double.parse(_latController.text);
                    final longitude = double.parse(_lonController.text);

                    if (_imageFile != null) {
                      if (kIsWeb) {

                        // Aquí deberías adaptar create_poi para aceptar bytes si es necesario
                      } else {

                      }
                    }
                    await create_poi(_imageFile, name, description, latitude, longitude);
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    testingAndCreatingPoiDialog(context);
                    if (!mounted) return;
                    // Navigator.of(context).pop();
                  } catch (e) {
                    if (!mounted) return;
                    // Navigator.of(context).pop();
                    errorCreatingPoiDialog(context, e.toString());
                  }
                },
                icon: const Icon(Icons.send, size: 18),
                label: Text(localeProvider.translate('send')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
