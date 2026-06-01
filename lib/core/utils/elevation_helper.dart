import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Clase para representar un punto con elevación
class ElevationPoint {
  final LatLng position;
  final double elevation;
  
  ElevationPoint(this.position, this.elevation);
  
  factory ElevationPoint.fromList(List coords) {
    // coords: [longitude, latitude, elevation]
    return ElevationPoint(
      LatLng(coords[1], coords[0]),
      coords.length > 2 ? coords[2].toDouble() : 0.0,
    );
  }
}

/// Clase para representar un segmento de ruta con pendiente
class RouteSegment {
  final LatLng start;
  final LatLng end;
  final double slope; // Pendiente en porcentaje
  final double distance; // Distancia en metros
  final double elevationGain; // Ganancia de elevación en metros
  
  RouteSegment({
    required this.start,
    required this.end,
    required this.slope,
    required this.distance,
    required this.elevationGain,
  });
}

/// Clase con estadísticas de la ruta
class RouteStats {
  final double totalDistance; // km
  final double totalElevationGain; // m
  final double totalElevationLoss; // m
  final double maxElevation; // m
  final double minElevation; // m
  final double avgSlope; // %
  final double maxSlope; // %
  
  RouteStats({
    required this.totalDistance,
    required this.totalElevationGain,
    required this.totalElevationLoss,
    required this.maxElevation,
    required this.minElevation,
    required this.avgSlope,
    required this.maxSlope,
  });
}

/// Calcula la pendiente entre dos puntos
/// Retorna la pendiente en porcentaje
double calculateSlope(ElevationPoint p1, ElevationPoint p2) {
  final distance = const Distance();
  final horizontalDistance = distance.as(
    LengthUnit.Meter,
    p1.position,
    p2.position,
  );
  
  if (horizontalDistance == 0) return 0;
  
  final elevationDiff = p2.elevation - p1.elevation;
  return (elevationDiff / horizontalDistance) * 100;
}

/// Convierte una lista de puntos con elevación a segmentos
List<RouteSegment> createRouteSegments(List<ElevationPoint> points) {
  if (points.length < 2) return [];
  
  final segments = <RouteSegment>[];
  final distance = const Distance();
  
  for (int i = 0; i < points.length - 1; i++) {
    final p1 = points[i];
    final p2 = points[i + 1];
    
    final dist = distance.as(LengthUnit.Meter, p1.position, p2.position);
    final slope = calculateSlope(p1, p2);
    final elevGain = p2.elevation - p1.elevation;
    
    segments.add(RouteSegment(
      start: p1.position,
      end: p2.position,
      slope: slope,
      distance: dist,
      elevationGain: elevGain,
    ));
  }
  
  return segments;
}

/// Calcula las estadísticas de una ruta
RouteStats calculateRouteStats(List<ElevationPoint> points) {
  if (points.isEmpty) {
    return RouteStats(
      totalDistance: 0,
      totalElevationGain: 0,
      totalElevationLoss: 0,
      maxElevation: 0,
      minElevation: 0,
      avgSlope: 0,
      maxSlope: 0,
    );
  }
  
  final segments = createRouteSegments(points);
  
  double totalDist = 0;
  double totalGain = 0;
  double totalLoss = 0;
  double maxSlope = 0;
  double totalSlopeWeighted = 0;
  
  // Umbral mínimo de distancia para considerar un segmento válido (5 metros)
  const minDistanceThreshold = 5.0;
  
  for (var segment in segments) {
    totalDist += segment.distance;
    
    if (segment.elevationGain > 0) {
      totalGain += segment.elevationGain;
    } else {
      totalLoss += segment.elevationGain.abs();
    }
    
    // Solo considerar pendientes de segmentos suficientemente largos
    // para evitar valores extremos por errores GPS
    if (segment.distance >= minDistanceThreshold) {
      // Limitar pendiente a valores razonables (±50% es muy empinado)
      // Valores mayores son probablemente errores de medición
      final clampedSlope = segment.slope.clamp(-50.0, 50.0);
      
      if (clampedSlope.abs() > maxSlope.abs()) {
        maxSlope = clampedSlope;
      }
      
      totalSlopeWeighted += clampedSlope.abs() * segment.distance;
    }
  }
  
  final elevations = points.map((p) => p.elevation).toList();
  final maxElev = elevations.reduce(math.max);
  final minElev = elevations.reduce(math.min);
  final avgSlope = totalDist > 0 ? totalSlopeWeighted / totalDist : 0.0;
  
  return RouteStats(
    totalDistance: totalDist / 1000, // Convertir a km
    totalElevationGain: totalGain,
    totalElevationLoss: totalLoss,
    maxElevation: maxElev,
    minElevation: minElev,
    avgSlope: avgSlope,
    maxSlope: maxSlope,
  );
}

/// Retorna un color basado en la pendiente (5 categorías simplificadas)
/// Pendientes positivas (subida): naranja -> rojo
/// Pendientes negativas (bajada): verde -> azul
/// Plano: verde claro
Color getSlopeColor(double slopePercent) {
  if (slopePercent >= 10) {
    // Mucha subida - rojo
    return const Color(0xFFE53935);
  } else if (slopePercent >= 2) {
    // Subida - naranja/amarillo
    return const Color(0xFFFF9800);
  } else if (slopePercent >= -2) {
    // Plano - verde claro
    return const Color(0xFF66BB6A);
  } else if (slopePercent >= -10) {
    // Bajada - verde oscuro/azul
    return const Color(0xFF00897B);
  } else {
    // Mucha bajada - azul
    return const Color(0xFF1E88E5);
  }
}

/// Obtiene una descripción textual de la pendiente (5 categorías simplificadas)
String getSlopeDescription(double slopePercent) {
  if (slopePercent >= 10) {
    return 'Mucha subida ↗️';
  } else if (slopePercent >= 2) {
    return 'Subida ⤴';
  } else if (slopePercent >= -2) {
    return 'Plano →';
  } else if (slopePercent >= -10) {
    return 'Bajada ⤵';
  } else {
    return 'Mucha bajada ↘️';
  }
}

/// Simplifica una lista de puntos reduciendo la cantidad manteniendo la forma
/// Usa decimation simple: toma 1 de cada N puntos
/// Para rutas con más de maxPoints, reduce la densidad
List<ElevationPoint> simplifyPoints(List<ElevationPoint> points, {int maxPoints = 500}) {
  if (points.length <= maxPoints) {
    return points;
  }
  
  // Calcular el factor de reducción
  final step = (points.length / maxPoints).ceil();
  final simplified = <ElevationPoint>[];
  
  // Siempre incluir el primer punto
  simplified.add(points.first);
  
  // Tomar puntos con el paso calculado
  for (int i = step; i < points.length - 1; i += step) {
    simplified.add(points[i]);
  }
  
  // Siempre incluir el último punto
  if (simplified.last != points.last) {
    simplified.add(points.last);
  }
  
  return simplified;
}
