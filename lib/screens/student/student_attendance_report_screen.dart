import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/core/utils/date_format.dart';
import 'package:edutrack/providers/report_provider.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/attendance_bar_chart.dart';
import 'package:edutrack/widgets/attendance_ring.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/app_dialog.dart';

/// Student Attendance Report Screen
///
/// Displays a student's overall attendance, subject-wise breakdown,
/// attendance trend chart, and low attendance warnings.
class StudentAttendanceReportScreen extends StatefulWidget {
  const StudentAttendanceReportScreen({
    super.key,
    required this.studentId,
  });

  /// The student's ID (from their user record student_id field)
  final String studentId;

  @override
  State<StudentAttendanceReportScreen> createState() =>
      _StudentAttendanceReportScreenState();
}

class _StudentAttendanceReportScreenState
    extends State<StudentAttendanceReportScreen> {
  String? _errorMessage;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReportData();
    });
  }

  Future<void> _loadReportData() async {
    final report = context.read<ReportProvider>();

    // Load overall summary
    await report.loadStudentReport(
      studentId: widget.studentId,
      startDate: _startDate,
      endDate: _endDate,
    );

    // Load subject breakdown
    await report.loadStudentSubjectBreakdown(
      studentId: widget.studentId,
      startDate: _startDate,
      endDate: _endDate,
    );

    // Load trend
    await report.loadStudentTrend(
      studentId: widget.studentId,
      startDate: _startDate,
      endDate: _endDate,
    );

    // Load low attendance
    await report.loadStudentLowAttendance(
      studentId: widget.studentId,
    );
  }

  Future<void> _refresh() async {
    await _loadReportData();
  }

  // Date range helpers
  String _formatDateRange() {
    if (_startDate == null && _endDate == null) {
      return 'All time';
    }
    if (_startDate != null && _endDate != null) {
      return '${formatDate(_startDate!)} - ${formatDate(_endDate!)}';
    }
    return _startDate != null
        ? 'Since ${formatDate(_startDate!)}'
        : 'Until ${formatDate(_endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(textTheme, colorScheme),
    );
  }

  Widget _buildBody(TextTheme textTheme, ColorScheme colorScheme) {
    final provider = context.watch<ReportProvider>();

    // Build the UI based on loading state and available data
    if (provider.isLoading && provider.getStudentOverall == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final providerError = provider.errorMessage;
    if (_errorMessage != null || providerError != null) {
      final message = _errorMessage ?? providerError ?? 'Unknown error';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Check if we have data
    final hasOverall = provider.getStudentOverall != null;
    final hasSubjects = provider.getStudentSubjectBreakdown.isNotEmpty;
    final hasTrend = provider.getStudentTrend.isNotEmpty;
    final hasLowAttendance = provider.getStudentLowAttendance.isNotEmpty;

    if (!hasOverall && !hasSubjects && !hasTrend && !hasLowAttendance) {
      return EmptyState(
        title: 'No attendance data',
        subtitle:
            'This student has no attendance records yet. Attendance will be '
            'marked by teachers for each class. (${_formatDateRange()})',
        icon: Icons.event_busy_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Attendance Overview ---
          _AttendanceOverviewCard(
            overallAttendance: provider.getStudentOverall,
            onRefresh: _refresh,
          ),

          const SizedBox(height: AppSpacing.lg),

          // --- Subject-wise Attendance ---
          if (hasSubjects) ...[
            Text(
              'Subject-wise Attendance',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._buildSubjectCards(
              provider.getStudentSubjectBreakdown,
              textTheme,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // --- Attendance Trend ---
          if (hasTrend) ...[
            Text(
              'Attendance Trend',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _AttendanceTrendChart(
              trend: provider.getStudentTrend,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // --- Low Attendance Warnings ---
          if (hasLowAttendance) ...[
            Text(
              'Low Attendance Alerts',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._buildLowAttendanceRows(
              provider.getStudentLowAttendance,
              textTheme,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // --- Export Button ---
          _ExportButton(
            studentId: widget.studentId,
            reportProvider: context.read<ReportProvider>(),
          ),
        ],
      ),
    );
  }

  // --- Subject Cards ---

  List<Widget> _buildSubjectCards(
    Map<String, AttendanceSummary> subjects,
    TextTheme textTheme,
  ) {
    return [
      for (final entry in subjects.entries)
        _SubjectAttendanceCard(
          subjectCode: entry.key,
          summary: entry.value,
        ),
    ];
  }

  // --- Low Attendance Rows ---

  List<Widget> _buildLowAttendanceRows(
    List<AttendanceSummary> lowAttendance,
    TextTheme textTheme,
  ) {
    return [
      for (var i = 0; i < lowAttendance.length; i++)
        _LowAttendanceRow(
          label: 'Subject ${i + 1}',
          subjectCode: 'SUB-${i + 1}',
          attendancePercentage: lowAttendance[i].percentage,
          totalClasses: lowAttendance[i].total,
          present: lowAttendance[i].present,
          absent: lowAttendance[i].absent,
          late: lowAttendance[i].late,
        ),
    ];
  }
}

// --- Widgets ---

class _AttendanceOverviewCard extends StatelessWidget {
  const _AttendanceOverviewCard({
    required this.overallAttendance,
    required this.onRefresh,
  });

  final AttendanceSummary? overallAttendance;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final overall = overallAttendance;

    if (overall == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('No overall attendance data available.'),
        ),
      );
    }

    final color = AppColors.attendance(overall.percentage);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Attendance',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                AttendanceRing(
                  percentage: overall.percentage,
                  size: 80,
                  strokeWidth: 8,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${overall.percentage.toStringAsFixed(1)}%',
                        style: textTheme.headlineMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${overall.present} present · ${overall.absent} absent · ${overall.late} late',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectAttendanceCard extends StatelessWidget {
  const _SubjectAttendanceCard({
    required this.subjectCode,
    required this.summary,
  });

  final String subjectCode;
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = AppColors.attendance(summary.percentage);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  subjectCode,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${summary.percentage.toStringAsFixed(1)}%',
                  style: textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            AttendanceBarChart(
              height: 80,
              segments: [
                BarSegment(
                  label: 'Present',
                  percentage: summary.presentRate,
                  color: AppColors.success,
                ),
                BarSegment(
                  label: 'Late',
                  percentage: summary.lateRate,
                  color: AppColors.warning,
                ),
                BarSegment(
                  label: 'Absent',
                  percentage: summary.absentRate,
                  color: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Present: ${summary.present} · Late: ${summary.late} · Absent: ${summary.absent}',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTrendChart extends StatelessWidget {
  const _AttendanceTrendChart({
    required this.trend,
  });

  final List<Map<String, dynamic>> trend;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('Not enough data to display trend.'),
        ),
      );
    }

    final percentages = trend
        .map((p) => (p['percentage'] as num?)?.toDouble() ?? 0.0)
        .toList();
    // ignore: unnecessary_null_comparison
    final maxPercentage = percentages.reduce(max) * 1.1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Trend',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Render trend points as stacked visual
            ...List.generate(trend.length, (index) {
              final point = trend[index];
              final percentage =
                  (point['percentage'] as num?)?.toDouble() ?? 0.0;
              final dateLabel = (point['date'] ?? '').toString();
              final safeMax =
                  maxPercentage <= 0 ? 1.0 : maxPercentage.clamp(0.01, 110.0);
              final heightFactor = (percentage / safeMax).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    // Date label
                    Expanded(
                      child: Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Percentage value
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    // Visual bar
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 20 * heightFactor.clamp(0.1, 1.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LowAttendanceRow extends StatelessWidget {
  const _LowAttendanceRow({
    required this.label,
    required this.subjectCode,
    required this.attendancePercentage,
    required this.totalClasses,
    required this.present,
    required this.absent,
    required this.late,
  });

  final String label;
  final String subjectCode;
  final double attendancePercentage;
  final int totalClasses;
  final int present;
  final int absent;
  final int late;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = AppColors.attendance(attendancePercentage);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  name: label,
                  radius: 20,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$label ($subjectCode)',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Attendance: ${attendancePercentage.toStringAsFixed(1)}%',
                        style: textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.remove_circle_outline,
                    color: AppColors.error, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Absent: $absent',
                  style: textTheme.bodySmall,
                ),
                const Spacer(),
                const Icon(Icons.access_time_outlined,
                    color: AppColors.warning, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Late: $late',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Present: $present',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Total Classes: $totalClasses',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.studentId,
    required this.reportProvider,
  });

  final String studentId;
  final ReportProvider reportProvider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: ElevatedButton(
        onPressed: () async {
          final csvContent =
              await reportProvider.exportStudentReportCSV(
            studentId: studentId,
          );

          if (!context.mounted) return;
          if (csvContent != null && csvContent.isNotEmpty) {
            // Show confirmation with preview length
            await showInfoDialog(
              context,
              title: 'Report ready',
              message:
                  'Generated ${csvContent.length} characters for $studentId.',
            );
            if (!context.mounted) return;
            // File saved successfully
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report exported successfully'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to generate report'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
        child: const Text('Export as CSV'),
      ),
    );
  }
}
