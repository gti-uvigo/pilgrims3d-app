import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pilgrims_3d/services/offline/image_cache_service.dart';

/// Widget que muestra una imagen desde el caché offline si está disponible,
/// o desde la red si no lo está
class OfflineCachedImage extends StatefulWidget {
  final String imageUrl;
  final String imageId;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  const OfflineCachedImage({
    super.key,
    required this.imageUrl,
    required this.imageId,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<OfflineCachedImage> createState() => _OfflineCachedImageState();
}

class _OfflineCachedImageState extends State<OfflineCachedImage> {
  late Future<File?> _cachedImageFuture;

  @override
  void initState() {
    super.initState();
    // Cachear el Future para evitar múltiples llamadas
    if (!kIsWeb) {
      _cachedImageFuture = ImageCacheService().getCachedImage(widget.imageId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // En web, usar directamente CachedNetworkImage sin verificar caché local
    if (kIsWeb) {
      return _buildNetworkImage();
    }

    // En apps nativas, verificar primero el caché local
    return FutureBuilder<File?>(
      future: _cachedImageFuture,
      builder: (context, snapshot) {
        // Si ya tenemos el archivo en caché local, mostrarlo
        if (snapshot.connectionState == ConnectionState.done && 
            snapshot.hasData && 
            snapshot.data != null) {
          // Si no hay width/height definidos, usar SizedBox.expand
          if (widget.width == null && widget.height == null) {
            return SizedBox.expand(
              child: Image.file(
                snapshot.data!,
                fit: widget.fit ?? BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error cargando imagen desde archivo local: $error');
                  return _buildNetworkImage();
                },
              ),
            );
          }
          
          return Image.file(
            snapshot.data!,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error cargando imagen desde archivo local: $error');
              return _buildNetworkImage();
            },
          );
        }

        // Si no está en caché local, cargar desde red con CachedNetworkImage
        if (snapshot.connectionState == ConnectionState.done) {
          return _buildNetworkImage();
        }

        // Mientras se verifica el caché, mostrar placeholder
        if (widget.placeholder != null) {
          return widget.placeholder!(context, widget.imageUrl);
        }
        
        // Si no hay width/height y no hay placeholder custom, usar SizedBox.expand
        if (widget.width == null && widget.height == null) {
          return SizedBox.expand(
            child: Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        
        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: widget.placeholder,
      errorWidget: widget.errorWidget,
    );
  }
}
