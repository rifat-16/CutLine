import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class SalonGalleryScreen extends StatelessWidget {
  final String salonName;
  final int uploadedCount;
  final int totalLimit;
  final List<String> photos;

  const SalonGalleryScreen({
    super.key,
    required this.salonName,
    this.uploadedCount = 0,
    this.totalLimit = 10,
    this.photos = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CutlineAppBar(
        title: '$salonName Gallery',
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$uploadedCount / $totalLimit', style: CutlineTextStyles.subtitleBold.copyWith(color: CutlineColors.primary)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 500)),
        child: photos.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: CutlineSpacing.section.copyWith(top: 24, bottom: 24),
                children: [
                  Container(
                    height: 220,
                    decoration: CutlineDecorations.card(
                      colors: [CutlineColors.primary.withValues(alpha: 0.08), Colors.white],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 48, color: CutlineColors.primary),
                          const SizedBox(height: 12),
                          Text(
                            'No gallery photos yet',
                            style: CutlineTextStyles.title.copyWith(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Images will appear here after the next update.',
                            style: CutlineTextStyles.subtitle,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : GridView.builder(
                padding: CutlineSpacing.section.copyWith(top: 24, bottom: 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final url = photos[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(CutlineDecorations.radius),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
