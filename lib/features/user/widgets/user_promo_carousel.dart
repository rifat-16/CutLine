import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UserPromoCarousel extends StatelessWidget {
  final List<String> offers;
  final PageController controller;
  final ValueChanged<int> onChanged;

  const UserPromoCarousel({
    super.key,
    required this.offers,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: SizedBox(
        height: 140.h,
        child: PageView.builder(
          controller: controller,
          onPageChanged: onChanged,
          itemCount: offers.length + 2,
          itemBuilder: (context, index) {
            final int realIndex;
            if (index == 0) {
              realIndex = offers.length - 1;
            } else if (index == offers.length + 1) {
              realIndex = 0;
            } else {
              realIndex = index - 1;
            }
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CutlineColors.primary.withValues(alpha: 0.7),
                    CutlineColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  offers[realIndex],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
