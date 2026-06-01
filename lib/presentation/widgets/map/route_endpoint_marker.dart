import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteEndpointMarker extends Marker {
  RouteEndpointMarker({
    required LatLng position,
    bool isStart = true,
    VoidCallback? onTap,
  }) : super(
         point: position,
         width: 44,
         height: 44,
         child: GestureDetector(
           onTap: onTap,
           child: Container(
             width: 44,
             height: 44,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               color: isStart ? Colors.green.shade600 : Colors.red,
               border: Border.all(color: Colors.white, width: 2.5),
               boxShadow: const [
                 BoxShadow(
                   color: Colors.black26,
                   blurRadius: 6,
                   offset: Offset(0, 2),
                 ),
               ],
             ),
             child: Icon(
               isStart ? Icons.play_arrow_rounded : Icons.flag_rounded,
               size: 22,
               color: Colors.white,
             ),
           ),
         ),
       );
}
