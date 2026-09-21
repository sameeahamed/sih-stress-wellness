/// Phase 3 — Wellness assessment form.
///
/// Fields mirror the backend `POST /assessments` schema exactly (see
/// `backend/app/schemas/assessment.py`):
///   stress_level_self_report (1–10), rest_hours_7d (0–24),
///   sleep_hours_7d (0–24), workload_score (1–10), notes (<= 2000 chars).
/// No fields are invented. Client-side validation mirrors the backend rules;
/// the server remains the authority. On success the automatic prediction from
/// the response is shown (Phase 5).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';
import '../results/prediction_result_screen.dart';

class AssessmentFormScreen extends StatefulWidget {
  const AssessmentFormScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  int _stressLevel = 5;
  int _workloadScore = 5;
  double _restHours = 7.0;
  double _sleepHours = 7.0;
  final _notesController = TextEditingController();

  bool _submitting = false;
  String? _apiError;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _apiError = null);
    if (!_formKey.currentState!.validate()) return;
    final token = widget.controller.token;
    if (token == null) return;

    setState(() => _submitting = true);
    try {
      final response = await widget.controller.api.submitAssessment(
        token,
        AssessmentCreate(
          stressLevelSelfReport: _stressLevel,
          restHours7d: _restHours,
          sleepHours7d: _sleepHours,
          workloadScore: _workloadScore,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PredictionResultScreen(
            controller: widget.controller,
            result: response,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellness Assessment'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: SyntheticDataNotice()),
            const SizedBox(height: 16),
            const RiskDisclaimerCard(),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.speed_outlined,
              title: 'How do you feel?',
              subtitle: 'Self-reported scales (1 = low, 10 = high)',
              child: Column(
                children: [
                  _ScaleSlider(
                    label: 'Self-reported stress level',
                    subtitle: 'How stressed have you felt recently?',
                    value: _stressLevel.toDouble(),
                    min: 1,
                    max: 10,
                    divisor: 9,
                    display: '$_stressLevel / 10',
                    onChanged: (v) =>
                        setState(() => _stressLevel = v.round()),
                  ),
                  _ScaleSlider(
                    label: 'Workload score',
                    subtitle: 'How heavy was your recent workload?',
                    value: _workloadScore.toDouble(),
                    min: 1,
                    max: 10,
                    divisor: 9,
                    display: '$_workloadScore / 10',
                    onChanged: (v) =>
                        setState(() => _workloadScore = v.round()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.bedtime_outlined,
              title: 'Rest & sleep',
              subtitle: 'Average over the last 7 days',
              child: Column(
                children: [
                  _HoursField(
                    label: 'Rest hours',
                    hint: 'e.g. 7.5',
                    initial: _restHours,
                    onChanged: (v) => _restHours = v,
                    validator: _hoursValidator,
                  ),
                  _HoursField(
                    label: 'Sleep hours',
                    hint: 'e.g. 7',
                    initial: _sleepHours,
                    onChanged: (v) => _sleepHours = v,
                    validator: _hoursValidator,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.notes_outlined,
              title: 'Notes',
              subtitle: 'Optional comments for the welfare officer',
              child: TextFormField(
                controller: _notesController,
                enabled: !_submitting,
                maxLength: 2000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Anything you would like to add',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            if (_apiError != null) ...[
              const SizedBox(height: 8),
              Text(
                _apiError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
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
                      'Submit assessment',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _hoursValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a number';
    }
    if (parsed < 0 || parsed > 24) {
      return 'Must be between 0 and 24 hours';
    }
    return null;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      size: 22, color: theme.colorScheme.primary),
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
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ScaleSlider extends StatelessWidget {
  const _ScaleSlider({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisor,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisor;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  display,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisor,
            label: display,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _HoursField extends StatelessWidget {
  const _HoursField({
    required this.label,
    required this.hint,
    required this.initial,
    required this.onChanged,
    required this.validator,
  });

  final String label;
  final String hint;
  final double initial;
  final ValueChanged<double> onChanged;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: initial.toStringAsFixed(1),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: 'hours',
          border: const OutlineInputBorder(),
        ),
        validator: validator,
        onChanged: (v) {
          final parsed = double.tryParse(v.trim());
          if (parsed != null) onChanged(parsed.clamp(0, 24));
        },
      ),
    );
  }
}