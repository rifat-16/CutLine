import 'package:cutline/features/owner/providers/salon_setup_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SalonPhotoManager extends StatelessWidget {
  const SalonPhotoManager({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _CoverUploadCard(),
        SizedBox(height: 20),
        _GalleryHeader(),
        SizedBox(height: 12),
        _GalleryUploadField(),
      ],
    );
  }
}

class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader();

  @override
  Widget build(BuildContext context) {
    return const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold));
  }
}

class _CoverUploadCard extends StatelessWidget {
  const _CoverUploadCard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalonSetupProvider>();
    final coverUrl = provider.coverPhotoUrl;
    final isUploading = provider.isUploadingCover;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrl != null)
                  Image.network(coverUrl, fit: BoxFit.cover)
                else
                  const Icon(Icons.image_outlined,
                      color: Colors.white, size: 36),
                if (isUploading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                        child:
                            CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cover Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'High-quality cover boosts bookings by 42%.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed:
                      isUploading ? null : () => provider.uploadCoverPhoto(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.upload),
                  label: Text(isUploading ? 'Uploading...' : 'Upload cover'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryUploadField extends StatelessWidget {
  const _GalleryUploadField();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalonSetupProvider>();
    final isUploading = provider.isUploadingGallery;
    final photos = provider.galleryUrls;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
        color: Colors.blueAccent.withValues(alpha: 0.04),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload_outlined,
                  color: Colors.blueAccent.shade200, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Drop or select multiple gallery photos',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${photos.length}/10',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Max 10 files • JPG/PNG • 1200x800 recommended',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final url in photos)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(url,
                          width: 80, height: 80, fit: BoxFit.cover),
                    ],
                  ),
                ),
              if (photos.length < 10)
                OutlinedButton.icon(
                  onPressed:
                      isUploading ? null : () => provider.uploadGalleryPhotos(),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label:
                      Text(isUploading ? 'Uploading...' : 'Upload gallery'),
                ),
              if (isUploading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
