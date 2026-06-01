import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/audio_provider.dart';
import '../providers/audio_player_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/route_provider.dart';
import '../../data/models/audio.dart';
import '../../services/haptic/haptic_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE  –  derived from the active app theme (light / dark)
// ═══════════════════════════════════════════════════════════════════════════

class _Palette {
  final Color scaffoldBg;
  final Color surface;        // card bg
  final Color activeSurface;  // active card bg
  final Color border;         // subtle border
  final Color activeBorder;   // active card accent border
  final Color accent;         // primary colour (green)
  final Color accentDim;      // secondary / dimmer green
  final Color playBtnBg;      // inactive play-button fill
  final Color textPri;        // primary text
  final Color textSec;        // secondary / muted text
  final Color headerGrad1;    // header gradient start
  final Color headerGrad2;    // header gradient end
  final bool isDark;

  const _Palette({
    required this.scaffoldBg,
    required this.surface,
    required this.activeSurface,
    required this.border,
    required this.activeBorder,
    required this.accent,
    required this.accentDim,
    required this.playBtnBg,
    required this.textPri,
    required this.textSec,
    required this.headerGrad1,
    required this.headerGrad2,
    required this.isDark,
  });

  factory _Palette.of(BuildContext context) {
    final th = Theme.of(context);
    final cs = th.colorScheme;
    final dark = cs.brightness == Brightness.dark;
    if (dark) {
      return _Palette(
        scaffoldBg: const Color(0xFF121212),
        surface: const Color(0xFF1A2A1A),
        activeSurface: const Color(0xFF1F3520),
        border: cs.primary.withOpacity(0.18),
        activeBorder: cs.primary,
        accent: cs.primary,
        accentDim: cs.secondary,
        playBtnBg: const Color(0xFF1E2E1E),
        textPri: Colors.white.withOpacity(0.92),
        textSec: cs.secondary,
        headerGrad1: const Color(0xFF061004),
        headerGrad2: cs.primary,
        isDark: true,
      );
    } else {
      return _Palette(
        scaffoldBg: th.scaffoldBackgroundColor,
        surface: th.cardColor,
        activeSurface: const Color(0xFFE7FAE0),
        border: cs.secondary.withOpacity(0.18),
        activeBorder: cs.primary,
        accent: cs.primary,
        accentDim: cs.secondary,
        playBtnBg: const Color(0xFFF0ECE6),
        textPri: const Color(0xFF3E3E3E),
        textSec: cs.secondary,
        headerGrad1: cs.primary,
        headerGrad2: cs.secondary,
        isDark: false,
      );
    }
  }
}

/// Pantalla para listar y reproducir audios de rutas
class AudiosScreen extends StatefulWidget {
  const AudiosScreen({super.key});

  @override
  State<AudiosScreen> createState() => _AudiosScreenState();
}

