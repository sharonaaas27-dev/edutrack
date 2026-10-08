import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/providers/auth_provider.dart';
import 'package:edutrack/widgets/app_logo.dart';

/// First screen: restores a stored session, then routes by role.
/// Shows branding + loader while [AuthStatus] is initial/loading so the
/// login screen never flashes for returning users.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final auth = context.read<AuthProvider>();
    await auth.restoreSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(auth.homeRoute);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(),
              SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
