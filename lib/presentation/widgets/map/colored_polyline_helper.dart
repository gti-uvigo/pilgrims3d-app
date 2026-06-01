import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pilgrims_3d/core/utils/elevation_helper.dart';

/// Genera polylines con colores graduados basados en la pendiente
/// Retorna una lista de polylines, cada uno con un color según su pendiente
List<Polyline> createColoredPolylines(
  List<ElevationPoint> elevationPoints, {
  double strokeWidth = 5,
}) {
  if (elevationPoints.length < 2) return [];
  
  final segments = createRouteSegments(elevationPoints);
  final polylines = <Polyline>[];
  
  for (int i = 0; i < segments.length; i++) {
    final segment = segments[i];
    final color = getSlopeColor(segment.slope);
    
    polylines.add(
      Polyline(
        points: [segment.start, segment.end],
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
  
  return polylines;
}

/// Genera polylines agrupados por rangos de color para mejorar rendimiento
/// En lugar de crear un polyline por cada segmento, agrupa segmentos consecutivos
/// con el mismo color
List<Polyline> createOptimizedColoredPolylines(
  List<ElevationPoint> elevationPoints, {
  double strokeWidth = 5,
}) {
  if (elevationPoints.length < 2) return [];
  
  final segments = createRouteSegments(elevationPoints);
  final polylines = <Polyline>[];
  
  List<ElevationPoint> currentSegmentPoints = [elevationPoints[0]];
  Color? currentColor;
  
  for (int i = 0; i < segments.length; i++) {
    final segment = segments[i];
    final color = getSlopeColor(segment.slope);
    
    if (currentColor == null) {
      currentColor = color;
      currentSegmentPoints.add(elevationPoints[i + 1]);
    } else if (currentColor == color) {
      // Mismo color, agregar al segmento actual
      currentSegmentPoints.add(elevationPoints[i + 1]);
    } else {
      // Color diferente, crear polyline para el segmento acumulado
      polylines.add(
        Polyline(
          points: currentSegmentPoints.map((p) => p.position).toList(),
          color: currentColor,
          strokeWidth: strokeWidth,
        ),
      );
      
      // Iniciar nuevo segmento
      currentSegmentPoints = [elevationPoints[i], elevationPoints[i + 1]];
      currentColor = color;
    }
  }
  
  // Agregar el último segmento
  if (currentSegmentPoints.length > 1 && currentColor != null) {
    polylines.add(
      Polyline(
        points: currentSegmentPoints.map((p) => p.position).toList(),
        color: currentColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
  
  return polylines;
}

/// Crea un polyline simple sin colores de pendiente (fallback)
Polyline createSimplePolyline(
  List<ElevationPoint> elevationPoints, {
  Color color = Colors.red,
  double strokeWidth = 5,
}) {
  return Polyline(
    points: elevationPoints.map((p) => p.position).toList(),
    color: color,
    strokeWidth: strokeWidth,
  );
}
