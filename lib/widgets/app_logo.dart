import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';

/// Minimal Flutter-built logo communicating education + technology.
/// No external image assets required.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = AppSpacing.logoSize});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'EduTrack logo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.school_rounded,
              size: size * 0.52,
              color: Colors.white,
              semanticLabel: 'Graduation cap',
            ),
            Positioned(
              right: size * 0.16,
              bottom: size * 0.16,
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(size * 0.07),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: size * 0.16,
                  color: AppColors.primary,
                  semanticLabel: 'Technology bolt',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
