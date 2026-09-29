/// Duty record form.
///
/// Fields mirror the backend `POST /duty-records` schema exactly (see
/// `backend/app/schemas/duty.py`): record_date (not in the future), duty_type,
/// start_time + end_time together, or self-reported duty_hours in (0, 24],
/// plus an optional deployment_id. When start/end times are supplied the
/// backend derives `duty_hours` server-side and the app sends no duration at
/// all — the backend remains the source of truth.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'duty_result_screen.dart';

class DutyRecordFormScreen extends StatefulWidget {
  const DutyRecordFormScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<DutyRecordFormScreen> createState() => _DutyRecordFormScreenState();
}

class _DutyRecordFormScreenState extends State<DutyRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _recordDate = DateTime.now();
  DutyType _dutyType = DutyType.duty;

  bool _useClockTimes = true;
  DateTime? _startTime;
  DateTime? _endTime;
  final _hoursController = TextEditingController();
  final _deploymentController = TextEditingController();

  bool _submitting = false;
  String? _apiError;

  @override
  void dispose() {
    _hoursController.dispose();
    _deploymentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      helpText: 'Record date (cannot be in the future)',
    );
    if (picked != null) {
      setState(() => _recordDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime ?? DateTime.now()),
      helpText: 'Duty start time',
    );
    if (picked != null) {
      setState(() {
        _startTime = DateTime(
          _recordDate.year,
          _recordDate.month,
          _recordDate.day,
          picked.hour,
          picked.minute,
        );
        _endTime = null;
        _apiError = null;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime ?? DateTime.now()),
      helpText: 'Duty end time',
    );
    if (picked != null) {
      setState(() {
        _endTime = DateTime(
          _recordDate.year,
          _recordDate.month,
          _recordDate.day,
          picked.hour,
          picked.minute,
        );
        _apiError = null;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _apiError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_recordDate.isAfter(DateTime.now())) {
      setState(() => _apiError = 'The record date cannot be in the future.');
      return;
    }
    final token = widget.controller.token;
    if (token == null) return;

    DutyRecordCreate? draft;
    if (_useClockTimes) {
      if (_startTime == null || _endTime == null) {
        setState(
          () => _apiError =
              'Set both a start and an end time, or switch to total hours.',
        );
        return;
      }
      if (!_endTime!.isAfter(_startTime!)) {
        setState(
          () => _apiError = 'The end time must be after the start time.',
        );
        return;
      }
      final durationHours = _endTime!.difference(_startTime!).inMinutes / 60.0;
      if (durationHours <= 0 || durationHours > 24) {
        setState(
          () => _apiError = 'Duty duration must be within (0, 24] hours.',
        );
        return;
      }
      draft = DutyRecordCreate(
        recordDate: _recordDate,
        dutyType: _dutyType,
        startTime: _startTime,
        endTime: _endTime,
        deploymentId: _deploymentController.text.trim(),
      );
    } else {
      if (_hoursController.text.trim().isEmpty) {
        setState(() => _apiError = 'Enter the total hours for this record.');
        return;
      }
      draft = DutyRecordCreate(
        recordDate: _recordDate,
        dutyType: _dutyType,
        dutyHours: double.parse(_hoursController.text.trim()),
        deploymentId: _deploymentController.text.trim(),
      );
    }

    setState(() => _submitting = true);
    try {
      final result = await widget.controller.api.submitDutyRecord(token, draft);
      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DutyResultScreen(record: result, controller: widget.controller),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _apiError = userFacingErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _apiError = userFacingErrorMessage(e);
      });
    }
  }

  String? _hoursValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter the total hours';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a number, for example 8';
    }
    if (parsed <= 0 || parsed > 24) {
      return 'Must be greater than 0 and at most 24';
    }
    return null;
  }

  String? _deploymentValidator(String? value) {
    if (value != null && value.trim().length > 64) {
      return 'At most 64 characters';
    }
    return null;
  }

  String _timeLabel(DateTime? time) => time == null
      ? 'not set'
      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// Live duration preview, so the user can sanity-check their entry before
  /// submitting. The server remains the authority for the stored value.
  String? get _durationPreview {
    if (_useClockTimes) {
      if (_startTime == null || _endTime == null) return null;
      final hours = _endTime!.difference(_startTime!).inMinutes / 60.0;
      if (hours <= 0) return null;
      return 'That is ${_formatHours(hours)} hours, calculated for you.';
    }
    final parsed = double.tryParse(_hoursController.text.trim());
    if (parsed == null || parsed <= 0) return null;
    return 'That is ${_formatHours(parsed)} hours.';
  }

  static String _formatHours(double hours) {
    final fixed = hours.toStringAsFixed(2);
    return fixed.endsWith('00')
        ? hours.toStringAsFixed(0)
        : fixed.endsWith('0')
        ? fixed.substring(0, fixed.length - 1)
        : fixed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Duty Record')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            const Center(child: SyntheticDataNotice()),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: AppRadii.card,
                border: Border.all(color: AppColors.infoBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Log what you did and for how long. This is used, '
                      'together with your wellness check-ins, to work out your '
                      'stress-risk level. Only the hours are recorded — never '
                      'your location.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              icon: Icons.event_note_outlined,
              title: 'What are you recording?',
              subtitle: 'The day and the type of entry',
              child: Column(
                children: [
                  InkWell(
                    onTap: _submitting ? null : _pickDate,
                    borderRadius: AppRadii.chip,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.field,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date', style: theme.textTheme.bodySmall),
                                const SizedBox(height: 2),
                                Text(
                                  formatDateOnly(_recordDate),
                                  style: theme.textTheme.titleSmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.brand,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<DutyType>(
                    initialValue: _dutyType,
                    decoration: const InputDecoration(
                      labelText: 'Type of entry',
                      helperText: 'Leave and rest entries count towards rest',
                    ),
                    items: DutyType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(_dutyTypeDescription(t)),
                          ),
                        )
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _dutyType = v ?? DutyType.duty),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              icon: Icons.timelapse_outlined,
              title: 'How long?',
              subtitle: 'Give the start and end time, or just the total hours',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.schedule, size: 18),
                        label: Text('Start & end time'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.timer_outlined, size: 18),
                        label: Text('Total hours'),
                      ),
                    ],
                    selected: {_useClockTimes},
                    onSelectionChanged: (s) => setState(() {
                      _useClockTimes = s.first;
                      _apiError = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_useClockTimes) ...[
                    Text(
                      'Set the times you started and finished. The duration is '
                      'worked out for you.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeButton(
                            icon: Icons.login_outlined,
                            label: 'Start',
                            value: _timeLabel(_startTime),
                            onPressed: _submitting ? null : _pickStartTime,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _TimeButton(
                            icon: Icons.logout_outlined,
                            label: 'End',
                            value: _timeLabel(_endTime),
                            onPressed: _submitting ? null : _pickEndTime,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'If you do not have exact times, enter the total hours '
                      'you spent on this entry.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('duty-hours'),
                      controller: _hoursController,
                      enabled: !_submitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,2}(\.\d{0,2})?'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Total hours',
                        helperText: 'More than 0 and at most 24 hours',
                        suffixText: 'hours',
                        border: OutlineInputBorder(),
                      ),
                      validator: _hoursValidator,
                      onChanged: (_) => setState(() => _apiError = null),
                    ),
                  ],
                  if (_durationPreview != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _durationPreview!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              icon: Icons.tag_outlined,
              title: 'Reference (optional)',
              subtitle:
                  'Add a deployment or operation reference, if you have one',
              child: TextFormField(
                controller: _deploymentController,
                enabled: !_submitting,
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: 'Deployment or operation reference',
                  hintText: 'Leave blank if not applicable',
                  border: OutlineInputBorder(),
                ),
                validator: _deploymentValidator,
                onChanged: (_) => setState(() => _apiError = null),
              ),
            ),
            if (_apiError != null) ...[
              const SizedBox(height: AppSpacing.lg),
              InlineMessage(message: _apiError!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: StickyActionBar(
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Text('Saving…'),
                  ],
                )
              : const Text('Save duty record'),
        ),
      ),
    );
  }

  static String _dutyTypeDescription(DutyType type) => switch (type) {
    DutyType.duty => 'Duty',
    DutyType.deployment => 'Deployment',
    DutyType.leave => 'Leave',
    DutyType.rest => 'Rest',
    DutyType.training => 'Training',
  };
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSet = value != 'not set';
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.field),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.brand),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: isSet ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
