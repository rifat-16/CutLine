import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A reusable widget for displaying profile images that works on both mobile and web.
/// Uses CachedNetworkImage to handle CORS issues on web platforms.
class CachedProfileImage extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedProfileImage({
    super.key,
    this.imageUrl,
    required this.radius,
    this.backgroundColor,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[300],
        child: errorWidget ?? const Icon(Icons.person, color: Colors.grey),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        httpHeaders: kIsWeb ? {'Access-Control-Allow-Origin': '*'} : null,
        placeholder: (context, url) {
          return Container(
            width: radius * 2,
            height: radius * 2,
            color: backgroundColor ?? Colors.grey[300],
            child: placeholder ??
                const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          );
        },
        errorWidget: (context, url, error) {
          return Container(
            width: radius * 2,
            height: radius * 2,
            color: backgroundColor ?? Colors.grey[300],
            child: errorWidget ?? const Icon(Icons.person, color: Colors.grey),
          );
        },
      ),
    );
  }
}
