import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';

/// Canonical avatar: profile photo when available, deterministic
/// initial-based fallback otherwise. Never crashes on missing URLs.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 26,
    this.heroTag,
    this.fontSize,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Object? heroTag;
  final double? fontSize;

  /// Initials derived from a display name ("Alex Thomas" -> "AT").
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasPhoto = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor:
          hasPhoto ? AppColors.surfaceVariant : AppColors.avatarFor(name),
      backgroundImage:
          hasPhoto ? NetworkImage(imageUrl!.trim()) : null,
      onBackgroundImageError: hasPhoto ? (_, _) {} : null,
      child: hasPhoto
          ? null
          : Text(
              initialsOf(name),
              style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: fontSize,
              ),
            ),
    );
    final labeled = Semantics(
      label: 'Avatar for $name',
      image: true,
      child: avatar,
    );
    if (heroTag == null) return labeled;
    return Hero(tag: heroTag!, child: labeled);
  }
}
