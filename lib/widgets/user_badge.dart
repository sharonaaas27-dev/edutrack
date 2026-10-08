import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/models/user.dart';

/// Small identity pill: display name + role. Used in dashboard headers so
/// the signed-in account is always visible (never hard-coded).
class UserBadge extends StatelessWidget {
  const UserBadge({
    super.key,
    required this.displayName,
    required this.role,
    this.onDarkBackground = false,
  });

  final String displayName;
  final UserRole role;
  final bool onDarkBackground;

  /// Derives a friendly name: linked student record preferred, otherwise
  /// the email local-part capitalized.
  static String nameFor(UserModel? user, String? linkedStudentName) {
    if (linkedStudentName != null && linkedStudentName.isNotEmpty) {
      return linkedStudentName.split(' ').first;
    }
    final email = user?.email ?? '';
    final local = email.split('@').first;
    if (local.isEmpty) return 'there';
    return local[0].toUpperCase() + local.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fg = onDarkBackground ? Colors.white : AppColors.primaryDark;
    final bg = onDarkBackground
        ? Colors.white.withValues(alpha: 0.16)
        : AppColors.primaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        '$displayName · Role: ${role.label}',
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
