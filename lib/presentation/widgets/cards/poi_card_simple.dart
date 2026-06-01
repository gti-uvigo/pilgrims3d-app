import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pilgrims_3d/core/config/env.dart';
import 'package:pilgrims_3d/services/haptic/haptic_service.dart';
import 'package:pilgrims_3d/services/api/api_service.dart';
import 'package:pilgrims_3d/services/tts/tts_service.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:pilgrims_3d/presentation/widgets/offline_cached_image.dart';
import 'package:url_launcher/url_launcher.dart';

class PoiCardSimple extends StatefulWidget {
  final Map<String, dynamic> poi;
  final LocaleProvider localeProvider;
  final ThemeData theme;
  final int index;
  final bool isFlipped;
  final bool showHint;
  final VoidCallback onFlip;
  final VoidCallback onLongPress;

  const PoiCardSimple({
    super.key,
    required this.poi,
    required this.localeProvider,
    required this.theme,
    required this.index,
    required this.isFlipped,
    required this.showHint,
    required this.onFlip,
    required this.onLongPress,
  });

  @override
  State<PoiCardSimple> createState() => _PoiCardSimpleState();
}

class _PoiCardSimpleState extends State<PoiCardSimple> {
  bool _enableFlipAnimation = false;

  @override
  void didUpdateWidget(covariant PoiCardSimple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFlipped != widget.isFlipped) {
      _enableFlipAnimation = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticService().light();
        widget.onFlip();
      },
      onLongPress: widget.onLongPress,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.isFlipped ? math.pi : 0.0),
        duration:
            _enableFlipAnimation
                ? const Duration(milliseconds: 600)
                : Duration.zero,
        curve: Curves.easeInOut,
        builder: (context, angle, _) {
          final isBack = angle >= (math.pi / 2);
          final displayAngle = isBack ? angle - math.pi : angle;
          final transform =
              Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(displayAngle);
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child:
                isBack
                    ? _buildPoiCardBack(context)
                    : _buildPoiCardFront(context),
          );
        },
      ),
    );
  }

  Widget _buildPoiCardFront(BuildContext context) {
    final String title =
        widget.poi['title'] ??
        (widget.poi['types'] != null && (widget.poi['types'] as List).isNotEmpty
            ? (widget.poi['types'] as List).first
            : 'Sin título');
    return Card(
      key: const ValueKey('front'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          OfflineCachedImage(
            imageUrl: "$baseUrl/images/${widget.poi['image_id']}",
            imageId: widget.poi['image_id'].toString(),
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Center(child: CircularProgressIndicator()),
            errorWidget:
                (context, url, error) =>
                    Image.asset('images/default_image.png', fit: BoxFit.cover),
          ),
          // Scrim eased: concentrado en el 55% inferior, el resto permanece limpio
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  widthFactor: 1,
                  heightFactor: 0.55,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.75),
                          Colors.black.withOpacity(0.50),
                          Colors.black.withOpacity(0.27),
                          Colors.black.withOpacity(0.10),
                          Colors.black.withOpacity(0.02),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.12, 0.28, 0.50, 0.75, 1.0],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedOpacity(
                  opacity: widget.showHint ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 12,
                            color: widget.theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.localeProvider.translate('hold_to_press'),
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Frosted glass: desenfoca y oscurece la imagen detrás del texto,
                // garantizando legibilidad sea la imagen oscura, clara o blanca.
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: widget.theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 12.0,
                                  color: Colors.black.withOpacity(0.9),
                                  offset: const Offset(0, 2),
                                ),
                                Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.black.withOpacity(0.7),
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (widget.poi['types'] != null &&
                              (widget.poi['types'] as List).isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                (widget.poi['types'] as List).join(' • '),
                                style: widget.theme.textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 8.0,
                                          color: Colors.black.withOpacity(0.9),
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ], // Column.children de BackdropFilter
                      ), // Column
                    ), // Container
                  ), // BackdropFilter
                ), // ClipRRect
              ],
            ),
          ),
          if (widget.poi['zenodo_url'] != null &&
              widget.poi['zenodo_url'] != '')
            Positioned(
              bottom: 16,
              right: 16,
              child: Material(
                color: const Color.fromARGB(255, 32, 90, 34),
                elevation: 6,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    HapticService().medium();
                    context.push(
                      '/model-viewer?modelUrl=${Uri.encodeComponent(widget.poi['zenodo_url'])}',
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.view_in_ar, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          '3D',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPoiCardBack(BuildContext context) {
    final bool isMobilityFriendly = widget.poi['is_mobility_friendly'] == true;
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonSize = (screenWidth * 0.12).clamp(40.0, 48.0);
    final iconSize = buttonSize * 0.55;
    return Card(
      key: const ValueKey('back'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          OfflineCachedImage(
            imageUrl: "$baseUrl/images/${widget.poi['image_id']}",
            imageId: widget.poi['image_id'].toString(),
            fit: BoxFit.cover,
            errorWidget:
                (context, url, error) =>
                    Image.asset('images/default_image.png', fit: BoxFit.cover),
          ),
          Container(color: Colors.black.withOpacity(0.5)),
          // Icono de movilidad arriba a la derecha
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMobilityFriendly ? Colors.blue : Colors.grey,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.accessible, size: 28, color: Colors.white),
            ),
          ),
          // Contenido alineado abajo
          Positioned(
            bottom: 16,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selector de estrellas
                _StarRatingSelector(
                  poiId: widget.poi['id']?.toString() ?? '',
                  initialRating: 0,
                ),
                const SizedBox(height: 16),
                // Botones de navegación e información
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botón de Google Maps
                    Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () async {
                            HapticService().medium();
                            final lat = widget.poi['latitude'];
                            final lng = widget.poi['longitude'];
                            if (lat != null && lng != null) {
                              final url = Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking',
                              );
                              if (await canLaunchUrl(url)) {
                                await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            }
                          },
                          child: Icon(
                            Icons.navigation,
                            size: iconSize,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Botón de información
                    Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: widget.onLongPress,
                          child: Icon(
                            Icons.info_outline,
                            size: iconSize,
                            color: widget.theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    // Botón de audio
                    _AudioButton(
                      poiId: widget.poi['id']?.toString() ?? '',
                      localeProvider: widget.localeProvider,
                      buttonSize: buttonSize,
                      iconSize: iconSize,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget auxiliar para el selector de estrellas
class _StarRatingSelector extends StatefulWidget {
  final String poiId;
  final int initialRating;

  const _StarRatingSelector({required this.poiId, required this.initialRating});

  @override
  State<_StarRatingSelector> createState() => _StarRatingSelectorState();
}

class _StarRatingSelectorState extends State<_StarRatingSelector> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Ajustar tamaño de estrellas según ancho de pantalla
    final starSize = (screenWidth * 0.06).clamp(24.0, 36.0);
    final horizontalPadding = (screenWidth * 0.005).clamp(2.0, 3.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () async {
            await HapticService().light();
            setState(() {
              _rating = index + 1;
            });
            // Aquí podrías guardar la puntuación en una base de datos
            debugPrint('POI ${widget.poiId} rated: ${index + 1} stars');
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Icon(
              index < _rating ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: starSize,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// Widget para el botón de audio
class _AudioButton extends StatefulWidget {
  final String poiId;
  final LocaleProvider localeProvider;
  final double buttonSize;
  final double iconSize;

  const _AudioButton({
    required this.poiId,
    required this.localeProvider,
    required this.buttonSize,
    required this.iconSize,
  });

  @override
  State<_AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<_AudioButton> {
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
  Widget build(BuildContext context) {
    return Container(
      width: widget.buttonSize,
      height: widget.buttonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.orange,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            if (_ttsService.isPlaying) {
              await _ttsService.stop();
            } else {
              try {
                final description = await moreInfoPois(
                  widget.poiId,
                  widget.localeProvider.currentLangId,
                );
                if (description.isNotEmpty) {
                  await _ttsService.initialize();
                  final langCode = _ttsService.getLanguageCode(
                    widget.localeProvider.currentLangId,
                  );
                  await _ttsService.speak(description, languageCode: langCode);
                }
              } catch (e) {
                debugPrint('Error playing audio: $e');
              }
            }
          },
          child: Icon(
            _ttsService.isPlaying ? Icons.stop : Icons.volume_up,
            size: widget.iconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
