/// Wellness assessment form.
///
/// Fields mirror the backend `POST /assessments` schema exactly (see
/// `backend/app/schemas/assessment.py`):
///   stress_level_self_report (1–10), rest_hours_7d (0–24),
///   sleep_hours_7d (0–24), workload_score (1–10), notes (<= 2000 chars).
/// No fields are invented and no defaults are pre-filled: client-side
/// validation mirrors the backend rules and the server remains the authority.
/// On success the automatic prediction from the response is shown.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
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

  // 1 is the lowest value the backend accepts, so nothing is pre-selected that
  // the user has not actually chosen.
  int? _stressLevel;
  int? _workloadScore;
  final _restHoursController = TextEditingController();
  final _sleepHoursController = TextEditingController();
  final _notesController = TextEditingController();

  bool _submitting = false;
  String? _apiError;

  @override
  void dispose() {
    _restHoursController.dispose();
    _sleepHoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _apiError = null);
    if (!_formKey.currentState!.validate()) return;
    final stress = _stressLevel;
    final workload = _workloadScore;
    if (stress == null || workload == null) {
      setState(
        () => _apiError =
            'Please answer both rating questions before '
            'submitting.',
      );
      return;
    }
    final token = widget.controller.token;
    if (token == null) return;

    setState(() => _submitting = true);
    try {
      final response = await widget.controller.api.submitAssessment(
        token,
        AssessmentCreate(
          stressLevelSelfReport: stress,
          restHours7d: double.parse(_restHoursController.text.trim()),
          sleepHours7d: double.parse(_sleepHoursController.text.trim()),
          workloadScore: workload,
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
      return 'Enter the average hours';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a number, for example 7.5';
    }
    if (parsed < 0 || parsed > 24) {
      return 'Must be between 0 and 24 hours';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Wellness Assessment')),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About the last 7 days',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Answer honestly about your own rest, sleep and '
                          'workload. When you submit, the system will show a '
                          'LOW, MEDIUM or HIGH stress-risk level and the '
                          'reasons behind it.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              icon: Icons.favorite_outline,
              title: 'How have you been feeling?',
              subtitle: 'Tap a number to rate yourself',
              child: Column(
                children: [
                  ScaleQuestion(
                    label: 'Stress level',
                    helper: 'How stressed have you felt over the last 7 days?',
                    lowAnchor: 'Not stressed at all',
                    highAnchor: 'Extremely stressed',
                    value: _stressLevel,
                    onChanged: (v) => setState(() {
                      _stressLevel = v;
                      _apiError = null;
                    }),
                  ),
                  const Divider(height: AppSpacing.huge),
                  ScaleQuestion(
                    label: 'Workload',
                    helper: 'How heavy has your recent workload felt?',
                    lowAnchor: 'Very light',
                    highAnchor: 'Very heavy',
                    value: _workloadScore,
                    onChanged: (v) => setState(() {
                      _workloadScore = v;
                      _apiError = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              icon: Icons.bedtime_outlined,
              title: 'Rest and sleep',
              subtitle: 'Your daily average over the last 7 days',
              child: Column(
                children: [
                  HoursField(
                    key: const Key('assessment-rest-hours'),
                    label: 'Rest hours',
                    helper: 'Hours spent resting or off duty each day',
                    controller: _restHoursController,
                    validator: _hoursValidator,
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HoursField(
                    key: const Key('assessment-sleep-hours'),
                    label: 'Sleep hours',
                    helper: 'Hours of sleep each night on average',
                    controller: _sleepHoursController,
                    validator: _hoursValidator,
                    enabled: !_submitting,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              icon: Icons.notes_outlined,
              title: 'Anything to add?',
              subtitle: 'Optional — a note for your welfare officer',
              child: TextFormField(
                controller: _notesController,
                enabled: !_submitting,
                maxLength: 2000,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'For example: recent deployment, family situation, sleep '
                      'difficulties, anything you want support with.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            if (_apiError != null) ...[
              const SizedBox(height: AppSpacing.lg),
              InlineMessage(message: _apiError!),
            ],
            const SizedBox(height: AppSpacing.lg),
            const RiskDisclaimerCard(headline: 'Before you submit'),
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
                    Text('Submitting…'),
                  ],
                )
              : const Text('Submit assessment'),
        ),
      ),
    );
  }
}

/// A 1–10 self-rating question.
///
/// A tappable 1–10 scale with plain-language anchors at both ends, instead of
/// a bare slider: a person can see the whole range, understand what the ends
/// mean, and tap their answer directly. The chosen value is also announced to
/// screen readers.
class ScaleQuestion extends StatelessWidget {
  const ScaleQuestion({
    super.key,
    required this.label,
    required this.helper,
    required this.lowAnchor,
    required this.highAnchor,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String helper;
  final String lowAnchor;
  final String highAnchor;

  /// Currently chosen value, or null when the user has not chosen yet.
  final int? value;

  final ValueChanged<int> onChanged;

  /// The colour a value maps to. Reused for the 1–10 severity ramp.
  static Color toneFor(int value) {
    if (value <= 3) return AppColors.success;
    if (value <= 6) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(helper, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (value != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: toneFor(value!).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: toneFor(value!).withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '$value out of 10',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: toneFor(value!),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (var n = 1; n <= 10; n++) ...[
              if (n > 1) const SizedBox(width: 4),
              Expanded(
                child: _ScaleCell(
                  value: n,
                  selected: value == n,
                  onTap: onChanged,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text('1 · $lowAnchor', style: theme.textTheme.labelSmall),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                '$highAnchor · 10',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScaleCell extends StatelessWidget {
  const _ScaleCell({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = ScaleQuestion.toneFor(value);
    return Semantics(
      button: true,
      selected: selected,
      label: '$value out of 10',
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? tone : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? tone : AppColors.borderStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            '$value',
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? Colors.white : AppColors.textMuted,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// A decimal hours input with a unit suffix and a plain-language helper.
class HoursField extends StatelessWidget {
  const HoursField({
    super.key,
    required this.label,
    required this.helper,
    required this.controller,
    required this.validator,
    required this.enabled,
  });

  final String label;
  final String helper;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d{0,2})?')),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixText: 'hours',
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}
