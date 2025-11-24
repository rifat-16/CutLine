import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NearbySalonCard extends StatelessWidget {
  final String salonName;
  final VoidCallback onTap;

  const NearbySalonCard({super.key, required this.salonName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CutlineDecorations.radius),
      child: Container(
        decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
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
                  child: Center(
                    child: Text('Cover Image Area', style: CutlineTextStyles.subtitle),
                  ),
                ),
                Positioned(
                  right: 12.w,
                  top: 12.h,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: EdgeInsets.all(4.r),
                    child: const Icon(Icons.favorite_border, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: 16.w,
                  bottom: 16.h,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salonName,
                        style: CutlineTextStyles.title.copyWith(color: Colors.white),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.star, size: 16, color: CutlineColors.accent),
                          SizedBox(width: 4),
                          Text('4.6 (120)', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ],
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
                          'Banani, Dhaka • 0.8 km away',
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
                      Text('Wait time: 10 mins  •  ', style: CutlineTextStyles.body),
                      Text('Open Now',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  const Text('Top Services: Haircut, Beard Trim, Facial',
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