class _AudiosScreenState extends State<AudiosScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _headerAnim;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ap = context.read<AudioProvider>();
      if (ap.audios.isEmpty) ap.loadAudios();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final audioProvider = context.watch<AudioProvider>();
    final routeProvider = context.watch<RouteProvider>();
    final playerProvider = context.watch<AudioPlayerProvider>();
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 700;
    final isDesk = width >= 1100;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        backgroundColor: p.scaffoldBg,
        body: Column(
          children: [
            _buildHeader(p, localeProvider, audioProvider, isWide, isDesk),
            Expanded(
              child: _buildBody(
                  p, audioProvider, routeProvider, localeProvider, playerProvider, isWide, isDesk),
            ),
            if (playerProvider.hasAudio)
              _NowPlayingBar(playerProvider: playerProvider, isWide: isWide),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
      _Palette p, LocaleProvider loc, AudioProvider ap, bool isWide, bool isDesk) {
    final hPad = isDesk ? 56.0 : isWide ? 40.0 : 18.0;
    final titleFs = isDesk ? 32.0 : isWide ? 27.0 : 24.0;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [p.headerGrad1, p.headerGrad2],
          ),
          border: Border(
            bottom: BorderSide(
              color: p.accent.withOpacity(0.25),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesk ? 1200 : double.infinity),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad - 4, isWide ? 14 : 8, hPad, 0),
                    child: Row(
                      children: [
                        _CircleBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => context.go('/'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.translate('audios'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: titleFs,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              if (!ap.isLoading && ap.audios.isNotEmpty)
                                Text(
                                  '${ap.audios.length} pistas disponibles',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(isWide ? 13 : 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.library_music_rounded,
                            color: Colors.white,
                            size: isWide ? 30 : 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isWide ? 16 : 14),
                  Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, isWide ? 20 : 16),
                    child: _SearchBar(
                      controller: _searchController,
                      hint: loc.translate('search_audios'),
                      query: _searchQuery,
                      palette: p,
                      isWide: isWide,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      onClear: () => setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── BODY ──────────────────────────────────────────────────────────────────

  Widget _buildBody(
    _Palette p,
    AudioProvider ap,
    RouteProvider rp,
    LocaleProvider loc,
    AudioPlayerProvider pp,
    bool isWide,
    bool isDesk,
  ) {
    if (ap.isLoading) return _LoadingList(isWide: isWide, isDesk: isDesk);

    if (ap.error.isNotEmpty) {
      return _ErrorState(
        message: ap.error,
        onRetry: ap.loadAudios,
        retryLabel: loc.translate('retry'),
      );
    }

    final audios =
        _searchQuery.isEmpty ? ap.audios : ap.searchAudios(_searchQuery);

    if (audios.isEmpty) {
      return _EmptyState(
        label: _searchQuery.isEmpty
            ? loc.translate('no_audios_available')
            : loc.translate('no_audios_found'),
        isSearch: _searchQuery.isNotEmpty,
      );
    }

    final hPad = isDesk ? 56.0 : isWide ? 40.0 : 16.0;

    Widget list = ListView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 28),
      itemCount: audios.length,
      itemBuilder: (ctx, i) => _AudioCard(
        audio: audios[i],
        routeProvider: rp,
        localeProvider: loc,
        isCurrentAudio: pp.isCurrentAudio(audios[i].metadata.audioId),
        isPlaying: pp.isAudioPlaying(audios[i].metadata.audioId),
        isLoading: pp.isLoading,
        isWide: isWide,
        isDesk: isDesk,
        animDelay: Duration(milliseconds: 55 * i),
        onTap: () => _handleTap(audios[i], pp, loc),
      ),
    );

    if (isWide) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesk ? 1200 : 1000),
          child: list,
        ),
      );
    }
    return list;
  }

  Future<void> _handleTap(
      AudioModel audio, AudioPlayerProvider pp, LocaleProvider loc) async {
    HapticService().medium();
    if (pp.isCurrentAudio(audio.metadata.audioId)) {
      if (pp.isPlaying) {
        await pp.pause();
      } else {
        await pp.resume();
      }
    } else {
      try {
        await pp.playAudio(audio);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('error_playing_audio')),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SEARCH BAR
// ═══════════════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String query;
  final _Palette palette;
  final bool isWide;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.query,
    required this.palette,
    required this.isWide,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final h = isWide ? 54.0 : 48.0;
    final fs = isWide ? 15.5 : 14.0;
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(p.isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: fs, color: p.textPri),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: p.textSec.withOpacity(0.7), fontSize: fs),
          prefixIcon: Icon(Icons.search_rounded, color: p.accent,
              size: isWide ? 22 : 20),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: p.textSec),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CIRCLE BUTTON  (always on the header's dark gradient — always white)
// ═══════════════════════════════════════════════════════════════════════════

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AUDIO CARD
// ═══════════════════════════════════════════════════════════════════════════

class _AudioCard extends StatefulWidget {
  final AudioModel audio;
  final RouteProvider routeProvider;
  final LocaleProvider localeProvider;
  final bool isCurrentAudio;
  final bool isPlaying;
  final bool isLoading;
  final bool isWide;
  final bool isDesk;
  final Duration animDelay;
  final VoidCallback onTap;

  const _AudioCard({
    required this.audio,
    required this.routeProvider,
    required this.localeProvider,
    required this.isCurrentAudio,
    required this.isPlaying,
    required this.isLoading,
    required this.isWide,
    required this.isDesk,
    required this.animDelay,
    required this.onTap,
  });

  @override
  State<_AudioCard> createState() => _AudioCardState();
}

class _AudioCardState extends State<_AudioCard>
    with TickerProviderStateMixin {
  String? _routeName;
  late final AnimationController _entrance;
  late final AnimationController _wave;
  late final List<Animation<double>> _waveBars;

  @override
  void initState() {
    super.initState();
    _loadRouteName();

    _entrance = AnimationController(
        duration: const Duration(milliseconds: 380), vsync: this);
    Future.delayed(widget.animDelay, () {
      if (mounted) _entrance.forward();
    });

    _wave = AnimationController(
        duration: const Duration(milliseconds: 850), vsync: this)
      ..repeat(reverse: true);

    _waveBars = List.generate(4, (i) {
      final start = i * 0.18;
      return Tween<double>(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(
          parent: _wave,
          curve: Interval(start, math.min(1.0, start + 0.65),
              curve: Curves.easeInOut),
        ),
      );
    });
  }

  Future<void> _loadRouteName() async {
    try {
      final rt = widget.routeProvider.routeTypes.firstWhere(
        (r) => r['id'] == widget.audio.metadata.routeId,
        orElse: () => null,
      );
      if (mounted) setState(() => _routeName = rt?['name'] as String?);
    } catch (_) {}
  }

  @override
  void dispose() {
    _entrance.dispose();
    _wave.dispose();
    super.dispose();
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    if (diff < 7) return 'Hace $diff días';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final active = widget.isCurrentAudio;
    final playing = widget.isPlaying;
    final isWide = widget.isWide;
    final isDesk = widget.isDesk;

    final titleFs = isDesk ? 18.0 : isWide ? 16.5 : 15.5;
    final innerPad = isDesk ? 20.0 : isWide ? 17.0 : 14.0;
    final spacing = isWide ? 16.0 : 14.0;

    final entrance = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);

    return FadeTransition(
      opacity: entrance,
      child: SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(entrance),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 230),
            margin: EdgeInsets.symmetric(vertical: isWide ? 8 : 6),
            decoration: BoxDecoration(
              color: active ? p.activeSurface : p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? p.activeBorder : p.border,
                width: active ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? p.accent.withOpacity(0.22)
                      : Colors.black.withOpacity(p.isDark ? 0.4 : 0.07),
                  blurRadius: active ? 18 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(innerPad),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildPlayBtn(p, active, playing, isWide, isDesk),
                  SizedBox(width: spacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.audio.metadata.title,
                          style: TextStyle(
                            fontSize: titleFs,
                            fontWeight: FontWeight.w700,
                            color: active ? p.accent : p.textPri,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        if (_routeName != null)
                          _RouteBadge(
                            name: _routeName!,
                            palette: p,
                            isWide: isWide,
                            onTap: () {
                              HapticService().selection();
                              context.go('/route', extra: {
                                'routeId': widget.audio.metadata.routeId,
                                'routeName': _routeName,
                              });
                            },
                          ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            _MetaChip(
                              icon: Icons.graphic_eq_rounded,
                              label: _fmtSize(widget.audio.length),
                              palette: p,
                              isWide: isWide,
                            ),
                            const SizedBox(width: 12),
                            _MetaChip(
                              icon: Icons.schedule_rounded,
                              label: _fmtDate(widget.audio.uploadDate),
                              palette: p,
                              isWide: isWide,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayBtn(_Palette p, bool active, bool playing, bool isWide, bool isDesk) {
    final sz = isDesk ? 72.0 : isWide ? 64.0 : 56.0;
    final iconSz = isDesk ? 40.0 : isWide ? 36.0 : 34.0;
    final waveW = sz * 0.5;
    final waveH = sz * 0.5;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 230),
      width: sz,
      height: sz,
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.accentDim, p.accent],
              )
            : null,
        color: active ? null : p.playBtnBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: active ? p.accent.withOpacity(0.5) : p.border,
          width: 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: p.accent.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: playing
          ? Center(
              child: SizedBox(
                width: waveW,
                height: waveH,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    4,
                    (i) => AnimatedBuilder(
                      animation: _waveBars[i],
                      builder: (_, __) => Container(
                        width: 4,
                        height: waveH * _waveBars[i].value,
                        decoration: BoxDecoration(
                          color: active ? Colors.white : p.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : widget.isLoading && active
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      color: active ? Colors.white : p.accent, strokeWidth: 2),
                )
              : Icon(
                  Icons.play_arrow_rounded,
                  color: active ? Colors.white : p.accent,
                  size: iconSz,
                ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _RouteBadge extends StatelessWidget {
  final String name;
  final _Palette palette;
  final bool isWide;
  final VoidCallback? onTap;
  const _RouteBadge({required this.name, required this.palette, required this.isWide, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final fs = isWide ? 12.0 : 11.0;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: p.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.accent.withOpacity(onTap != null ? 0.45 : 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_rounded, size: fs, color: p.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: fs,
                color: p.accent,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded, size: fs - 1, color: p.accent),
          ],
        ],
      ),
    );
    if (onTap == null) return badge;
    return GestureDetector(
      onTap: onTap,
      child: badge,
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final _Palette palette;
  final bool isWide;
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.palette,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final fs = isWide ? 12.5 : 11.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: fs + 1, color: p.textSec.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: fs, color: p.textSec),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOADING STATE (Shimmer)
// ═══════════════════════════════════════════════════════════════════════════

class _LoadingList extends StatefulWidget {
  final bool isWide;
  final bool isDesk;
  const _LoadingList({required this.isWide, required this.isDesk});

  @override
  State<_LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<_LoadingList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1300), vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final hPad = widget.isDesk ? 56.0 : widget.isWide ? 40.0 : 16.0;
    final h = widget.isDesk ? 105.0 : widget.isWide ? 95.0 : 86.0;

    final shimBase = p.isDark ? const Color(0xff1a2a14) : const Color(0xFFE8E4DF);
    final shimHigh = p.isDark ? const Color(0xff223320) : const Color(0xFFF5F2EE);

    Widget list = ListView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 28),
      itemCount: 6,
      itemBuilder: (_, i) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final shimmer = LinearGradient(
            begin: Alignment(-2.0 + 4.0 * _ctrl.value, -0.3),
            end: Alignment(-1.0 + 4.0 * _ctrl.value, 0.3),
            colors: [shimBase, shimHigh, shimBase],
          );
          return Container(
            margin: EdgeInsets.symmetric(vertical: widget.isWide ? 8 : 6),
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: shimmer,
              border: Border.all(color: p.border),
            ),
          );
        },
      ),
    );
    if (widget.isWide) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.isDesk ? 1200 : 1000),
          child: list,
        ),
      );
    }
    return list;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ERROR STATE
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const _ErrorState(
      {required this.message,
      required this.onRetry,
      required this.retryLabel});

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: cs.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 52, color: cs.error),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: p.textSec),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String label;
  final bool isSearch;
  const _EmptyState({required this.label, required this.isSearch});

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: p.accent.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: p.accent.withOpacity(0.25), width: 1.5),
            ),
            child: Icon(
              isSearch ? Icons.search_off_rounded : Icons.music_off_rounded,
              size: 52,
              color: p.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: p.textSec,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NOW PLAYING BAR
// ═══════════════════════════════════════════════════════════════════════════

class _NowPlayingBar extends StatefulWidget {
  final AudioPlayerProvider playerProvider;
  final bool isWide;

  const _NowPlayingBar({required this.playerProvider, required this.isWide});

  @override
  State<_NowPlayingBar> createState() => _NowPlayingBarState();
}

class _NowPlayingBarState extends State<_NowPlayingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
        duration: const Duration(milliseconds: 320), vsync: this)
      ..forward();
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final audio = widget.playerProvider.currentAudio!;
    final playing = widget.playerProvider.isPlaying;
    final isWide = widget.isWide;

    // The player bar always uses a rich dark-green surface for visual consistency,
    // but uses the theme's primary colour for accents.
    final barBg = p.isDark ? const Color(0xff0d2008) : p.accentDim;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
              CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 1200 : double.infinity),
          child: Container(
            margin: EdgeInsets.fromLTRB(
                isWide ? 20 : 12, 0, isWide ? 20 : 12, isWide ? 18 : 14),
            padding: EdgeInsets.symmetric(
                horizontal: isWide ? 22 : 16, vertical: isWide ? 16 : 12),
            decoration: BoxDecoration(
              color: barBg,
              border: Border.all(color: p.accent.withOpacity(0.4), width: 1.5),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: p.accent.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: isWide ? 50 : 42,
                  height: isWide ? 50 : 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Icon(Icons.music_note_rounded,
                      color: Colors.white, size: isWide ? 26 : 22),
                ),
                SizedBox(width: isWide ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        audio.metadata.title,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: isWide ? 16 : 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        playing ? 'Reproduciendo...' : 'En pausa',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: isWide ? 13 : 11.5),
                      ),
                    ],
                  ),
                ),
                _BarBtn(
                  icon: playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onTap: () async {
                    HapticService().light();
                    if (playing) {
                      await widget.playerProvider.pause();
                    } else {
                      await widget.playerProvider.resume();
                    }
                  },
                  isWide: isWide,
                ),
                const SizedBox(width: 8),
                _BarBtn(
                  icon: Icons.stop_rounded,
                  onTap: () async {
                    HapticService().light();
                    await widget.playerProvider.stop();
                  },
                  dim: true,
                  isWide: isWide,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dim;
  final bool isWide;

  const _BarBtn({
    required this.icon,
    required this.onTap,
    this.dim = false,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final sz = isWide ? 48.0 : 40.0;
    final iconSz = isWide ? 26.0 : 22.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: sz,
        height: sz,
        decoration: BoxDecoration(
          color: dim
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dim
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.35),
          ),
        ),
        child: Icon(
          icon,
          color: dim ? Colors.white54 : Colors.white,
          size: iconSz,
        ),
      ),
    );
  }
}

