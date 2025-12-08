import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/gallery_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ManageGalleryScreen extends StatelessWidget {
  const ManageGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = GalleryProvider(
          authProvider: context.read<AuthProvider>(),
        );
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<GalleryProvider>();
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: AppBar(
            title: const Text('Manage Gallery'),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(
                  provider.isEditMode ? Icons.check : Icons.edit,
                  color: provider.isEditMode ? Colors.green : Colors.blue,
                ),
                onPressed: () => provider.toggleEditMode(),
                tooltip: provider.isEditMode ? 'Done' : 'Edit',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.load(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Cover photo section
                _CoverPhotoSection(provider: provider),
                const SizedBox(height: 24),
                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Upload up to 10 photos to showcase your salon',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
          
                // Gallery grid
                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: provider.galleryUrls.length + 1,
                  itemBuilder: (context, index) {
                    if (index == provider.galleryUrls.length) {
                      // Add photo button
                      return _AddPhotoButton(
                        onTap: provider.isUploadingGallery
                            ? null
                            : () => provider.uploadGalleryPhotos(),
                        isUploading: provider.isUploadingGallery,
                      );
                    }
                    // Photo item
                    return _GalleryPhotoItem(
                      imageUrl: provider.galleryUrls[index],
                      isEditMode: provider.isEditMode,
                      onTap: provider.isEditMode && !provider.isUploadingGallery
                          ? () => provider.changeGalleryPhoto(index)
                          : null,
                      isUploading: provider.isUploadingGallery,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoverPhotoSection extends StatelessWidget {
  final GalleryProvider provider;

  const _CoverPhotoSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cover Photo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 2,
            ),
            color: Colors.grey.shade100,
          ),
          child: provider.coverPhotoUrl != null &&
                  provider.coverPhotoUrl!.isNotEmpty
              ? InkWell(
                  onTap: provider.isEditMode && !provider.isUploadingCover
                      ? () => provider.changeCoverPhoto()
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          provider.coverPhotoUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _CoverPlaceholder(),
                        ),
                      ),
                      if (provider.isEditMode)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.black.withValues(alpha: 0.3),
                          ),
                          child: Center(
                            child: provider.isUploadingCover
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to change',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                    ],
                  ),
                )
              : InkWell(
                  onTap: provider.isUploadingCover
                      ? null
                      : () => provider.uploadCoverPhoto(),
                  borderRadius: BorderRadius.circular(14),
                  child: provider.isUploadingCover
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : _CoverPlaceholder(),
                ),
        ),
        if (provider.coverPhotoUrl == null ||
            provider.coverPhotoUrl!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Upload a cover photo for your salon (Recommended: 1200x600)',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 8),
        Text(
          'Upload Cover Photo',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isUploading;

  const _AddPhotoButton({
    this.onTap,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: isUploading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: Colors.blue.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add Photo',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GalleryPhotoItem extends StatelessWidget {
  final String? imageUrl;
  final bool isEditMode;
  final VoidCallback? onTap;
  final bool isUploading;

  const _GalleryPhotoItem({
    required this.imageUrl,
    this.isEditMode = false,
    this.onTap,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _PlaceholderPhoto(),
                  )
                : _PlaceholderPhoto(),
          ),
          if (isEditMode)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: Center(
                child: isUploading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Change',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceholderPhoto extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}

