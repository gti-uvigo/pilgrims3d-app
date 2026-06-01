import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';

class LanguageDropdown extends StatefulWidget {
  const LanguageDropdown({super.key});

  @override
  _LanguageDropdownState createState() => _LanguageDropdownState();
}

class _LanguageDropdownState extends State<LanguageDropdown> {
  // Usamos un Future para controlar los estados de carga/error/éxito de forma declarativa.
  Future<List<dynamic>>? _languagesFuture;
  String? _selectedLanguageId;


  @override
  void initState() {
    super.initState();
    _languagesFuture = getLanguages();
  }

  // Se llama cuando las dependencias del widget cambian, ideal para inicializar
  // el estado que depende del 'context', como el Provider.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializamos el idioma seleccionado desde el Provider.
    // Esto es más seguro que hacerlo en initState.
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    _selectedLanguageId ??= localeProvider.currentLangId;
  }

  // Función para reintentar la carga en caso de error.
  void _retryFetch() {
    setState(() {
      _languagesFuture = getLanguages();
    });
  }
  
  // Función para manejar el cambio de idioma.
  void _onLanguageChanged(String? newValue, List<dynamic> languages) {
    if (newValue == null || newValue == _selectedLanguageId) return;

    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    setState(() {
      _selectedLanguageId = newValue;
    });

  localeProvider.setLocaleById(newValue);

    // Muestra una confirmación con Overlay.
    final selectedLang = languages.firstWhere((lang) => lang['id'] == newValue);
    final message = localeProvider.translate(
      'language_changed',
      args: {'lang': selectedLang['name']},
    );
    
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    // FutureBuilder maneja automáticamente los estados de carga, error y datos.
    return FutureBuilder<List<dynamic>>(
      future: _languagesFuture,
      builder: (context, snapshot) {
        // --- Estado de Carga ---
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3.0),
            ),
          );
        }

        // --- Estado de Error ---
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Text(
                localeProvider.translate('error_loading'), // 'error_loading'
                style: GoogleFonts.poppins(color: theme.colorScheme.error),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
                onPressed: _retryFetch,
              ),
            ],
          );
        }

        // --- Estado con Datos ---
        final languages = snapshot.data!;
        final availableLangIds = languages.map((lang) => lang['id'].toString()).toList();
        
        // Si el idioma seleccionado no está en la lista, se pone en null para mostrar el hint.
        final finalSelectedId = availableLangIds.contains(_selectedLanguageId)
            ? _selectedLanguageId
            : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: theme.dividerColor, 
              width: 1.5
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: finalSelectedId,
              isExpanded: true,
              hint: Text(
              
                  localeProvider.translate('select'),
                style: GoogleFonts.poppins(color: theme.hintColor),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded, 
                color: theme.hintColor
              ),
              dropdownColor: theme.cardColor,
              borderRadius: BorderRadius.circular(12.0),
              items: languages.map((lang) {
                return DropdownMenuItem<String>(
                  value: lang['id'],
                  child: _buildLanguageItem(lang['iso_code'], lang['name']),
                );
              }).toList(),
              onChanged: (newValue) => _onLanguageChanged(newValue, languages),
              // Esto construye el widget que se ve cuando el menú está cerrado.
              selectedItemBuilder: (context) {
                return languages.map<Widget>((lang) {
                  return _buildLanguageItem(lang['iso_code'], lang['name'], isSelectedItem: true, isDisabled: false);
                }).toList();
              },
            ),
          ),
        );
      },
    );
  }

  // Widget para mostrar un item de idioma (con bandera y nombre).
  Widget _buildLanguageItem(String langIso, String langName, {bool isSelectedItem = false, bool isDisabled = false}) {
    return Row(
      children: [
        Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: _getFlagWidget(langIso),
        ),
        const SizedBox(width: 12),
        Text(
          langName,
          style: GoogleFonts.poppins(
            fontWeight: isSelectedItem ? FontWeight.w600 : FontWeight.w500,
            color: isDisabled 
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
              : Theme.of(context).colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Widget para mostrar la bandera según el idioma
  Widget _getFlagWidget(String langCode) {
    final String flagPath = 'images/flags/${langCode.toLowerCase()}.svg';
    
    return SizedBox(
      width: 28,
      height: 20,
      child: SvgPicture.asset(
        flagPath,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.flag, size: 16),
        ),
      ),
    );
  }
}