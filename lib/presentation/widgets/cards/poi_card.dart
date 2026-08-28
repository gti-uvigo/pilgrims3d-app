import 'dart:math' as math;
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

class PoiCard extends StatefulWidget {
  final Map<String, dynamic> poi;
  final LocaleProvider localeProvider;
  final ThemeData theme;
  final int dayIndex;
  final int poiIndex;
  final Size? frontCardSize;
  final double fixedCardHeight;
  final bool isFlipped;
  final VoidCallback onFlip;
  final bool showHint;
  final Key? frontCardKey;
  final bool showModel3dButton;

  const PoiCard({
    super.key,
    required this.poi,
    required this.localeProvider,
    required this.theme,
    required this.dayIndex,
    required this.poiIndex,
    required this.frontCardSize,
    required this.fixedCardHeight,
    required this.isFlipped,
    required this.onFlip,
    required this.showHint,
    this.frontCardKey,
    this.showModel3dButton = true,
  });

  @override
  State<PoiCard> createState() => _PoiCardState();
}

class _PoiCardState extends State<PoiCard> {
  bool _enableFlipAnimation = false;
  late Map<String, dynamic> _poi;

  @override
  void initState() {
    super.initState();
    _poi = Map<String, dynamic>.from(widget.poi);
  }

  @override
  void didUpdateWidget(covariant PoiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFlipped != widget.isFlipped) {
      _enableFlipAnimation = true;
    }
    if (!mapEquals(oldWidget.poi, widget.poi)) {
      _poi = Map<String, dynamic>.from(widget.poi);
    }
  }

  void _updatePoi(Map<String, dynamic> updatedPoi) {
    setState(() {
      _poi = Map<String, dynamic>.from(updatedPoi);
    });
  }

  @override
  Widget build(BuildContext context) {
    final zenodoUrl = _poi['zenodo_url'] as String?;
    final hasZenodo = zenodoUrl != null && zenodoUrl.isNotEmpty;
    return SizedBox(
      height: widget.fixedCardHeight,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              HapticService().light();
              widget.onFlip();
            },
            onLongPress: () async {
              await HapticService().longPress();
              if (context.mounted) {
                _showExpandedContentAsBottomSheet(
                  context,
                  widget.poi,
                  widget.localeProvider,
                  widget.theme,
                );
              }
            },
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
                          ? _buildPoiCardBack(
                            context,
                            _poi,
                            widget.localeProvider,
                            widget.theme,
                            key: const ValueKey('back'),
                            frontCardSize: widget.frontCardSize,
                          )
                          : _buildPoiCardFront(
                            context,
                            _poi,
                            widget.localeProvider,
                            widget.theme,
                            key: widget.frontCardKey,
                            showHint: widget.showHint,
                          ),
                );
              },
            ),
          ),
          if (hasZenodo && !widget.isFlipped && widget.showModel3dButton)
            Positioned(
              bottom: 38,
              right: 38,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticService().medium();
                  context.push(
                    '/model-viewer?modelUrl=${Uri.encodeComponent(zenodoUrl)}',
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    color: const Color.fromARGB(255, 32, 90, 34),
                    elevation: 6,
                    borderRadius: BorderRadius.circular(24),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
            ),
        ],
      ),
    );
  }

  // ... (El método _buildPoiCardFront se mantiene igual que en tu código original)
  Widget _buildPoiCardFront(
    BuildContext context,
    Map<String, dynamic> poi,
    LocaleProvider localeProvider,
    ThemeData theme, {
    Key? key,
    required bool showHint,
  }) {
    // Copia aquí el código original de _buildPoiCardFront si no ha cambiado,
    // o usa el que tenías en tu snippet. Para abreviar la respuesta, asumo
    // que esta parte no necesita cambios visuales.
    // (Incluido por completitud basado en tu input)
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600 && !kIsWeb;
    final bool isMobilityFriendly = poi['is_mobility_friendly'] ?? false;
    return Card(
      key: key,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      elevation: 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          OfflineCachedImage(
            imageUrl: "$baseUrl/images/${poi['image_id']}",
            imageId: poi['image_id'].toString(),
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                ),
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
          if (isMobilityFriendly)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.9),
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
          Transform(
            transform:
                isTablet ? (Matrix4.rotationZ(math.pi)) : Matrix4.identity(),
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: isTablet ? math.pi : 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedOpacity(
                      opacity: showHint ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app,
                                size: 12,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.localeProvider.translate(
                                  'hold_to_press',
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poi['title'] ?? 'Sin título',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 8.0,
                                color: Colors.black,
                                offset: const Offset(0, 2),
                              ),
                              Shadow(
                                blurRadius: 16.0,
                                color: Colors.black,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (poi['distancia'] != null)
                          Text(
                            '${localeProvider.translate('length')} ${poi['distancia']} km',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              shadows: [
                                Shadow(
                                  blurRadius: 8.0,
                                  color: Colors.black,
                                  offset: const Offset(0, 2),
                                ),
                                Shadow(
                                  blurRadius: 14.0,
                                  color: Colors.black,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!widget.showModel3dButton && (poi['zenodo_url'] as String?) != null && (poi['zenodo_url'] as String).isNotEmpty)
            Positioned(
              bottom: 14,
              right: 14,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.view_in_ar, size: 14, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        '3D',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AQUÍ ESTÁ LA LÓGICA MODIFICADA PARA LA PARTE TRASERA (ESTILO REVIEW CARD)
  // ---------------------------------------------------------------------------
  Widget _buildPoiCardBack(
    BuildContext context,
    Map<String, dynamic> poi,
    LocaleProvider localeProvider,
    ThemeData theme, {
    Key? key,
    Size? frontCardSize,
  }) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600 && !kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive: Tamaños más conservadores para móvil
    final buttonSize =
        screenWidth < 400 ? 45.0 : (screenWidth * 0.11).clamp(45.0, 60.0);
    final iconSize = buttonSize * 0.5;
    final mobilityIconSize = screenWidth < 400 ? 32.0 : 40.0;
    final ratingFontSize =
        screenWidth < 350
            ? 24.0
            : (screenWidth < 400
                ? 28.0
                : (screenWidth * 0.07).clamp(28.0, 42.0));
    final starSize =
        screenWidth < 350 ? 12.0 : (screenWidth < 400 ? 14.0 : 18.0);
    final userStarSize =
        screenWidth < 350 ? 20.0 : (screenWidth < 400 ? 24.0 : 28.0);
    final cardPadding =
        screenWidth < 350 ? 8.0 : (screenWidth < 400 ? 12.0 : 16.0);

    // Manejo del rating: si es null, usar 0
    final double rating = (poi['rating']?['score']?.toDouble()) ?? 0.0;
    final int userRatingsTotal = (poi['rating']?['user_ratings_total']) ?? 0;
    final double userRating = poi['user_rating']?.toDouble() ?? 0.0;
    final String ratingScore = rating.toStringAsFixed(1);
    final String ratingCount =
        "$userRatingsTotal ${localeProvider.translate('reviews')}";

    return Card(
      key: key,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      elevation: 4,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // 1. Imagen de Fondo
          OfflineCachedImage(
            imageUrl: "$baseUrl/images/${poi['image_id']}",
            imageId: poi['image_id'].toString(),
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                ),
            errorWidget:
                (context, url, error) =>
                    Image.asset('images/default_image.png', fit: BoxFit.cover),
          ),

          // 2. Overlay oscuro sutil para que resalten los elementos blancos
          Container(color: Colors.black.withOpacity(0.4)),

          // 3. Contenido Principal
          Transform(
            transform:
                isTablet ? (Matrix4.rotationZ(math.pi)) : Matrix4.identity(),
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: isTablet ? math.pi : 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Espacio superior para el icono de movilidad
                  SizedBox(height: mobilityIconSize + 20),

                  // --- Tarjeta de Reseña — crece para ocupar el espacio disponible ---
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.08,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availH = constraints.maxHeight;
                          final isTiny = availH < 55;
                          final isCompact = !isTiny && availH < 110;
                          final adaptedRatingFont =
                              isTiny
                                  ? 14.0
                                  : isCompact
                                  ? (ratingFontSize * 0.65).clamp(
                                    16.0,
                                    ratingFontSize,
                                  )
                                  : ratingFontSize;
                          final adaptedStarSize =
                              isCompact
                                  ? (starSize * 0.75).clamp(8.0, starSize)
                                  : starSize;
                          final tinyUserStarSize = (availH * 0.5).clamp(
                            12.0,
                            18.0,
                          );
                          final vPadding =
                              isTiny
                                  ? 2.0
                                  : isCompact
                                  ? 4.0
                                  : 10.0;

                          // Modo una sola línea: rating + selector de voto
                          if (isTiny) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: cardPadding,
                                vertical: vPadding,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: const Color(0xFFE69800),
                                        size: tinyUserStarSize,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        ratingScore,
                                        style: TextStyle(
                                          fontSize: adaptedRatingFont,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFE69800),
                                          height: 1.0,
                                        ),
                                      ),
                                      if (FirebaseAuth.instance.currentUser !=
                                          null) ...[
                                        const SizedBox(width: 8),
                                        const SizedBox(
                                          width: 1,
                                          height: 20,
                                          child: VerticalDivider(
                                            color: Color(0xFFEEEEEE),
                                            thickness: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _StarRatingSelector(
                                          poiId: poi['id']?.toString() ?? '',
                                          poi: poi,
                                          initialRating: userRating.toInt(),
                                          starColor: const Color(0xFFE69800),
                                          starSize: tinyUserStarSize,
                                          onRatingChanged:
                                              (updatedPoi) =>
                                                  _updatePoi(updatedPoi),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: cardPadding,
                              vertical: vPadding,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                // Fila superior: Puntuación Grande y Estrellas
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      ratingScore,
                                      style: TextStyle(
                                        fontSize: adaptedRatingFont,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFE69800),
                                        height: 1.0,
                                      ),
                                    ),
                                    SizedBox(width: screenWidth < 350 ? 6 : 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(5, (index) {
                                            final fullStars = rating.floor();
                                            final hasHalfStar =
                                                (rating - fullStars) >= 0.5;
                                            IconData icon;
                                            if (index < fullStars) {
                                              icon = Icons.star;
                                            } else if (index == fullStars &&
                                                hasHalfStar) {
                                              icon = Icons.star_half;
                                            } else {
                                              icon = Icons.star_border;
                                            }
                                            return Icon(
                                              icon,
                                              color: const Color(0xFFE69800),
                                              size: adaptedStarSize,
                                            );
                                          }),
                                        ),
                                        if (!isCompact) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            ratingCount,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize:
                                                  screenWidth < 350 ? 9 : 10,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                if (!isCompact) ...[
                                  SizedBox(height: screenWidth < 350 ? 6 : 8),
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFEEEEEE),
                                  ),
                                  SizedBox(height: screenWidth < 350 ? 6 : 8),
                                ],
                                if (FirebaseAuth.instance.currentUser != null)
                                  Center(
                                    child: _StarRatingSelector(
                                      poiId: poi['id']?.toString() ?? '',
                                      poi: poi,
                                      initialRating: userRating.toInt(),
                                      starColor: const Color(0xFFE69800),
                                      starSize:
                                          isCompact
                                              ? (userStarSize * 0.7).clamp(
                                                14.0,
                                                userStarSize,
                                              )
                                              : userStarSize,
                                      onRatingChanged: (updatedPoi) {
                                        _updatePoi(updatedPoi);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // --- Botones de Acción ---
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: screenWidth < 600 ? 16 : 24,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 1. Botón Navegar
                        _buildCircleActionButton(
                          icon: Icons.directions,
                          color: Colors.transparent,
                          iconColor: Colors.white,
                          size: buttonSize,
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

                        // 2. Botón Información
                        _buildCircleActionButton(
                          icon: Icons.info_outline,
                          color: Colors.transparent,
                          iconColor: Colors.white,
                          size: buttonSize,
                          iconSize: iconSize,
                          onTap: () {
                            HapticService().medium();
                            _showExpandedContentAsBottomSheet(
                              context,
                              poi,
                              localeProvider,
                              theme,
                            );
                          },
                        ),

                        // 3. Botón Compartir
                        _buildCircleActionButton(
                          icon: Icons.share,
                          color: Colors.transparent,
                          iconColor: Colors.white,
                          size: buttonSize,
                          iconSize: iconSize,
                          onTap: () async {
                            HapticService().medium();
                            final poiId = poi['id']?.toString();
                            if (poiId == null) {
                              debugPrint('No hay id de POI para compartir');
                              return;
                            }

                            final uri = AppRouter.buildPoiDeepLink(poiId);
                            final subject = poi['title']?.toString() ?? 'POI';

                            try {
                              if (kIsWeb) {
                                await Clipboard.setData(
                                  ClipboardData(text: uri.toString()),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enlace copiado al portapapeles',
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                await Share.share(
                                  uri.toString(),
                                  subject: subject,
                                );
                              }
                            } catch (e) {
                              debugPrint('No se pudo compartir el POI: $e');
                            }
                          },
                        ),
                      ],
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

  // Widget auxiliar para los botones circulares
  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: iconColor,
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

  void _showExpandedContentAsBottomSheet(
    BuildContext context,
    Map<String, dynamic> poi,
    LocaleProvider localeProvider,
    ThemeData theme,
  ) {
    // ... (Mismo código que tenías)
    final String? poiId = poi['id']?.toString();
    final String langCode = localeProvider.currentLangId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return _PoiDescriptionSheet(
          poi: poi,
          poiId: poiId,
          langCode: langCode,
          theme: theme,
        );
      },
    );
  }
}

// Widget con estado para el Bottom Sheet que comparte el TTSService
class _PoiDescriptionSheet extends StatefulWidget {
  final Map<String, dynamic> poi;
  final String? poiId;
  final String langCode;
  final ThemeData theme;

  const _PoiDescriptionSheet({
    required this.poi,
    required this.poiId,
    required this.langCode,
    required this.theme,
  });

  @override
  State<_PoiDescriptionSheet> createState() => _PoiDescriptionSheetState();
}

class _PoiDescriptionSheetState extends State<_PoiDescriptionSheet> {
  late TTSService _ttsService;
  String? _description;

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
    _loadDescription();
  }

  @override
  void dispose() {
    _ttsService.removeOnStartListener(_onTtsStateChange);
    _ttsService.removeOnCompleteListener(_onTtsStateChange);
    _ttsService.removeOnStopListener(_onTtsStateChange);
    super.dispose();
  }

  Future<void> _loadDescription() async {
    if (widget.poiId != null) {
      try {
        final desc = await moreInfoPois(widget.poiId!, widget.langCode);
        if (mounted) {
          setState(() {
            _description = desc;
          });
        }
      } catch (e) {
        debugPrint('Error loading description: $e');
      }
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
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
                        _ttsService.isPlaying ? Icons.stop : Icons.volume_up,
                        color: Colors.blue,
                      ),
                      onPressed: () async {
                        if (_ttsService.isPlaying) {
                          await _ttsService.stop();
                        } else {
                          if (_description != null &&
                              _description!.isNotEmpty) {
                            try {
                              await _ttsService.initialize();
                              final langCode = _ttsService.getLanguageCode(
                                widget.langCode,
                              );
                              await _ttsService.speak(
                                _description!,
                                languageCode: langCode,
                              );
                            } catch (e) {
                              debugPrint('Error playing audio: $e');
                            }
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
                      const Text('No POI ID available for more information.')
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
                        ttsService: _ttsService,
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

// Widget auxiliar para el selector de estrellas (modificado para ajustarse a la tarjeta)
class _StarRatingSelector extends StatefulWidget {
  final String poiId;
  final Map<String, dynamic> poi;
  final int initialRating;
  final Color starColor;
  final double starSize;
  final Function(Map<String, dynamic>)? onRatingChanged;

  const _StarRatingSelector({
    required this.poiId,
    required this.poi,
    required this.initialRating,
    this.starColor = Colors.amber,
    this.starSize = 24.0,
    this.onRatingChanged,
  });

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () async {
            await HapticService().light();
            setState(() {
              _rating = index + 1;
            });

            // Hacer la petición al servidor
            final newRatings = await rate_poi(widget.poiId, _rating);
            debugPrint('New ratings: $newRatings');

            // Si el callback está definido, actualizar solo el rating dentro del POI
            if (widget.onRatingChanged != null && newRatings != null) {
              // Crear una copia del POI y actualizar solo los campos de rating
              final updatedPoi = Map<String, dynamic>.from(widget.poi);

              // Actualizar el rating general
              if (updatedPoi['rating'] is Map) {
                updatedPoi['rating'] = {
                  'score': newRatings['score'],
                  'user_ratings_total': newRatings['user_ratings_total'],
                };
              } else {
                updatedPoi['rating'] = {
                  'score': newRatings['score'],
                  'user_ratings_total': newRatings['user_ratings_total'],
                };
              }

              // Actualizar el rating del usuario
              updatedPoi['user_rating'] = _rating;

              // Pasar el POI actualizado al callback
              widget.onRatingChanged!(updatedPoi);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(2.0),
            child: Icon(
              index < _rating ? Icons.star : Icons.star_border,
              color: widget.starColor,
              size: widget.starSize,
            ),
          ),
        );
      }),
    );
  }
}

// Widget para el botón de reproducción de audio
class _AudioPlayButton extends StatefulWidget {
  final String poiId;
  final String langCode;

  const _AudioPlayButton({required this.poiId, required this.langCode});

  @override
  State<_AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<_AudioPlayButton> {
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
    return IconButton(
      icon: Icon(
        _ttsService.isPlaying ? Icons.stop : Icons.volume_up,
        color: Colors.blue,
      ),
      onPressed: () async {
        if (_ttsService.isPlaying) {
          await _ttsService.stop();
        } else {
          try {
            final description = await moreInfoPois(
              widget.poiId,
              widget.langCode,
            );
            if (description.isNotEmpty) {
              await _ttsService.initialize();
              final langCode = _ttsService.getLanguageCode(widget.langCode);
              await _ttsService.speak(description, languageCode: langCode);
            }
          } catch (e) {
            debugPrint('Error playing audio: $e');
          }
        }
      },
    );
  }
}
