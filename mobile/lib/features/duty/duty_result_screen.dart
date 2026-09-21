/// Confirmation shown after a duty record is saved.
///
/// The duration displayed is the value the backend returned — when clock
/// times were supplied it was derived server-side, never trusted from the
/// client.
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../assessment/assessment_form_screen.dart';

class DutyResultScreen extends StatelessWidget {
  const DutyResultScreen({
    super.key,
    required this.record,
    required this.controller,
  });

  final DutyRecord record;
  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duty Record Saved'),
        backgroundColor: theme.colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 44,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Duty record saved',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Duration is the value returned by the server.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(context, Icons.event_outlined, 'Date',
                      formatDateOnly(record.recordDate)),
                  const Divider(height: 20),
                  _row(context, Icons.category_outlined, 'Type',
                      record.dutyType.label),
                  const Divider(height: 20),
                  _row(
                    context,
                    Icons.timelapse_outlined,
                    'Duration',
                    '${record.dutyHours.toStringAsFixed(record.dutyHours == record.dutyHours.roundToDouble() ? 0 : 2)} hours',
                    emphasize: true,
                  ),
                  if (record.startTime != null) ...[
                    const Divider(height: 20),
                    _row(context, Icons.schedule, 'Start',
                        formatDateTime(record.startTime!)),
                  ],
                  if (record.endTime != null) ...[
                    const Divider(height: 20),
                    _row(context, Icons.timer_outlined, 'End',
                        formatDateTime(record.endTime!)),
                  ],
                  if (record.deploymentId != null) ...[
                    const Divider(height: 20),
                    _row(context, Icons.tag_outlined, 'Deployment',
                        record.deploymentId!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Continue to wellness assessment',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value,
      {bool emphasize = false}) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:
                theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? theme.colorScheme.primary : null,
            ),
          ),
        ),
      ],
    );
  }
}