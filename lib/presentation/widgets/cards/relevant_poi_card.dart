import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pilgrims_3d/core/config/env.dart';
import 'package:pilgrims_3d/core/config/routes.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'package:pilgrims_3d/services/tts/tts_service.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/presentation/widgets/offline_cached_image.dart';
import 'package:pilgrims_3d/presentation/widgets/highlighted_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card de una sola cara para la pantalla de Elementos Culturales 3D.
/// Muestra imagen, rating, selector de valoración y botones de acción.
/// Tocar la card (fuera de los botones) navega al visor de modelo 3D.
class RelevantPoiCard extends StatefulWidget {
  final Map<String, dynamic> poi;
  final LocaleProvider localeProvider;
  final ThemeData theme;
  final double cardHeight;

  const RelevantPoiCard({
    super.key,
    required this.poi,
    required this.localeProvider,
    required this.theme,
    required this.cardHeight,
  });

  @override
  State<RelevantPoiCard> createState() => _RelevantPoiCardState();
}

class _RelevantPoiCardState extends State<RelevantPoiCard> {
  late Map<String, dynamic> _poi;

  @override
  void initState() {
    super.initState();
    _poi = Map<String, dynamic>.from(widget.poi);
  }

  @override
  void didUpdateWidget(covariant RelevantPoiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.poi, widget.poi)) {
      _poi = Map<String, dynamic>.from(widget.poi);
    }
  }

  void _updatePoi(Map<String, dynamic> updatedPoi) {
    setState(() => _poi = Map<String, dynamic>.from(updatedPoi));
  }

  void _navigate3D(BuildContext context) {
    final url = _poi['zenodo_url'] as String? ?? '';
    if (url.isEmpty) return;
    HapticService().medium();
    context.push('/model-viewer?modelUrl=${Uri.encodeComponent(url)}');
  }

  void _openInfo(BuildContext context) {
    final String? poiId = _poi['id']?.toString();
    final String langCode = widget.localeProvider.currentLangId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PoiInfoSheet(
        poi: _poi,
        poiId: poiId,
        langCode: langCode,
        theme: widget.theme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poi = _poi;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobilityFriendly = poi['is_mobility_friendly'] ?? false;
    final double rating = (poi['rating']?['score']?.toDouble()) ?? 0.0;
    final int ratingsCount = (poi['rating']?['user_ratings_total']) ?? 0;
    final double userRating = poi['user_rating']?.toDouble() ?? 0.0;
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final double btnSize = (screenWidth * 0.105).clamp(40.0, 52.0);
    final double iconSize = btnSize * 0.50;

    return SizedBox(
      height: widget.cardHeight,
      child: GestureDetector(
        onTap: () => _navigate3D(context),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
          elevation: 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Imagen de fondo ──────────────────────────────────────────
              OfflineCachedImage(
                imageUrl: '$baseUrl/images/${poi['image_id']}',
                imageId: poi['image_id'].toString(),
                fit: BoxFit.cover,
                placeholder: (_, __) => Center(
                  child: CircularProgressIndicator(
                    color: widget.theme.colorScheme.primary,
                  ),
                ),
                errorWidget: (_, __, ___) =>
                    Image.asset('images/default_image.png', fit: BoxFit.cover),
              ),

              // ── Overlay oscuro suave ─────────────────────────────────────
              Container(color: Colors.black.withOpacity(0.30)),

              // ── Gradiente inferior ───────────────────────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: 0.65,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.90),
                              Colors.black.withOpacity(0.55),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Icono movilidad (top-right) ──────────────────────────────
              if (isMobilityFriendly)
                Positioned(
                  top: 14,
                  right: 14,
                  child: IgnorePointer(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.90),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.accessible,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

              // ── Pill de rating global (top-left) ─────────────────────────
              if (rating > 0)
                Positioned(
                  top: 14,
                  left: 14,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFD54F),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${rating.toStringAsFixed(1)}  ($ratingsCount)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),


              // ── Panel inferior: título + botones ─────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // Título
                        Text(
                          poi['title'] ?? 'Sin título',
                          style: widget.theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            shadows: [
                              const Shadow(
                                blurRadius: 8,
                                color: Colors.black,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (poi['distancia'] != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${widget.localeProvider.translate('length')} ${poi['distancia']} km',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.80),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        // Fila: botones izquierda + estrellas derecha
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _ActionIconBtn(
                              icon: Icons.directions,
                              size: btnSize,
                              iconSize: iconSize,
                              onTap: () async {
                                HapticService().medium();
                                final lat = poi['latitude'];
                                final lng = poi['longitude'];
                                if (lat != null && lng != null) {
                                  final url = Uri.parse(
                                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                }
                              },
                            ),
                            const SizedBox(width: 2),
                            _ActionIconBtn(
                              icon: Icons.info_outline,
                              size: btnSize,
                              iconSize: iconSize,
                              onTap: () {
                                HapticService().medium();
                                _openInfo(context);
                              },
                            ),
                            const SizedBox(width: 2),
                            _ActionIconBtn(
                              icon: Icons.share,
                              size: btnSize,
                              iconSize: iconSize,
                              onTap: () async {
                                HapticService().medium();
                                final poiId = poi['id']?.toString();
                                if (poiId == null) return;
                                final uri = AppRouter.buildPoiDeepLink(poiId);
                                final subject =
                                    poi['title']?.toString() ?? 'POI';
                                try {
                                  if (kIsWeb) {
                                    await Clipboard.setData(
                                      ClipboardData(text: uri.toString()),
                                    );
                                  } else {
                                    await Share.share(
                                      uri.toString(),
                                      subject: subject,
                                    );
                                  }
                                } catch (_) {}
                              },
                            ),
                            if (isLoggedIn) ...[
                              const Spacer(),
                              _StarRatingWidget(
                                poiId: poi['id']?.toString() ?? '',
                                poi: poi,
                                initialRating: userRating.toInt(),
                                starSize: 20,
                                onRatingChanged: _updatePoi,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón de icono circular con sombra de texto
// ─────────────────────────────────────────────────────────────────────────────
class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _ActionIconBtn({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: iconSize,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selector de estrellas de valoración
// ─────────────────────────────────────────────────────────────────────────────
class _StarRatingWidget extends StatefulWidget {
  final String poiId;
  final Map<String, dynamic> poi;
  final int initialRating;
  final double starSize;
  final Function(Map<String, dynamic>)? onRatingChanged;

  const _StarRatingWidget({
    required this.poiId,
    required this.poi,
    required this.initialRating,
    this.starSize = 22,
    this.onRatingChanged,
  });

  @override
  State<_StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<_StarRatingWidget> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < _rating;
        return GestureDetector(
          onTap: () async {
            await HapticService().light();
            setState(() => _rating = i + 1);
            final newRatings = await rate_poi(widget.poiId, _rating);
            if (widget.onRatingChanged != null && newRatings != null) {
              final updatedPoi = Map<String, dynamic>.from(widget.poi);
              updatedPoi['rating'] = {
                'score': newRatings['score'],
                'user_ratings_total': newRatings['user_ratings_total'],
              };
              updatedPoi['user_rating'] = _rating;
              widget.onRatingChanged!(updatedPoi);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFFFD54F),
              size: widget.starSize,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet con descripción del POI
// ─────────────────────────────────────────────────────────────────────────────
class _PoiInfoSheet extends StatefulWidget {
  final Map<String, dynamic> poi;
  final String? poiId;
  final String langCode;
  final ThemeData theme;

  const _PoiInfoSheet({
    required this.poi,
    required this.poiId,
    required this.langCode,
    required this.theme,
  });

  @override
  State<_PoiInfoSheet> createState() => _PoiInfoSheetState();
}

class _PoiInfoSheetState extends State<_PoiInfoSheet> {
  late TTSService _tts;
  String? _description;

  void _onTtsStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tts = TTSService();
    _tts.addOnStartListener(_onTtsStateChange);
    _tts.addOnCompleteListener(_onTtsStateChange);
    _tts.addOnStopListener(_onTtsStateChange);
    _loadDescription();
  }

  @override
  void dispose() {
    _tts.removeOnStartListener(_onTtsStateChange);
    _tts.removeOnCompleteListener(_onTtsStateChange);
    _tts.removeOnStopListener(_onTtsStateChange);
    super.dispose();
  }

  Future<void> _loadDescription() async {
    if (widget.poiId == null) return;
    try {
      final desc = await moreInfoPois(widget.poiId!, widget.langCode);
      if (mounted) setState(() => _description = desc);
    } catch (e) {
      debugPrint('Error loading description: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.poi['title'] ?? 'Sin título',
                      style: widget.theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (widget.poiId != null && _description != null)
                    IconButton(
                      icon: Icon(
                        _tts.isPlaying ? Icons.stop : Icons.volume_up,
                        color: Colors.blue,
                      ),
                      onPressed: () async {
                        if (_tts.isPlaying) {
                          await _tts.stop();
                        } else if (_description != null &&
                            _description!.isNotEmpty) {
                          try {
                            await _tts.initialize();
                            final langCode = _tts.getLanguageCode(
                              widget.langCode,
                            );
                            await _tts.speak(
                              _description!,
                              languageCode: langCode,
                            );
                          } catch (e) {
                            debugPrint('TTS error: $e');
                          }
                        }
                      },
                    ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (widget.poiId == null)
                      const Text('No hay ID de POI disponible.')
                    else if (_description == null)
                      const Center(child: CircularProgressIndicator())
                    else if (_description!.isEmpty)
                      const Text('No hay descripción disponible.')
                    else
                      HighlightedText(
                        text: _description!,
                        style:
                            widget.theme.textTheme.bodyLarge ??
                            const TextStyle(),
                        ttsService: _tts,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
