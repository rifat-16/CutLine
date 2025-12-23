import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UserLocationPickerBar extends StatelessWidget {
  const UserLocationPickerBar({
    super.key,
    required this.label,
    required this.onTap,
    this.isBusy = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isBusy ? null : onTap,
      borderRadius: BorderRadius.circular(30.r),
      child: Container(
        height: 54.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30.r),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: CutlineColors.primary),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CutlineTextStyles.body,
              ),
            ),
            if (isBusy) ...[
              SizedBox(width: 10.w),
              SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else ...[
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.black45),
            ],
          ],
        ),
      ),
    );
  }
}

