import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/providers/auth_provider.dart';
import 'package:edutrack/screens/auth/login_screen.dart';
import 'package:edutrack/screens/auth/splash_screen.dart';
import 'package:edutrack/widgets/empty_state.dart';

/// Route guard: renders [child] only for authenticated users whose role
/// is in [roles]. Otherwise renders login (logged out) or access-denied
/// (wrong role). Rendering instead of navigating keeps the back stack
/// clean and loop-free.
class RequireRole extends StatelessWidget {
  const RequireRole({super.key, required this.roles, required this.child});

  final Set<UserRole> roles;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isLoading) {
      return const SplashScreen();
    }
    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }
    if (!roles.contains(auth.role)) {
      return const AccessDeniedScreen();
    }
    return child;
  }
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Restricted')),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyState(
                title: 'Access denied',
                subtitle:
                    'Your account role cannot open this section. '
                    'Contact an administrator if you need access.',
                icon: Icons.lock_outline_rounded,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pushNamedAndRemoveUntil(
                              auth.homeRoute, (route) => false),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Go to my dashboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => auth.logout(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
