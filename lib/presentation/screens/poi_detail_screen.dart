import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:pilgrims_3d/core/config/env.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/presentation/widgets/highlighted_text.dart';
import 'package:pilgrims_3d/presentation/widgets/offline_cached_image.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'package:pilgrims_3d/services/tts/tts_service.dart';

class PoiDetailScreen extends StatefulWidget {
  final String poiId;

  const PoiDetailScreen({super.key, required this.poiId});

  @override
  State<PoiDetailScreen> createState() => _PoiDetailScreenState();
}

class _PoiDetailScreenState extends State<PoiDetailScreen> {
  Future<Map<String, dynamic>?>? _poiFuture;
  String? _lastLangId;
  late TTSService _ttsService;

  void _onTtsStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _ttsService = TTSService();
    _ttsService.addOnStartListener(_onTtsStateChange);
    _ttsService.addOnCompleteListener(_onTtsStateChange);
    _ttsService.addOnStopListener(_onTtsStateChange);
  }

  @override
  void dispose() {
    _ttsService.removeOnStartListener(_onTtsStateChange);
    _ttsService.removeOnCompleteListener(_onTtsStateChange);
    _ttsService.removeOnStopListener(_onTtsStateChange);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final langId = context.read<LocaleProvider>().currentLangId;
    if (_lastLangId != langId || _poiFuture == null) {
      _lastLangId = langId;
      _poiFuture = fetchPoiDetail(widget.poiId, langId);
    }
  }

  String _getLocalizedText(dynamic data, String key, String defaultText) {
    if (data == null || data[key] == null) return defaultText;
    if (data[key] is String) return data[key];
    if (data[key] is List) {
      final list = data[key] as List;
      final match = list.firstWhere(
        (item) => item['language_id'] == _lastLangId,
        orElse: () => null,
      );
      if (match != null) return match['text']?.toString() ?? defaultText;
      if (list.isNotEmpty) return list.first['text']?.toString() ?? defaultText;
    }
    return defaultText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // CAMBIO: Navegación a Home como antes
        leading: IconButton(
          icon: Icon(
            Icons.home_outlined,
            size: 32,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => context.go('/'),
        ),
        // CAMBIO: Eliminado botón de compartir
      ),
      extendBodyBehindAppBar: true,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _poiFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No se pudo cargar el punto de interés',
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
            );
          }

          final poi = snapshot.data!;

          final title = _getLocalizedText(poi, 'titles', 'Punto de interés');
          final description = _getLocalizedText(
            poi,
            'descriptions',
            'Sin descripción disponible.',
          );
          final imageId = poi['image_id']?.toString();
          final imageUrl = imageId != null ? '$baseUrl/images/$imageId' : null;
          final types =
              (poi['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
          final address = poi['address']?.toString();
          final zenodoUrl = poi['zenodo_url']?.toString();
          final website = poi['website']?.toString();
          final latitude = (poi['latitude'] as num?)?.toDouble();
          final longitude = (poi['longitude'] as num?)?.toDouble();
          final ratingData = poi['rating'] as Map<String, dynamic>?;
          final score = ratingData?['score']?.toDouble();
          final duration = poi['minutes_duration']?.toString();

          return LayoutBuilder(
            builder: (context, constraints) {
              bool isWideScreen = constraints.maxWidth > 900;

              Widget imageWidget = _buildImage(
                imageUrl,
                imageId,
                isWideScreen,
                theme,
              );

              Widget contentWidget = _buildContent(
                theme: theme,
                title: title,
                score: score,
                types: types,
                description: description,
                address: address,
                duration: duration,
                latitude: latitude,
                longitude: longitude,
                zenodoUrl: zenodoUrl,
                website: website,
                isWideScreen: isWideScreen,
              );

              if (isWideScreen) {
                // --- DISEÑO PC AJUSTADO (Más grande y lleno) ---
                return Center(
                  child: ConstrainedBox(
                    // CAMBIO: Aumentado de 1200 a 1600 para llenar más pantalla
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: Padding(
                      padding: EdgeInsets.only(
                        top:
                            MediaQuery.of(context).padding.top +
                            80, // Más margen arriba
                        left: 40,
                        right: 40,
                        bottom: 40,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6, // La imagen ocupa un poco más (60%)
                            child: imageWidget,
                          ),
                          const SizedBox(width: 50), // Separación más grande
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: contentWidget,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                // --- DISEÑO MÓVIL ---
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: MediaQuery.of(context).padding.top + 60),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 10,
                        ),
                        child: Column(
                          children: [
                            imageWidget,
                            const SizedBox(height: 30),
                            contentWidget,
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildImage(
    String? imageUrl,
    String? imageId,
    bool isWideScreen,
    ThemeData theme,
  ) {
    // CAMBIO: Proporciones ajustadas para que la imagen sea más imponente
    double aspectRatio = isWideScreen ? 16 / 10 : 16 / 9;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32), // Bordes más redondeados
        child: Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child:
              imageUrl != null && imageId != null
                  ? OfflineCachedImage(
                    imageUrl: imageUrl,
                    imageId: imageId,
                    fit: BoxFit.cover,
                    placeholder:
                        (_, __) => Center(
                          child: Icon(
                            Icons.image,
                            size: 50,
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.3),
                          ),
                        ),
                    errorWidget:
                        (_, __, ___) => Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 50,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                  )
                  : Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 60,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required ThemeData theme,
    required String title,
    double? score,
    required List<String> types,
    required String description,
    String? address,
    String? duration,
    double? latitude,
    double? longitude,
    String? zenodoUrl,
    String? website,
    required bool isWideScreen,
  }) {
    // CAMBIO: Estilos de texto aumentados manualmente para dar sensación de "grande"
    final headlineStyle = theme.textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w900,
      fontSize: isWideScreen ? 48 : 32, // Título gigante en PC
      height: 1.1,
    );

    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: isWideScreen ? 20 : 16, // Texto de lectura más grande
      height: 1.6,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título con botón de audio
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(title, style: headlineStyle)),
            const SizedBox(width: 16),
            _AudioPlayButton(
              ttsService: _ttsService,
              text: description,
              langId: _lastLangId ?? 'es',
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Rating y Categorías
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 10,
          children: [
            if (score != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Colors.amber.shade800,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      score.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),

            ...types.map(
              (t) => Chip(
                padding: const EdgeInsets.all(8),
                label: Text(t, style: const TextStyle(fontSize: 16)),
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.5),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Botones de Acción (Más grandes)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (latitude != null && longitude != null)
                _ActionButton(
                  icon: Icons.map_outlined,
                  label: 'Abrir Mapa',
                  onTap: () => _openMaps(latitude, longitude),
                  theme: theme,
                  isBig: true,
                ),
              if (zenodoUrl != null) ...[
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.view_in_ar_outlined,
                  label: 'Modelo 3D',
                  isPrimary: true,
                  onTap: () => _openUrl(zenodoUrl),
                  theme: theme,
                  isBig: true,
                ),
              ],
              if (website != null) ...[
                const SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.language_outlined,
                  label: 'Sitio Web',
                  onTap: () => _openUrl(website),
                  theme: theme,
                  isBig: true,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 40),
        Divider(
          thickness: 1.5,
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
        const SizedBox(height: 30),

        // Descripción
        Text(
          "Información",
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 16),
        HighlightedText(
          text: description,
          style: bodyStyle ?? const TextStyle(),
          ttsService: _ttsService,
        ),

        const SizedBox(height: 40),

        // Fichas (Más grandes)
        if (address != null)
          _InfoTile(
            icon: Icons.location_on_outlined,
            label: address,
            onTap:
                (latitude != null && longitude != null)
                    ? () => _openMaps(latitude, longitude)
                    : null,
            theme: theme,
            isBig: true,
          ),
        if (duration != null) ...[
          const SizedBox(height: 20),
          _InfoTile(
            icon: Icons.access_time_rounded,
            label: "$duration minutos estimados",
            theme: theme,
            isBig: true,
          ),
        ],

        if (!isWideScreen) const SizedBox(height: 50),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMaps(double lat, double lng) async {
    final nativeUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng($lat,$lng)");
    final webUri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );

    if (await canLaunchUrl(nativeUri) && !kIsWeb) {
      await launchUrl(nativeUri);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final ThemeData theme;
  final bool isBig;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    required this.theme,
    this.isBig = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final bgColor =
        isPrimary ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final fgColor = isPrimary ? colorScheme.onPrimary : colorScheme.primary;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          // CAMBIO: Padding aumentado
          padding: EdgeInsets.symmetric(
            horizontal: isBig ? 24 : 16,
            vertical: isBig ? 18 : 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fgColor, size: isBig ? 28 : 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  // Fuente más grande
                  color: fgColor,
                  fontWeight: FontWeight.bold,
                  fontSize: isBig ? 18 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final ThemeData theme;
  final bool isBig;

  const _InfoTile({
    required this.icon,
    required this.label,
    this.onTap,
    required this.theme,
    this.isBig = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isBig ? 16.0 : 12.0),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isBig ? 16 : 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.6,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: isBig ? 32 : 22,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: isBig ? 18 : 16, // Texto más grande
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.outline,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioPlayButton extends StatefulWidget {
  final TTSService ttsService;
  final String text;
  final String langId;

  const _AudioPlayButton({
    required this.ttsService,
    required this.text,
    required this.langId,
  });

  @override
  State<_AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<_AudioPlayButton> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        if (widget.ttsService.isPlaying) {
          await widget.ttsService.stop();
        } else {
          try {
            await widget.ttsService.initialize();
            final langCode = widget.ttsService.getLanguageCode(widget.langId);
            await widget.ttsService.speak(widget.text, languageCode: langCode);
          } catch (e) {
            debugPrint('Error playing audio: $e');
          }
        }
      },
      icon: Icon(
        widget.ttsService.isPlaying
            ? Icons.stop_rounded
            : Icons.volume_up_rounded,
        size: 28,
        color: Colors.green,
      ),
      tooltip: widget.ttsService.isPlaying ? 'Detener' : 'Escuchar descripción',
    );
  }
}
