import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A widget that handles image loading on web with CORS issues.
/// Falls back to Image.network if CachedNetworkImage fails on web.
class WebSafeImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Map<String, String>? httpHeaders;

  const WebSafeImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.httpHeaders,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // On web, try Image.network first as it sometimes handles CORS better
      // when CORS isn't fully configured
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        headers: httpHeaders,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        },
        errorBuilder: (context, error, stackTrace) {
          // Fallback to CachedNetworkImage if Image.network fails
          return _buildCachedNetworkImage();
        },
      );
    } else {
      // On mobile, use CachedNetworkImage
      return _buildCachedNetworkImage();
    }
  }

  Widget _buildCachedNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      httpHeaders: httpHeaders,
      placeholder: (context, url) {
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
      },
      errorWidget: (context, url, error) {
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
      },
    );
  }
}
