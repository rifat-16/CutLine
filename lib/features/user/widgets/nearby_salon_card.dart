import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:cutline/shared/widgets/web_safe_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NearbySalonCard extends StatelessWidget {
  final String salonName;
  final String location;
  final String distanceLabel;
  final int waitMinutes;
  final bool isOpen;
  final bool isFavorite;
  final List<String> topServices;
  final VoidCallback onTap;
  final String? coverImageUrl;

  const NearbySalonCard({
    super.key,
    required this.salonName,
    required this.location,
    required this.distanceLabel,
    required this.waitMinutes,
    required this.isOpen,
    this.isFavorite = false,
    required this.topServices,
    required this.onTap,
    this.coverImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final waitLabel = waitMinutes <= 0 ? 'No wait' : '$waitMinutes mins';
    final servicesLabel = topServices.isEmpty
        ? 'Popular services will appear here'
        : topServices.join(', ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CutlineDecorations.radius),
      child: Container(
        decoration:
            CutlineDecorations.card(solidColor: CutlineColors.background),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 200.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(CutlineDecorations.radius),
                      topRight: Radius.circular(CutlineDecorations.radius),
                    ),
                    color: Colors.grey.shade300,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: coverImageUrl != null && coverImageUrl!.isNotEmpty
                      ? WebSafeImage(
                          imageUrl: coverImageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: _placeholder(),
                        )
                      : _placeholder(),
                ),
                Positioned(
                  right: 12.w,
                  top: 12.h,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? Colors.redAccent.withValues(alpha: 0.9)
                          : Colors.black38,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: EdgeInsets.all(4.r),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(CutlineDecorations.radius),
                        bottomRight: Radius.circular(CutlineDecorations.radius),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.06),
                          Colors.black.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          salonName,
                          style: CutlineTextStyles.title.copyWith(
                            color: Colors.white,
                            fontSize: 24,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 6,
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          '$location • $distanceLabel',
                          style: CutlineTextStyles.body,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      SizedBox(width: 4.w),
                      Text('Wait time: $waitLabel  •  ',
                          style: CutlineTextStyles.body),
                      Text(
                        isOpen ? 'Open Now' : 'Closed',
                        style: TextStyle(
                          color: isOpen ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text('Top Services: $servicesLabel',
                      style: CutlineTextStyles.subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _placeholder() {
  return Center(
    child: Text(
      'Cover image will appear after the next update',
      style: CutlineTextStyles.subtitle,
      textAlign: TextAlign.center,
    ),
  );
}
