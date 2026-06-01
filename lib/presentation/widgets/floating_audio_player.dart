import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import '../../data/models/audio.dart';
import '../../services/haptic/haptic_service.dart';
import '../../core/config/routes.dart';

/// Widget de reproductor de audio flotante que persiste entre pantallas
class FloatingAudioPlayer extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final AudioModel? currentAudio;
  final VoidCallback? onClose;
  final VoidCallback? onExpand;

  const FloatingAudioPlayer({
    super.key,
    required this.audioPlayer,
    this.currentAudio,
    this.onClose,
    this.onExpand,
  });

  @override
  State<FloatingAudioPlayer> createState() => _FloatingAudioPlayerState();
}

class _FloatingAudioPlayerState extends State<FloatingAudioPlayer> {
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  Offset _position = const Offset(16, 100); // Posición inicial
  bool _isDragging = false;
  Offset? _dragStartPosition;
  bool _isModalOpen = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    // Escuchar cambios en la posición
    widget.audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Escuchar cambios en la duración
    widget.audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    // Escuchar cambios en el estado
    widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Cuando termina, resetear
    widget.audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _playPause() async {
    HapticService().light();
    if (_isPlaying) {
      await widget.audioPlayer.pause();
    } else {
      await widget.audioPlayer.resume();
    }
  }

  Future<void> _stop() async {
    HapticService().medium();
    await widget.audioPlayer.stop();
    if (widget.onClose != null) {
      widget.onClose!();
    }
  }

  Future<void> _seek(Duration position) async {
    await widget.audioPlayer.seek(position);
    // Actualizar inmediatamente el estado local
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    HapticService().light();
    final newPosition = _currentPosition + delta;
    if (newPosition < Duration.zero) {
      await _seek(Duration.zero);
    } else if (newPosition > _totalDuration) {
      await _seek(_totalDuration);
    } else {
      await _seek(newPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentAudio == null) {
      return const SizedBox.shrink();
    }

    final localeProvider = context.watch<LocaleProvider>();
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _dragStartPosition = _position;
            _isDragging = false; // Empezamos sin marcar como dragging
          });
        },
        onPanUpdate: (details) {
          setState(() {
            // Actualizar posición asegurando que no salga de la pantalla
            double newX = _position.dx + details.delta.dx;
            double newY = _position.dy + details.delta.dy;
            
            // Limitar dentro de los bordes de la pantalla
            newX = newX.clamp(0.0, screenSize.width - 200);
            newY = newY.clamp(0.0, screenSize.height - 60);
            
            _position = Offset(newX, newY);
            
            // Si se movió más de 5 píxeles, es un drag
            if (_dragStartPosition != null && 
                (_position - _dragStartPosition!).distance > 5) {
              _isDragging = true;
            }
          });
        },
        onPanEnd: (_) {
          // Si no hubo drag significativo, abrir el reproductor expandido
          if (!_isDragging && _dragStartPosition != null) {
            _showExpandedPlayer(context, localeProvider);
          }
          setState(() {
            _isDragging = false;
            _dragStartPosition = null;
          });
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(30),
          shadowColor: Colors.black.withOpacity(0.3),
          child: Container(
            width: 200,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xff6b8e4e),
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Ícono de audio
                const Icon(
                  Icons.audiotrack,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                // Información del audio
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.currentAudio!.metadata.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Mini progress bar
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(1),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _totalDuration.inSeconds > 0
                              ? _currentPosition.inSeconds / _totalDuration.inSeconds
                              : 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Botón de play/pause (sin activar drag)
                GestureDetector(
                  onTap: () {
                    HapticService().light();
                    _playPause();
                  },
                  onPanDown: (_) {}, // Prevenir que se propague el pan al padre
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExpandedPlayer(BuildContext context, LocaleProvider localeProvider) {
    // Prevenir abrir múltiples modales
    if (_isModalOpen) return;
    
    final navContext = navigatorKey.currentContext;
    if (navContext == null) return;
    
    setState(() {
      _isModalOpen = true;
    });
    
    showModalBottomSheet(
      context: navContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildExpandedPlayerDialog(localeProvider),
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isModalOpen = false;
        });
      }
    });
  }

  Widget _buildExpandedPlayerDialog(LocaleProvider localeProvider) {
    return StreamBuilder<PlayerState>(
      stream: widget.audioPlayer.onPlayerStateChanged,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data == PlayerState.playing;
        
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              // Indicador de arrastre
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              
              // Título del audio
              Row(
                children: [
                  const Icon(
                    Icons.audiotrack,
                    color: Color(0xff6b8e4e),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentAudio!.metadata.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.currentAudio!.filename,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          
          const SizedBox(height: 24),
          
          // Barra de progreso interactiva
              StatefulBuilder(
                builder: (context, setSliderState) {
                  Duration sliderPosition = _currentPosition;
                  
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: const Color(0xff6b8e4e),
                          inactiveTrackColor: Colors.grey[300],
                          thumbColor: const Color(0xff6b8e4e),
                          overlayColor: const Color(0xff6b8e4e).withOpacity(0.2),
                        ),
                        child: Slider(
                          value: _totalDuration.inSeconds > 0
                              ? sliderPosition.inSeconds.toDouble()
                              : 0,
                          max: _totalDuration.inSeconds > 0 
                              ? _totalDuration.inSeconds.toDouble() 
                              : 1.0,
                          onChanged: (value) {
                            setSliderState(() {
                              sliderPosition = Duration(seconds: value.toInt());
                            });
                          },
                          onChangeEnd: (value) {
                            _seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_currentPosition),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _formatDuration(_totalDuration),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          const SizedBox(height: 24),
          
          // Controles de reproducción
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Retroceder 10 segundos
              IconButton(
                icon: const Icon(Icons.replay_10),
                iconSize: 36,
                onPressed: () => _seekRelative(const Duration(seconds: -10)),
                color: Colors.grey[700],
              ),
              const SizedBox(width: 32),
              
              // Play/Pause
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xff6b8e4e),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 36,
                    color: Colors.white,
                  ),
                  onPressed: _playPause,
                ),
              ),
              const SizedBox(width: 32),
              
              // Avanzar 10 segundos
              IconButton(
                icon: const Icon(Icons.forward_10),
                iconSize: 36,
                onPressed: () => _seekRelative(const Duration(seconds: 10)),
                color: Colors.grey[700],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Botón para detener completamente el audio
          TextButton.icon(
            onPressed: () {
              navigatorKey.currentState?.pop();
              _stop();
            },
            icon: const Icon(Icons.stop, color: Colors.red),
            label: const Text(
              'Detener audio',
              style: TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      ),
        );
      },
    );
  }
}
