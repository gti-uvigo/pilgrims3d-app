import 'package:flutter/material.dart';
import 'package:pilgrims_3d/services/tts/tts_service.dart';

class HighlightedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TTSService ttsService;

  const HighlightedText({
    super.key,
    required this.text,
    required this.style,
    required this.ttsService,
  });

  @override
  State<HighlightedText> createState() => _HighlightedTextState();
}

class _HighlightedTextState extends State<HighlightedText> {
  int _currentStart = -1;
  int _currentEnd = -1;

  void _onProgress(String word, int start, int end) {
    if (mounted) {
      setState(() {
        _currentStart = start;
        _currentEnd = end;
      });
    }
  }

  void _onCompleteOrStop() {
    if (mounted) {
      setState(() {
        _currentStart = -1;
        _currentEnd = -1;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.ttsService.addOnProgressListener(_onProgress);
    widget.ttsService.addOnCompleteListener(_onCompleteOrStop);
    widget.ttsService.addOnStopListener(_onCompleteOrStop);
  }

  @override
  void dispose() {
    widget.ttsService.removeOnProgressListener(_onProgress);
    widget.ttsService.removeOnCompleteListener(_onCompleteOrStop);
    widget.ttsService.removeOnStopListener(_onCompleteOrStop);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay progreso o no está reproduciendo, mostrar texto normal
    if (_currentStart == -1 ||
        _currentEnd == -1 ||
        !widget.ttsService.isPlaying) {
      return Text(widget.text, style: widget.style);
    }

    final text = widget.text;
    final spans = <TextSpan>[];

    // Parte ya leída (en verde claro)
    if (_currentStart > 0) {
      spans.add(
        TextSpan(
          text: text.substring(0, _currentStart),
          style: widget.style.copyWith(color: Colors.green.shade900),
        ),
      );
    }

    // Parte que se está leyendo ahora (en verde oscuro y negrita)
    if (_currentStart < text.length && _currentEnd <= text.length) {
      spans.add(
        TextSpan(
          text: text.substring(_currentStart, _currentEnd),
          style: widget.style.copyWith(
            color: Colors.green.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Parte que aún no se ha leído (color original)
    if (_currentEnd < text.length) {
      spans.add(
        TextSpan(text: text.substring(_currentEnd), style: widget.style),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}
