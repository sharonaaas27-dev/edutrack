// Stage 7: design-system component smoke tests.
import 'package:edutrack/core/utils/format.dart';
import 'package:edutrack/core/utils/responsive.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/app_cards.dart';
import 'package:edutrack/widgets/app_dropdown.dart';
import 'package:edutrack/widgets/app_search_field.dart';
import 'package:edutrack/widgets/app_states.dart';
import 'package:edutrack/widgets/attendance_bar_chart.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/low_attendance_banner.dart';
import 'package:edutrack/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('format utils', () {
    test('formatPercentage keeps whole numbers whole', () {
      expect(formatPercentage(87), '87%');
      expect(formatPercentage(66.666), '66.7%');
      expect(formatPercentage(0), '0%');
      expect(formatPercentage(double.nan), '—');
    });

    test('formatCount compacts large numbers', () {
      expect(formatCount(12), '12');
      expect(formatCount(9999), '9999');
      expect(formatCount(12000), '12k');
      expect(formatCount(12500), '12.5k');
    });
  });

  group('responsive helpers', () {
    Future<AppScreenSize> sizeAt(
        WidgetTester tester, double width) async {
      AppScreenSize? seen;
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            seen = context.screenSize;
            return const SizedBox();
          }),
        ),
      );
      await tester.pump();
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      return seen!;
    }

    testWidgets('breakpoints classify widths', (tester) async {
      expect(await sizeAt(tester, 390), AppScreenSize.mobile);
      expect(await sizeAt(tester, 768), AppScreenSize.tablet);
      expect(await sizeAt(tester, 1300), AppScreenSize.desktop);
    });

    test('contentMaxWidth grows with breakpoint', () {
      expect(contentMaxWidth(AppScreenSize.tablet), 720);
      expect(contentMaxWidth(AppScreenSize.desktop), 1080);
      expect(contentMaxWidth(AppScreenSize.mobile), double.infinity);
    });
  });

  group('AppStatCard', () {
    testWidgets('renders title, value, subtitle and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppStatCard(
              title: 'Students',
              value: '12',
              subtitle: 'Enrolled',
              icon: Icons.groups_outlined,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Enrolled'), findsOneWidget);
    });

    testWidgets('tap invokes callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppStatCard(
              title: 'Students',
              value: '12',
              icon: Icons.groups_outlined,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.byType(AppStatCard));
      expect(tapped, isTrue);
    });
  });

  group('SectionHeader', () {
    testWidgets('renders title and optional action', (tester) async {
      var acted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Overview',
              actionLabel: 'View All',
              onAction: () => acted = true,
            ),
          ),
        ),
      );
      expect(find.text('OVERVIEW'), findsOneWidget);
      await tester.tap(find.text('View All'));
      expect(acted, isTrue);
    });
  });

  group('AppAvatar', () {
    test('initials derive from names', () {
      expect(AppAvatar.initialsOf('Alex Thomas'), 'AT');
      expect(AppAvatar.initialsOf('Madonna'), 'MA');
      expect(AppAvatar.initialsOf('  '), '?');
    });

    testWidgets('falls back to initials without a photo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppAvatar(name: 'Alex Thomas')),
        ),
      );
      expect(find.text('AT'), findsOneWidget);
    });
  });

  group('LowAttendanceBanner', () {
    testWidgets('shows subject, percentage and warning semantics',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LowAttendanceBanner(
              subjectName: 'Mathematics',
              percentage: 68,
            ),
          ),
        ),
      );
      expect(find.text('Low Attendance'), findsOneWidget);
      expect(find.textContaining('Mathematics'), findsOneWidget);
      expect(find.textContaining('68%'), findsOneWidget);
    });
  });

  group('AttendanceBarChart', () {
    testWidgets('renders labels, values and semantic summary',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttendanceBarChart(
              segments: [
                BarSegment(label: 'Mon', percentage: 80),
                BarSegment(label: 'Tue', percentage: 60),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Attendance chart. Mon: 80%, Tue: 60%'),
        findsOneWidget,
      );
    });

    testWidgets('empty segments take no space', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AttendanceBarChart(segments: [])),
        ),
      );
      expect(find.byType(AttendanceBarChart), findsOneWidget);
      expect(tester.getSize(find.byType(AttendanceBarChart)), Size.zero);
    });
  });

  group('AppErrorState + AppLoadingSkeleton', () {
    testWidgets('error shows message and retries', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              message: 'Offline.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      expect(find.text('Offline.'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });

    testWidgets('skeleton announces loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppLoadingSkeleton(itemCount: 2)),
        ),
      );
      expect(find.bySemanticsLabel('Loading content'), findsOneWidget);
    });
  });

  group('AppSearchField', () {
    testWidgets('clear button resets the query', (tester) async {
      final controller = TextEditingController();
      var last = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchField(
              controller: controller,
              hintText: 'Search…',
              onChanged: (v) => last = v,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'alex');
      await tester.pump();
      expect(last, 'alex');
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(last, isEmpty);
      controller.dispose();
    });
  });

  group('AppDropdown', () {
    testWidgets('selects a value', (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDropdown<String>(
              label: 'Course',
              value: null,
              items: const ['All', 'CS'],
              onChanged: (v) => selected = v,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CS').last);
      await tester.pumpAndSettle();
      expect(selected, 'CS');
    });
  });

  group('EmptyState', () {
    testWidgets('action button fires', (tester) async {
      var acted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'Nothing here',
              subtitle: 'Try again later.',
              actionLabel: 'Retry',
              onAction: () => acted = true,
            ),
          ),
        ),
      );
      // Let the entrance animation finish.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Retry'));
      expect(acted, isTrue);
    });
  });
}
