import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/core/utils/elevation_helper.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'dart:math' as math;

/// Widget que muestra un gráfico de elevación para una ruta
class ElevationChart extends StatelessWidget {
  final List<ElevationPoint> points;
  final double height;
  
  const ElevationChart({
    super.key,
    required this.points,
    this.height = 200,
  });
  
  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocaleProvider>(context);
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(loc.translate('elevation_no_data')),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            loc.translate('elevation_profile'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Gráfico
        Container(
          height: height,
          padding: const EdgeInsets.all(16),
          child: CustomPaint(
            painter: _ElevationChartPainter(points),
            child: Container(),
          ),
        ),
        
        // Leyenda de distancia
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 km',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${(calculateRouteStats(points).totalDistance / 2).toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${calculateRouteStats(points).totalDistance.toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Painter personalizado para dibujar el gráfico de elevación
class _ElevationChartPainter extends CustomPainter {
  final List<ElevationPoint> points;
  
  _ElevationChartPainter(this.points);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    // Simplificar puntos para mejor rendimiento en rutas largas
    final simplifiedPoints = simplifyPoints(points, maxPoints: 500);
    
    // Encontrar min y max elevación (usar puntos originales para stats precisos)
    final elevations = points.map((p) => p.elevation).toList();
    final minElev = elevations.reduce(math.min);
    final maxElev = elevations.reduce(math.max);
    final elevRange = maxElev - minElev;
    
    // Añadir padding vertical (10% arriba y abajo)
    final padding = elevRange * 0.1;
    final adjustedMin = minElev - padding;
    final adjustedMax = maxElev + padding;
    final adjustedRange = adjustedMax - adjustedMin;
    
    if (adjustedRange == 0) return;
    
    // Crear path para el área bajo la curva (usar puntos simplificados)
    final path = Path();
    final linePath = Path();
    
    for (int i = 0; i < simplifiedPoints.length; i++) {
      final x = (i / (simplifiedPoints.length - 1)) * size.width;
      final normalizedElev = (simplifiedPoints[i].elevation - adjustedMin) / adjustedRange;
      final y = size.height - (normalizedElev * size.height);
      
      if (i == 0) {
        path.moveTo(x, size.height);
        path.lineTo(x, y);
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
        path.lineTo(x, y);
      }
    }
    
    // Cerrar el path del área
    path.lineTo(size.width, size.height);
    path.close();
    
    // Dibujar gradiente para el área
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.blue.withOpacity(0.4),
        Colors.blue.withOpacity(0.1),
      ],
    );
    
    final areaPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, areaPaint);
    
    // Dibujar línea de elevación con colores según pendiente (usar puntos simplificados)
    final segments = createRouteSegments(simplifiedPoints);
    
    for (int i = 0; i < segments.length; i++) {
      final x1 = (i / (simplifiedPoints.length - 1)) * size.width;
      final x2 = ((i + 1) / (simplifiedPoints.length - 1)) * size.width;
      
      final normalizedElev1 = (simplifiedPoints[i].elevation - adjustedMin) / adjustedRange;
      final normalizedElev2 = (simplifiedPoints[i + 1].elevation - adjustedMin) / adjustedRange;
      
      final y1 = size.height - (normalizedElev1 * size.height);
      final y2 = size.height - (normalizedElev2 * size.height);
      
      final segmentPaint = Paint()
        ..color = getSlopeColor(segments[i].slope)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), segmentPaint);
    }
    
    // Dibujar líneas de grid horizontales
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    
    for (int i = 0; i <= 4; i++) {
      final y = (i / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    // Dibujar etiquetas de elevación
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    for (int i = 0; i <= 4; i++) {
      final elev = adjustedMax - (i / 4) * adjustedRange;
      final y = (i / 4) * size.height;
      
      textPainter.text = TextSpan(
        text: '${elev.toStringAsFixed(0)}m',
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 10,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - 6));
    }
  }
  
  @override
  bool shouldRepaint(_ElevationChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
