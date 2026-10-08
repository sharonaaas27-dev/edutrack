import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/utils/responsive.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/providers/auth_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/app_dialog.dart';
import 'package:edutrack/widgets/app_shell.dart';
import 'package:edutrack/widgets/section_header.dart';
import 'package:edutrack/widgets/user_badge.dart';

/// Signed-in account overview. All values come from the session and the
/// backend student record — nothing is hard-coded.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to use EduTrack.',
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
      danger: false,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final linked = user?.studentId == null
        ? null
        : context.watch<StudentProvider>().getById(user!.studentId!);
    final displayName =
        UserBadge.nameFor(user, linked?.name ?? user?.email ?? 'there');
    final fullName = linked?.name ?? displayName;

    return AppShell(
      title: 'Profile',
      selectedIndex: 4,
      body: PageBody(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Row(
                    children: [
                      AppAvatar(
                        name: fullName,
                        imageUrl: linked?.profileImageUrl,
                        radius: 34,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              user?.email ?? '',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            UserBadge(
                              displayName: displayName,
                              role: user?.role ?? UserRole.student,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(
                title: 'Account',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Column(
                  children: [
                    _InfoTile(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: user?.email ?? '—',
                    ),
                    const Divider(height: 1, indent: AppSpacing.xl),
                    _InfoTile(
                      icon: Icons.shield_outlined,
                      label: 'Status',
                      value: (user?.isActive ?? true)
                          ? 'Active'
                          : 'Deactivated',
                    ),
                    if (linked != null) ...[
                      const Divider(height: 1, indent: AppSpacing.xl),
                      _InfoTile(
                        icon: Icons.numbers_rounded,
                        label: 'Student ID',
                        value: linked.studentId,
                      ),
                      const Divider(height: 1, indent: AppSpacing.xl),
                      _InfoTile(
                        icon: Icons.school_outlined,
                        label: 'Program',
                        value:
                            '${linked.course} · ${linked.year} · Section ${linked.section}',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(
                title: 'About EduTrack',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'EduTrack is a student management and attendance '
                    'platform for students, teachers, and administrators: '
                    'records, subjects with enrollment, daily attendance, '
                    'and live reports.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize:
                      const Size.fromHeight(AppSpacing.buttonHeight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(icon, size: 18, color: AppColors.secondaryLight),
      ),
      title: Text(label, style: textTheme.bodySmall),
      subtitle: Text(
        value,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
