import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';

/// Reusable error state: icon, title, server-safe message, retry action.
/// Never surfaces stack traces or raw backend payloads.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Try Again',
    this.icon = Icons.cloud_off_outlined,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtle pulsing placeholder block for skeleton loading lists.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    super.key,
    this.height = 104,
    this.borderRadius = AppSpacing.radiusLg,
  });

  final double height;
  final double borderRadius;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.45, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton list used while first-page data loads. Announced politely to
/// screen readers instead of leaving a blank spinner.
class AppLoadingSkeleton extends StatelessWidget {
  const AppLoadingSkeleton({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 104,
    this.padding = const EdgeInsets.all(AppSpacing.screenPadding),
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading content',
      child: ListView.separated(
        padding: padding,
        itemCount: itemCount,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, _) => SkeletonBlock(height: itemHeight),
      ),
    );
  }
}
