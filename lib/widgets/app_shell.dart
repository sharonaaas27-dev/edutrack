import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/utils/responsive.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/providers/auth_provider.dart';

/// One navigation destination inside [AppShell].
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

/// Consistent authenticated chrome: title, responsive navigation
/// (bottom bar / rail / sidebar), profile entry, and logout.
///
/// Main pages opt in by wrapping their content; pushed detail routes keep
/// their own Scaffold so back navigation keeps working. Route guards in
/// [AppRoutes] remain the authorization boundary.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final int selectedIndex;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  static List<ShellDestination> destinationsFor(UserRole? role) {
    switch (role) {
      case UserRole.admin:
        return const [
          ShellDestination(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            route: AppRoutes.admin,
          ),
          ShellDestination(
            label: 'Students',
            icon: Icons.people_outline_rounded,
            selectedIcon: Icons.people_rounded,
            route: AppRoutes.students,
          ),
          ShellDestination(
            label: 'Subjects',
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            route: AppRoutes.subjects,
          ),
          ShellDestination(
            label: 'Attendance',
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_rounded,
            route: AppRoutes.attendance,
          ),
          ShellDestination(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            route: AppRoutes.profile,
          ),
        ];
      case UserRole.teacher:
        return const [
          ShellDestination(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            route: AppRoutes.teacher,
          ),
          ShellDestination(
            label: 'Students',
            icon: Icons.people_outline_rounded,
            selectedIcon: Icons.people_rounded,
            route: AppRoutes.students,
          ),
          ShellDestination(
            label: 'Subjects',
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            route: AppRoutes.subjects,
          ),
          ShellDestination(
            label: 'Attendance',
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_rounded,
            route: AppRoutes.attendance,
          ),
          ShellDestination(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            route: AppRoutes.profile,
          ),
        ];
      case UserRole.student:
      case null:
        return const [
          ShellDestination(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            route: AppRoutes.dashboard,
          ),
          ShellDestination(
            label: 'Subjects',
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            route: AppRoutes.studentSubjects,
          ),
          ShellDestination(
            label: 'Attendance',
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_rounded,
            route: AppRoutes.studentAttendance,
          ),
          ShellDestination(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            route: AppRoutes.profile,
          ),
        ];
    }
  }

  void _go(BuildContext context, int index) {
    final destinations =
        destinationsFor(context.read<AuthProvider>().role);
    if (index < 0 || index >= destinations.length) return;
    if (index == selectedIndex) return;
    Navigator.of(context)
        .pushReplacementNamed(destinations[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final destinations = destinationsFor(auth.role);
    final safeIndex =
        selectedIndex.clamp(0, destinations.length - 1);
    final profileAction = IconButton(
      tooltip: 'Profile',
      onPressed: () {
        if (ModalRoute.of(context)?.settings.name != AppRoutes.profile) {
          Navigator.of(context).pushNamed(AppRoutes.profile);
        }
      },
      icon: const Icon(Icons.account_circle_outlined),
    );

    return ResponsiveLayout(
      mobile: (_) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [...?actions, profileAction],
        ),
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: (i) => _go(context, i),
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
      tablet: (_) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [...?actions, profileAction],
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: safeIndex,
              onDestinationSelected: (i) => _go(context, i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
      ),
      desktop: (_) => Scaffold(
        body: Row(
          children: [
            _Sidebar(
              title: title,
              destinations: destinations,
              selectedIndex: safeIndex,
              onSelect: (i) => _go(context, i),
            ),
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    title: Text(title),
                    actions: [...?actions, profileAction],
                    automaticallyImplyLeading: false,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
  });

  final String title;
  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 264,
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'EduTrack',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    _SidebarTile(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fg = selected ? AppColors.onPrimary : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? destination.selectedIcon
                      : destination.icon,
                  color: selected ? fg : AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    destination.label,
                    style: textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
