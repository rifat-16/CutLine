import 'package:flutter/material.dart';

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
            child:
                const Icon(Icons.image_outlined, color: Colors.white, size: 36),
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
                  onPressed: () => _showComingSoon(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.upload),
                  label: const Text('Upload cover'),
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
    return InkWell(
      onTap: () => _showComingSoon(context),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
          color: Colors.blueAccent.withValues(alpha: 0.04),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined,
                color: Colors.blueAccent.shade200, size: 36),
            const SizedBox(height: 10),
            const Text(
              'Drop or select multiple gallery photos',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Max 10 files • JPG/PNG • 1200x800 recommended',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _showComingSoon(context),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Upload gallery'),
            ),
          ],
        ),
      ),
    );
  }
}

void _showComingSoon(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Photos coming soon'),
      content: const Text(
        'Photo uploads will be available in a future update. Please skip for now.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
