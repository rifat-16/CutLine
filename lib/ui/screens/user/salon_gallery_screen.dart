import 'package:cutline/ui/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class SalonGalleryScreen extends StatelessWidget {
  final String salonName;
  final int uploadedCount;
  final int totalLimit;

  const SalonGalleryScreen({super.key, required this.salonName, this.uploadedCount = 7, this.totalLimit = 10});

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
        onRefresh: () async => Future<void>.delayed(const Duration(seconds: 1)),
        child: GridView.builder(
          padding: CutlineSpacing.section.copyWith(top: 16, bottom: 16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: uploadedCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemBuilder: (context, index) {
            final imagePath = 'assets/images/salon_${(index % 4) + 1}.jpg';
            return CutlineAnimations.staggeredList(
              index: index,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(imagePath, fit: BoxFit.cover),
              ),
            );
          },
        ),
      ),
    );
  }
}
