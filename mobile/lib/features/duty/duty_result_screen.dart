/// Confirmation shown after a duty record is saved.
///
/// The duration displayed is the value the backend returned — when clock times
/// were supplied it was derived server-side, never trusted from the client.
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../assessment/assessment_form_screen.dart';

class DutyResultScreen extends StatelessWidget {
  const DutyResultScreen({
    super.key,
    required this.record,
    required this.controller,
  });

  final DutyRecord record;
  final AuthController controller;

  static String _formatHours(double hours) {
    if (hours == hours.roundToDouble()) return hours.toStringAsFixed(0);
    return hours.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Saved'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          const Center(child: SyntheticDataNotice()),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppColors.successSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 36,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Duty record saved',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This entry will be used with your next wellness check-in.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionCard(
            icon: Icons.receipt_long_outlined,
            title: 'What was recorded',
            child: Column(
              children: [
                _row(
                  context,
                  Icons.calendar_today_outlined,
                  'Date',
                  formatDateOnly(record.recordDate),
                ),
                const Divider(height: AppSpacing.xxl),
                _row(
                  context,
                  Icons.category_outlined,
                  'Type',
                  record.dutyType.label,
                ),
                const Divider(height: AppSpacing.xxl),
                _row(
                  context,
                  Icons.timelapse_outlined,
                  'Duration',
                  '${_formatHours(record.dutyHours)} hours',
                  emphasize: true,
                ),
                if (record.startTime != null) ...[
                  const Divider(height: AppSpacing.xxl),
                  _row(
                    context,
                    Icons.login_outlined,
                    'Start',
                    formatDateTime(record.startTime!),
                  ),
                ],
                if (record.endTime != null) ...[
                  const Divider(height: AppSpacing.xxl),
                  _row(
                    context,
                    Icons.logout_outlined,
                    'End',
                    formatDateTime(record.endTime!),
                  ),
                ],
                if (record.deploymentId != null) ...[
                  const Divider(height: AppSpacing.xxl),
                  _row(
                    context,
                    Icons.tag_outlined,
                    'Reference',
                    record.deploymentId!,
                  ),
                ],
                const Divider(height: AppSpacing.xxl),
                _row(
                  context,
                  Icons.verified_outlined,
                  'Checked by',
                  'The system calculated and checked the duration',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.popUntil((route) => route.isFirst);
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => AssessmentFormScreen(controller: controller),
                ),
              );
            },
            child: const Text('Continue to wellness check-in'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: AppColors.textMuted),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 84,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? AppColors.brand : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
