import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/config/app_config.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/utils/validators.dart';
import 'package:edutrack/providers/auth_provider.dart';
import 'package:edutrack/widgets/app_dialog.dart';
import 'package:edutrack/widgets/app_logo.dart';
import 'package:edutrack/widgets/custom_button.dart';
import 'package:edutrack/widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed(auth.homeRoute);
    } else {
      final message = auth.errorMessage ?? AppStrings.unexpectedError;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.maxContentWidth,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    const Center(child: AppLogo()),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      AppStrings.appName,
                      style: textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.appTagline,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    Text(AppStrings.welcomeBack, style: textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.signInToContinue,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    CustomTextField(
                      controller: _emailController,
                      label: AppStrings.emailLabel,
                      hint: AppStrings.emailHint,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.mail_outline_rounded,
                      validator: Validators.email,
                      onChanged: (_) => auth.clearError(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CustomTextField(
                      controller: _passwordController,
                      label: AppStrings.passwordLabel,
                      hint: AppStrings.passwordHint,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: Validators.password,
                      onChanged: (_) => auth.clearError(),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => showInfoDialog(
                                  context,
                                  title: 'Reset password',
                                  message:
                                      'Self-service password reset is not '
                                      'available in this version. Please '
                                      'contact your administrator to reset '
                                      'your password.',
                                ),
                        child: const Text(AppStrings.forgotPassword),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    CustomButton(
                      text: AppStrings.signIn,
                      isLoading: auth.isLoading,
                      onPressed: auth.isLoading ? null : _handleSignIn,
                      icon: Icons.login_rounded,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _DemoCredentialsCard(textTheme: textTheme),
                    const SizedBox(height: AppSpacing.md),
                    if (kDebugMode) const _ConnectionInfoFooter(),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      AppStrings.appVersion,
                      style: textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoCredentialsCard extends StatelessWidget {
  const _DemoCredentialsCard({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.primaryContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.demoCredentialsTitle,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Development accounts (password EduTrack123! for all three):\n'
            'Admin — admin@edutrack.local\n'
            'Teacher — teacher@edutrack.local\n'
            'Student — student@edutrack.local',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.primaryDark,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Debug-only footer showing which backend the app is pointing at.
///
/// This is the #1 cause of "Unable to connect" confusion:
/// - Android emulator must use http://10.0.2.2:8000 (not localhost)
/// - Desktop/Web use http://localhost:8000
/// - Mock mode (USE_MOCK_DATA=true) needs no backend at all.
class _ConnectionInfoFooter extends StatelessWidget {
  const _ConnectionInfoFooter();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mode = AppConfig.useMockData
        ? 'MOCK (offline)'
        : 'API: ${AppConfig.apiBaseUrl}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        '$mode\nEmulator? use http://10.0.2.2:8000 • Check /health in browser.',
        style: textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
