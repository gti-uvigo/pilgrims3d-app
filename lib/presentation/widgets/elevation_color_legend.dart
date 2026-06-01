import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pilgrims_3d/core/utils/elevation_helper.dart';
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';

/// Widget compacto que muestra la leyenda de colores de pendiente con diseño moderno
class ElevationColorLegend extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onToggle;
  
  const ElevationColorLegend({
    super.key,
    this.isExpanded = false,
    this.onToggle,
  });
  
  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocaleProvider>(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85), // Más transparente
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header elegante y compacto
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.terrain_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      loc.translate('slope'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (onToggle != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
                
                if (isExpanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 0.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Legend items con diseño mejorado y más compactos
                  _buildLegendItem(
                    context,
                    icon: Icons.arrow_upward_rounded,
                    label: loc.translate('steep_uphill'),
                    color: getSlopeColor(12),
                    value: '>10%',
                  ),
                  const SizedBox(height: 4),
                  _buildLegendItem(
                    context,
                    icon: Icons.trending_up_rounded,
                    label: loc.translate('uphill'),
                    color: getSlopeColor(5),
                    value: '2-10%',
                  ),
                  const SizedBox(height: 4),
                  _buildLegendItem(
                    context,
                    icon: Icons.horizontal_rule_rounded,
                    label: loc.translate('flat'),
                    color: getSlopeColor(0),
                    value: '±2%',
                  ),
                  const SizedBox(height: 4),
                  _buildLegendItem(
                    context,
                    icon: Icons.trending_down_rounded,
                    label: loc.translate('downhill'),
                    color: getSlopeColor(-5),
                    value: '-2 a -10%',
                  ),
                  const SizedBox(height: 4),
                  _buildLegendItem(
                    context,
                    icon: Icons.arrow_downward_rounded,
                    label: loc.translate('steep_downhill'),
                    color: getSlopeColor(-12),
                    value: '<-10%',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withOpacity(0.8)),
          const SizedBox(width: 5),
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget que puede ser posicionado en el mapa con animación
class MapElevationLegend extends StatefulWidget {
  const MapElevationLegend({super.key});
  
  @override
  State<MapElevationLegend> createState() => _MapElevationLegendState();
}

class _MapElevationLegendState extends State<MapElevationLegend> 
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true; // Empieza expandida para mostrar info inmediatamente
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward(); // Inicia la animación
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80, // Más abajo para no tapar botones superiores
      left: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ElevationColorLegend(
          isExpanded: _isExpanded,
          onToggle: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
        ),
      ),
    );
  }
}
