import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_spacing.dart';

/// Centralized responsive breakpoints (logical pixels).
///
/// Mobile < 600 < Tablet < 1024 < Desktop. Screens must read these through
/// the helpers below instead of hard-coding widths.
abstract final class AppBreakpoints {
  static const double tablet = 600;
  static const double desktop = 1024;

  /// Compact stat-grid breakpoint used inside constrained content.
  static const double wideContent = 560;
}

enum AppScreenSize { mobile, tablet, desktop }

extension ResponsiveContext on BuildContext {
  AppScreenSize get screenSize {
    final width = MediaQuery.widthOf(this);
    if (width >= AppBreakpoints.desktop) return AppScreenSize.desktop;
    if (width >= AppBreakpoints.tablet) return AppScreenSize.tablet;
    return AppScreenSize.mobile;
  }

  bool get isMobile => screenSize == AppScreenSize.mobile;
  bool get isTablet => screenSize == AppScreenSize.tablet;
  bool get isDesktop => screenSize == AppScreenSize.desktop;
}

/// Max content width per breakpoint. Pages center a ConstrainedBox with
/// this value so desktop layouts never stretch full-screen width.
double contentMaxWidth(AppScreenSize size) {
  switch (size) {
    case AppScreenSize.mobile:
      return double.infinity;
    case AppScreenSize.tablet:
      return 720;
    case AppScreenSize.desktop:
      return 1080;
  }
}

/// Picks a value by breakpoint (e.g. grid column counts, paddings).
T responsiveValue<T>(BuildContext context, {
  required T mobile,
  T? tablet,
  T? desktop,
}) {
  switch (context.screenSize) {
    case AppScreenSize.mobile:
      return mobile;
    case AppScreenSize.tablet:
      return tablet ?? mobile;
    case AppScreenSize.desktop:
      return desktop ?? tablet ?? mobile;
  }
}

/// Builds mobile-first layouts: tablet/desktop builders fall back to the
/// previous tier when omitted.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    switch (context.screenSize) {
      case AppScreenSize.mobile:
        return mobile(context);
      case AppScreenSize.tablet:
        return (tablet ?? mobile)(context);
      case AppScreenSize.desktop:
        return (desktop ?? tablet ?? mobile)(context);
    }
  }
}

/// Standard page scaffold body: safe area, responsive gutters, centered
/// max-width content.
///
/// Uses symmetric gutter math (not [Center]) so children with [Expanded]
/// keep working: tight height flows straight from the Scaffold body while
/// extra width becomes equal side gutters on tablet/desktop.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.screenPadding),
    this.maxWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final cap = maxWidth ?? contentMaxWidth(context.screenSize);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter =
            ((constraints.maxWidth - cap) / 2).clamp(0.0, double.infinity);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }
}
