/// SIMULATED "AI Wellness Check-in" — a demo-only concept screen.
///
/// PROTOTYPE / DEMO SIMULATION. There is no telephony, no speech recognition,
/// no text-to-speech and no external AI service anywhere in this flow. Every
/// "response" is an ordinary tappable button, and the whole conversation is
/// driven by a small local state machine.
///
/// The point it demonstrates: information that already exists in authorized
/// organizational systems (leave, deployment, duty, personnel records) should
/// NOT be asked of the person again. This screen only captures the small set of
/// things those systems cannot know — how the person actually feels right now.
///
/// The answers are mapped onto the EXISTING assessment contract
/// (`POST /assessments`) and submitted through the existing authenticated API
/// client. The prediction is therefore produced by the real backend XGBoost +
/// SHAP pipeline, not by this screen. No ML methodology is duplicated here.
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../results/prediction_result_screen.dart';

/// One conversational question and the buttons that answer it.
class _CheckinQuestion {
  const _CheckinQuestion({
    required this.prompt,
    required this.asks,
    required this.answers,
  });

  final String prompt;

  /// What the question is really asking for, shown as a small caption.
  final String asks;

  final List<_CheckinAnswer> answers;
}

class _CheckinAnswer {
  const _CheckinAnswer({
    required this.label,
    required this.icon,
    required this.onSelect,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelect;
}

class WellnessCheckinScreen extends StatefulWidget {
  const WellnessCheckinScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<WellnessCheckinScreen> createState() => _WellnessCheckinScreenState();
}

class _WellnessCheckinScreenState extends State<WellnessCheckinScreen> {
  /// 0 = intro, 1..N = questions, N+1 = done/submitting.
  int _step = 0;

  // Answers, mapped straight onto the existing assessment fields.
  int? _stress;
  int? _workload;
  double? _rest;
  double? _sleep;
  String? _followUp;

  bool _submitting = false;
  String? _error;
  AssessmentSubmitResponse? _result;

  List<DutyRecord> _duty = const [];
  bool _dutyLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganizationalData();
  }

  /// Real duty/deployment/leave context for this personnel, read from the
  /// existing `GET /duty-records` endpoint. This is the data the check-in
  /// deliberately does NOT ask the person to re-enter.
  Future<void> _loadOrganizationalData() async {
    final token = widget.controller.token;
    if (token == null) {
      setState(() => _dutyLoading = false);
      return;
    }
    try {
      final records = await widget.controller.api.fetchDutyRecords(token);
      if (!mounted) return;
      setState(() {
        _duty = records;
        _dutyLoading = false;
      });
    } on Object {
      // The concept screen is still usable without this panel; never let an
      // optional context card block the check-in itself.
      if (!mounted) return;
      setState(() => _dutyLoading = false);
    }
  }

  List<_CheckinQuestion> get _questions => [
        _CheckinQuestion(
          prompt: 'How are you feeling today?',
          asks: 'This is the only self-reported signal these systems cannot provide.',
          answers: [
            _CheckinAnswer(
              label: 'Good',
              icon: Icons.sentiment_very_satisfied_outlined,
              onSelect: () => _answer(2),
            ),
            _CheckinAnswer(
              label: 'Okay',
              icon: Icons.sentiment_neutral_outlined,
              onSelect: () => _answer(5),
            ),
            _CheckinAnswer(
              label: 'Stressed',
              icon: Icons.sentiment_dissatisfied_outlined,
              onSelect: () => _answer(8),
            ),
            _CheckinAnswer(
              label: 'Very stressed',
              icon: Icons.sentiment_very_dissatisfied_outlined,
              onSelect: () => _answer(10),
            ),
          ],
        ),
        _CheckinQuestion(
          prompt: 'How would you rate your current workload?',
          asks: 'Self-reported workload, mapped to the existing 1-10 scale.',
          answers: [
            _CheckinAnswer(
              label: 'Low',
              icon: Icons.battery_1_bar_outlined,
              onSelect: () => _answer(2),
            ),
            _CheckinAnswer(
              label: 'Moderate',
              icon: Icons.battery_3_bar_outlined,
              onSelect: () => _answer(5),
            ),
            _CheckinAnswer(
              label: 'High',
              icon: Icons.battery_5_bar_outlined,
              onSelect: () => _answer(8),
            ),
            _CheckinAnswer(
              label: 'Very high',
              icon: Icons.battery_full_outlined,
              onSelect: () => _answer(10),
            ),
          ],
        ),
        _CheckinQuestion(
          prompt: 'Have you had enough rest recently?',
          asks: 'Rest and sleep, mapped to the existing 7-day averages.',
          answers: [
            _CheckinAnswer(
              label: 'Yes',
              icon: Icons.bedtime_outlined,
              onSelect: () => _answer(3, rest: 8, sleep: 8),
            ),
            _CheckinAnswer(
              label: 'Mostly',
              icon: Icons.bedtime_outlined,
              onSelect: () => _answer(3, rest: 6, sleep: 6.5),
            ),
            _CheckinAnswer(
              label: 'Not enough',
              icon: Icons.nightlight_round,
              onSelect: () => _answer(3, rest: 3, sleep: 3.5),
            ),
          ],
        ),
        _CheckinQuestion(
          prompt: 'Would you like a welfare officer to follow up?',
          asks: 'A note for your record. It does not trigger any action by itself.',
          answers: [
            _CheckinAnswer(
              label: 'No',
              icon: Icons.check_circle_outline,
              onSelect: () => _answerFollowUp('No follow-up requested'),
            ),
            _CheckinAnswer(
              label: 'Yes',
              icon: Icons.support_agent_outlined,
              onSelect: () => _answerFollowUp('Requested welfare officer follow-up'),
            ),
          ],
        ),
      ];

  /// Records an answer for whichever question is on screen. [value] is the
  /// 1-10 answer for the stress and workload questions; the rest/sleep
  /// question supplies its own [rest] and [sleep] averages.
  void _answer(int value, {double? rest, double? sleep}) {
    setState(() {
      if (_step == 1) _stress = value;
      if (_step == 2) _workload = value;
      if (_step == 3) {
        _rest = rest;
        _sleep = sleep;
      }
      _step++;
    });
  }

  void _answerFollowUp(String note) {
    setState(() {
      _followUp = note;
      _step++;
    });
    // Leaving the last question starts the real submission. Without this the
    // outcome screen would sit on its loading state forever.
    if (_step > _questions.length) {
      _submit();
    }
  }

  /// Submit the conversational answers through the EXISTING assessment API.
  /// The backend runs the real model and returns a real prediction.
  Future<void> _submit() async {
    final token = widget.controller.token;
    if (token == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final response = await widget.controller.api.submitAssessment(
        token,
        AssessmentCreate(
          stressLevelSelfReport: _stress ?? 5,
          restHours7d: _rest ?? 6,
          sleepHours7d: _sleep ?? 6,
          workloadScore: _workload ?? 5,
          notes: 'Simulated wellness check-in. $_followUp',
        ),
      );
      if (!mounted) return;
      setState(() {
        _result = response;
        _submitting = false;
      });
      await _loadOrganizationalData();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFacingErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Wellness Check-in'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.gutter),
            child: Center(child: _DemoSimulationChip()),
          ),
        ],
      ),
      body: _step == 0
          ? _buildIntro(context)
          : _step <= _questions.length
              ? _buildQuestion(context)
              : _buildOutcome(context),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        const Center(child: SyntheticDataNotice()),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Low-friction wellness check-in',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Instead of asking personnel to repeatedly enter information that '
          'already exists in organizational systems, this concept uses a short '
          'conversational check-in for the information those systems cannot '
          'provide.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SimulatedCallCard(),
        const SizedBox(height: AppSpacing.lg),
        _OrganizationalInformation(
          duty: _duty,
          loading: _dutyLoading,
        ),
        const SizedBox(height: AppSpacing.lg),
        InlineMessage(
          tone: InlineMessageTone.info,
          message: 'Prototype simulation. There is no real phone call, no '
              'microphone access and no external AI service in this flow — '
              'every response below is an ordinary on-screen button.',
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: () => setState(() => _step = 1),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start simulated check-in'),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('Not now'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const RiskDisclaimerCard(headline: 'Before you begin'),
      ],
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final theme = Theme.of(context);
    final question = _questions[_step - 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          _ProgressBar(step: _step, total: _questions.length),
          const SizedBox(height: AppSpacing.xl),
          const Center(child: _AssistantAvatar()),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Wellness Assistant',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Simulated AI call',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            question.asks,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: ListView(
              children: [
                for (final answer in question.answers) ...[
                  _AnswerButton(
                    label: answer.label,
                    icon: answer.icon,
                    onTap: answer.onSelect,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _step = _step - 1),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Previous question'),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcome(BuildContext context) {
    final theme = Theme.of(context);
    if (_submitting) {
      return const LoadingView(message: 'Recording your responses');
    }
    if (_error != null) {
      return ErrorView(
        message: _error!,
        onRetry: _submit,
      );
    }
    final result = _result;
    if (result == null) {
      return const LoadingView(message: 'Preparing your check-in');
    }
    final prediction = result.prediction;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        const Center(child: SyntheticDataNotice()),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.successBorder),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 38,
              color: AppColors.success,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Check-in completed',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your responses have been recorded for welfare assessment.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        _RecordedSummary(
          stress: _stress,
          workload: _workload,
          rest: _rest,
          sleep: _sleep,
          followUp: _followUp,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (prediction != null) ...[
          SectionCard(
            icon: Icons.insights_outlined,
            title: 'Current Risk Assessment',
            subtitle: 'Produced by the backend XGBoost model from your '
                'check-in and your existing duty records',
            child: Column(
              children: [
                Row(
                  children: [
                    RiskBadge(
                      prediction.riskLevel,
                      dense: true,
                    ),
                    const Spacer(),
                    Text(
                      'Model score ${prediction.probabilityHigh.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  prediction.contributingFactors.isEmpty
                      ? 'No significant contributing factors were recorded.'
                      : prediction.contributingFactors.take(3).join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ] else if (result.predictionSkippedReason != null) ...[
          InlineMessage(
            message:
                'Your check-in was recorded, but no model assessment could be '
                'generated: ${result.predictionSkippedReason}',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (prediction != null)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PredictionResultScreen(
                  controller: widget.controller,
                  result: result,
                ),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('See full result and factors'),
          )
        else
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.done),
            label: const Text('Done'),
          ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to home'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const RiskDisclaimerCard(),
      ],
    );
  }
}

/// Persistent, always-visible "this is a simulation" label.
class _DemoSimulationChip extends StatelessWidget {
  const _DemoSimulationChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppRadii.chip,
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Text(
        'DEMO SIMULATION',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

/// Static avatar for the simulated assistant. Deliberately not an animated or
/// looping graphic — this is a prototype, not a live call.
class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.infoBorder, width: 2),
      ),
      child: const Icon(
        Icons.support_agent_outlined,
        size: 32,
        color: AppColors.brand,
      ),
    );
  }
}

/// The call-style card that introduces the simulated conversation.
class _SimulatedCallCard extends StatelessWidget {
  const _SimulatedCallCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.hero,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _AssistantAvatar(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wellness Assistant', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Quick 2-minute check-in',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: AppRadii.chip,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello. This is your scheduled wellness check-in.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Simulated AI call · 4 questions · on-screen buttons only',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the administrative context that the check-in deliberately does NOT
/// ask the person for. Values are the personnel's own real duty records from
/// the API; the framing is honest about the integration being a prototype.
class _OrganizationalInformation extends StatelessWidget {
  const _OrganizationalInformation({required this.duty, required this.loading});

  final List<DutyRecord> duty;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.account_balance_outlined,
      title: 'Organizational information',
      subtitle: 'Already held for you — so you never have to type it',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              _SourceChip(
                icon: Icons.verified_user_outlined,
                label: 'Source: Authorized organizational systems',
              ),
              _SourceChip(
                icon: Icons.science_outlined,
                label: 'Prototype simulation',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: LinearProgressIndicator(),
            )
          else if (duty.isEmpty) ...[
            Text(
              'No duty, deployment or leave records are available for you yet. '
              'A live deployment would read these from the authorized HR and '
              'establishment systems instead of asking you to enter them.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            _PlannedIntegrationNote(),
          ] else ...[
            Text(
              'Your recent duty context (${duty.length} record'
              '${duty.length == 1 ? '' : 's'}):',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final record in duty.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      _dutyIcon(record.dutyType),
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${_dutyLabel(record.dutyType)} · '
                        '${formatDateOnly(record.recordDate)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${record.dutyHours.toStringAsFixed(1)} h',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            const _PlannedIntegrationNote(),
          ],
        ],
      ),
    );
  }

  static IconData _dutyIcon(DutyType type) => switch (type) {
        DutyType.duty => Icons.work_outline,
        DutyType.deployment => Icons.flight_takeoff_outlined,
        DutyType.leave => Icons.beach_access_outlined,
        DutyType.rest => Icons.bedtime_outlined,
        DutyType.training => Icons.school_outlined,
      };

  static String _dutyLabel(DutyType type) => switch (type) {
        DutyType.duty => 'Duty',
        DutyType.deployment => 'Deployment',
        DutyType.leave => 'Leave',
        DutyType.rest => 'Rest',
        DutyType.training => 'Training',
      };
}

/// Honest boundary statement. This project has no real CAPF/HR integration, so
/// the UI must never imply one exists today.
class _PlannedIntegrationNote extends StatelessWidget {
  const _PlannedIntegrationNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'A live system would read this directly from authorized HR, leave and '
      'establishment records. That integration is planned, not present — this '
      'build has no connection to any external or government system.',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textMuted,
            height: 1.4,
          ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.chip,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        backgroundColor: AppColors.surface,
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question $step of $total',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadii.chip,
          child: LinearProgressIndicator(
            value: step / total,
            minHeight: 6,
            backgroundColor: AppColors.border,
          ),
        ),
      ],
    );
  }
}

/// Echoes exactly what was recorded, so the demo is transparent about the
/// mapping from conversation to the stored assessment.
class _RecordedSummary extends StatelessWidget {
  const _RecordedSummary({
    required this.stress,
    required this.workload,
    required this.rest,
    required this.sleep,
    required this.followUp,
  });

  final int? stress;
  final int? workload;
  final double? rest;
  final double? sleep;
  final String? followUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.checklist_rtl_outlined,
      title: 'What was recorded',
      subtitle: 'Saved through the existing assessment API',
      child: Column(
        children: [
          _row(theme, 'Stress (self-reported)', '$stress / 10'),
          _row(theme, 'Workload (self-reported)', '$workload / 10'),
          _row(theme, 'Rest (7-day average)', '${rest?.toStringAsFixed(1)} h'),
          _row(theme, 'Sleep (7-day average)', '${sleep?.toStringAsFixed(1)} h'),
          _row(theme, 'Follow-up preference', followUp ?? '—'),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}
