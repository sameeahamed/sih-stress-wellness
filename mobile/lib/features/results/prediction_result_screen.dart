/// Assessment result — the main screen of the demo.
///
/// Shows the automatic LOW / MEDIUM / HIGH stress-risk prediction returned with
/// the assessment submission (mirrors PredictionRead: risk level, per-class
/// probabilities, contributing factors, model version).
///
/// Design intent: a personnel member is not a data scientist. The screen
/// therefore leads with a large, plain-language result, says what the level
/// means and what happens next, shows the model's confidence as percentages,
/// and ranks the contributing factors while stating clearly that they are
/// model factors rather than medical causes. If the backend skipped the
/// prediction the reason is shown, together with what to do about it.
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/risk.dart';
import '../history/history_screen.dart';

class PredictionResultScreen extends StatelessWidget {
  const PredictionResultScreen({
    super.key,
    required this.controller,
    required this.result,
  });

  final AuthController controller;
  final AssessmentSubmitResponse result;

  @override
  Widget build(BuildContext context) {
    final prediction = result.prediction;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Result'),
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
          const SizedBox(height: AppSpacing.lg),
          if (prediction == null)
            _NoPredictionCard(reason: result.predictionSkippedReason)
          else ...[
            RiskGauge(
              prediction: prediction,
              assessmentTime: result.assessment.submittedAt,
            ),
            const SizedBox(height: AppSpacing.lg),
            _NextStepCard(prediction: prediction),
            if (prediction.riskLevel == RiskLevel.high) ...[
              const SizedBox(height: AppSpacing.lg),
              const WelfareReviewNotice(),
            ],
            const SizedBox(height: AppSpacing.lg),
            ProbabilityBreakdown(prediction: prediction),
            const SizedBox(height: AppSpacing.lg),
            ContributingFactorList(
              factors: prediction.contributingFactors,
              riskLevel: prediction.riskLevel,
              disclaimer: prediction.disclaimer,
            ),
            const SizedBox(height: AppSpacing.lg),
            PredictionProvenance(
              prediction: prediction,
              assessmentTime: result.assessment.submittedAt,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const RiskDisclaimerCard(),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.popUntil((route) => route.isFirst);
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(controller: controller),
                ),
              );
            },
            child: const Text('See my history'),
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
}

/// "What happens next" — the single most important piece of plain language on
/// the screen.
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final level = prediction.riskLevel;
    final tone = AppRisk.of(level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 18, color: AppColors.brand),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'What happens next',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            level.nextStep,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Shown when the backend could not generate a prediction. The usual cause is
/// a lack of recent duty records, so the screen points the user at the fix
/// instead of leaving a dead end.
class _NoPredictionCard extends StatelessWidget {
  const _NoPredictionCard({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppRadii.hero,
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_outlined,
                size: 24,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Your check-in was saved',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A stress-risk level could not be worked out for this check-in yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: AppRadii.chip,
            ),
            child: Text(
              reason ?? 'Not enough recent duty information was available.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'The system needs at least one duty record from the last 30 days '
            'before it can produce a level. Once you have logged one, your '
            'next check-in will include a result.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
