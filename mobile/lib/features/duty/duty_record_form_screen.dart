/// Phase 4 — Duty record form.
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
      initialTime: TimeOfDay.fromDateTime(
        _startTime ?? DateTime.now(),
      ),
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
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _apiError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_recordDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The record date cannot be in the future.'),
        ),
      );
      return;
    }
    final token = widget.controller.token;
    if (token == null) return;

    DutyRecordCreate? draft;
    if (_useClockTimes) {
      if (_startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Set both a start and an end time (or use hours instead).'),
          ),
        );
        return;
      }
      if (!_endTime!.isAfter(_startTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End time must be after start time.'),
          ),
        );
        return;
      }
      final durationHours = _endTime!.difference(_startTime!).inMinutes / 60.0;
      if (durationHours <= 0 || durationHours > 24) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Duty duration must be within (0, 24] hours.'),
          ),
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
      draft = DutyRecordCreate(
        recordDate: _recordDate,
        dutyType: _dutyType,
        dutyHours: double.parse(_hoursController.text.trim()),
        deploymentId: _deploymentController.text.trim(),
      );
    }

    setState(() => _submitting = true);
    try {
      final result = await widget.controller.api
          .submitDutyRecord(token, draft);
      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DutyResultScreen(
            record: result,
            controller: widget.controller,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _apiError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _apiError = 'Unexpected error. Please try again.';
      });
    }
  }

  String? _hoursValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Only required when not using clock times (checked on submit)
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a number';
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

  String _timeLabel(DateTime? time) =>
      time == null ? '—' : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duty Record'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: SyntheticDataNotice()),
            const SizedBox(height: 16),
            _DutySection(
              icon: Icons.event_note_outlined,
              title: 'Record details',
              subtitle: 'When and what kind of duty',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.event,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(formatDateOnly(_recordDate),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Record date (cannot be in the future)'),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _submitting ? null : _pickDate,
                  ),
                  const Divider(),
                  DropdownButtonFormField<DutyType>(
                    initialValue: _dutyType,
                    decoration: const InputDecoration(
                      labelText: 'Duty type',
                      border: OutlineInputBorder(),
                    ),
                    items: DutyType.values
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t.label)))
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (v) =>
                            setState(() => _dutyType = v ?? DutyType.duty),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DutySection(
              icon: Icons.timelapse_outlined,
              title: 'Duration',
              subtitle: 'Clock times or a self-reported duration',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.schedule),
                        label: Text('Clock times'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.timer_outlined),
                        label: Text('Hours'),
                      ),
                    ],
                    selected: {_useClockTimes},
                    onSelectionChanged: (s) => setState(() {
                      _useClockTimes = s.first;
                      _apiError = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (_useClockTimes) ...[
                    const Text(
                      'When both times are set, the duration is calculated by '
                      'the server — no hours need to be entered.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label:
                                Text('Start ${_timeLabel(_startTime)}'),
                            onPressed: _submitting ? null : _pickStartTime,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.stop),
                            label: Text('End ${_timeLabel(_endTime)}'),
                            onPressed: _submitting ? null : _pickEndTime,
                          ),
                        ),
                      ],
                    ),
                    if (_startTime != null && _endTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Builder(builder: (context) {
                          final dur = _endTime!.difference(_startTime!).inMinutes /
                              60.0;
                          return Text(
                            dur > 0 ? '≈ ${dur.toStringAsFixed(2)} hours' : '',
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        }),
                      ),
                  ] else
                    TextFormField(
                      controller: _hoursController,
                      enabled: !_submitting,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Duty hours',
                        hintText: 'e.g. 8',
                        suffixText: 'hours',
                        helperText: 'More than 0 and at most 24 hours',
                        border: OutlineInputBorder(),
                      ),
                      validator: _hoursValidator,
                      onChanged: (v) => setState(() => _apiError = null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DutySection(
              icon: Icons.tag_outlined,
              title: 'Optional reference',
              subtitle: 'Deployment identifier if applicable',
              child: TextFormField(
                controller: _deploymentController,
                enabled: !_submitting,
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: 'Deployment ID (optional)',
                  border: OutlineInputBorder(),
                ),
                validator: _deploymentValidator,
                onChanged: (v) => setState(() => _apiError = null),
              ),
            ),
            if (_apiError != null) ...[
              const SizedBox(height: 8),
              Text(
                _apiError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit duty record',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DutySection extends StatelessWidget {
  const _DutySection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}