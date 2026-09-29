/// Widgets for presenting an AI stress-risk result in plain language.
///
/// The model's output is a risk *level* plus a confidence, and the contributing
/// factors are model factors — not medical causes. Everything here exists to
/// communicate that honestly to a non-technical reader.
///
/// Nothing in this file invents a number: the probability shown is the model's
/// own output, and factor "bars" encode only the ordering the backend already
/// provides (the API returns factors sorted by descending influence).
library;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Plain-language wording for each risk level, written for uniformed
/// personnel rather than for data scientists.
extension RiskLevelCopy on RiskLevel {
  /// One short, non-clinical sentence describing the level.
  String get plainMeaning => switch (this) {
    RiskLevel.low =>
      'Your recent duty, rest and self-reported wellness look stable. No '
          'follow-up is suggested right now.',
    RiskLevel.medium =>
      'Some strain is showing in your recent duty and rest pattern. Worth '
          'keeping an eye on and improving rest where you can.',
    RiskLevel.high =>
      'Your recent duty, rest and self-reported wellness indicate you may '
          'be under significant strain and would benefit from support.',
  };

  /// What happens next, stated plainly.
  String get nextStep => switch (this) {
    RiskLevel.low =>
      'Keep logging your duty and wellness check-ins. You can view your '
          'past results at any time.',
    RiskLevel.medium =>
      'Try to protect rest and sleep, and submit a wellness check-in '
          'again soon to see whether the level changes.',
    RiskLevel.high =>
      'This result is recorded in your wellness history, where an authorised '
          'welfare officer or commander can see it alongside your duty and rest '
          'records. If you need support, speak to your welfare officer or '
          'medical officer. No action is taken automatically.',
  };

  /// Short label used inside the gauge.
  String get shortLabel => switch (this) {
    RiskLevel.low => 'Low',
    RiskLevel.medium => 'Medium',
    RiskLevel.high => 'High',
  };
}

/// The headline LOW / MEDIUM / HIGH result.
///
/// Shows a three-step scale with the predicted level filled in, the model's
/// confidence for that level as a percentage, and a plain-language
/// explanation of what the level means and what happens next.
class RiskGauge extends StatelessWidget {
  const RiskGauge({super.key, required this.prediction, this.assessmentTime});

  final Prediction prediction;

  /// When the underlying assessment was submitted, shown as provenance.
  final DateTime? assessmentTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = prediction.riskLevel;
    final tone = AppRisk.of(level);
    final confidence = AppRisk.probabilityOf(prediction, level);

    return Semantics(
      container: true,
      label:
          'Stress risk level ${level.label}. Model score '
          '${confidence.clamp(0.0, 1.0).toStringAsFixed(2)}, not a probability '
          'of a medical condition. ${level.plainMeaning}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: tone.soft,
          borderRadius: AppRadii.hero,
          border: Border.all(color: tone.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your stress-risk level',
              style: theme.textTheme.labelMedium?.copyWith(
                color: tone.onSoft,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(tone.icon, size: 40, color: tone.onSoft),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    level.shortLabel,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: tone.onSoft,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _ScaleTrack(prediction: prediction, active: level),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Model score for this level: '
              '${confidence.clamp(0.0, 1.0).toStringAsFixed(2)}',
              style: theme.textTheme.titleSmall?.copyWith(color: tone.onSoft),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This score is how strongly the model leaned toward this level. '
              'It is not the chance of a medical condition, and it is not a '
              'diagnosis.',
              style: theme.textTheme.bodySmall?.copyWith(color: tone.onSoft),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              level.plainMeaning,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three-step LOW / MEDIUM / HIGH scale with the predicted step highlighted.
class _ScaleTrack extends StatelessWidget {
  const _ScaleTrack({required this.prediction, required this.active});

  final Prediction prediction;
  final RiskLevel active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < AppRisk.scale.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _ScaleStep(
              level: AppRisk.scale[i],
              probability: AppRisk.probabilityOf(prediction, AppRisk.scale[i]),
              isActive: AppRisk.scale[i] == active,
            ),
          ),
        ],
      ],
    );
  }
}

class _ScaleStep extends StatelessWidget {
  const _ScaleStep({
    required this.level,
    required this.probability,
    required this.isActive,
  });

  final RiskLevel level;
  final double probability;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = AppRisk.of(level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          level.label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isActive ? tone.onSoft : AppColors.textMuted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: probability.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.75),
            valueColor: AlwaysStoppedAnimation<Color>(
              isActive ? tone.strong : tone.strong.withValues(alpha: 0.28),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(probability.clamp(0.0, 1.0) * 100).round()}%',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isActive ? tone.onSoft : AppColors.textMuted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// The model's confidence for each of the three levels, in percentages.
class ProbabilityBreakdown extends StatelessWidget {
  const ProbabilityBreakdown({super.key, required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.donut_large_outlined,
      title: 'How the model arrived at this level',
      subtitle: 'Model score for each possible level, as a percentage',
      child: Column(
        children: [
          for (final level in AppRisk.scale) ...[
            _ProbabilityRow(
              level: level,
              value: AppRisk.probabilityOf(prediction, level),
            ),
            if (level != AppRisk.scale.last)
              const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'These are the model\'s own outputs on a 0-100% scale. They show '
            'how strongly the model leaned towards each level. They are not a '
            'measurement of your stress, and not a medical assessment.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ProbabilityRow extends StatelessWidget {
  const _ProbabilityRow({required this.level, required this.value});

  final RiskLevel level;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = AppRisk.of(level);
    final clamped = value.clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            level.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 10,
              backgroundColor: tone.soft,
              valueColor: AlwaysStoppedAnimation<Color>(tone.strong),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 44,
          child: Text(
            '${(clamped * 100).round()}%',
            textAlign: TextAlign.right,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The SHAP-derived contributing factors, ranked by influence.
///
/// The backend returns the factors already sorted by descending influence and
/// deliberately exposes no raw SHAP magnitudes, so the rank bars below encode
/// ordering only — the strongest factor is drawn longest. No number is
/// invented.
class ContributingFactorList extends StatelessWidget {
  const ContributingFactorList({
    super.key,
    required this.factors,
    this.riskLevel,
    this.disclaimer,
  });

  final List<String> factors;

  /// Used to phrase the heading correctly. A LOW/MEDIUM result is explained
  /// by the factors that held assessed risk down, so a "flagged this" heading
  /// would misdescribe them.
  final RiskLevel? riskLevel;

  /// Non-causal, non-medical wording authored by the backend model layer.
  final String? disclaimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The factor list is always explained relative to HIGH risk, so the
    // wording has to follow the direction of the result. Calling protective
    // factors "what pushed this up" would be simply wrong for LOW/MEDIUM.
    final (String title, String subtitle) = switch (riskLevel) {
      RiskLevel.high => (
          'Why this assessment?',
          'Factors contributing toward higher risk',
        ),
      RiskLevel.medium => (
          'Why this assessment?',
          'Factors influencing this assessment',
        ),
      RiskLevel.low => (
          'Why this assessment?',
          'Factors supporting a lower risk assessment',
        ),
      null => (
          'Why this assessment?',
          'Contributing model factors',
        ),
    };

    if (factors.isEmpty) {
      return SectionCard(
        icon: Icons.rule_outlined,
        title: title,
        subtitle: subtitle,
        child: Text(
          'No significant contributing factors were recorded for this result.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    final count = factors.length;
    return SectionCard(
      icon: Icons.rule_outlined,
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < count; i++) ...[
            _FactorRow(rank: i + 1, total: count, label: factors[i]),
            if (i != count - 1) const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: AppRadii.chip,
              border: Border.all(color: AppColors.infoBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    disclaimer ??
                        'These are contributing model factors — the things the '
                            'model weighed most. They are not medical causes, '
                            'diagnoses, or a judgement about you.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.rank,
    required this.total,
    required this.label,
  });

  /// 1-based position in the ranked list.
  final int rank;

  /// Total number of factors, used for the relative rank bar.
  final int total;

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ordering only: the first factor is drawn longest. This is not a SHAP
    // magnitude and must not be read as one.
    final weight = (total - rank + 1) / total;
    return Semantics(
      label: 'Factor $rank of $total: $label',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.brand,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  _sentenceCase(label),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: weight,
                minHeight: 4,
                backgroundColor: AppColors.brandSoft,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF93AEEB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Provenance footer for a prediction: model version, when it was produced and
/// a reminder of what the output is.
class PredictionProvenance extends StatelessWidget {
  const PredictionProvenance({
    super.key,
    required this.prediction,
    this.assessmentTime,
  });

  final Prediction prediction;
  final DateTime? assessmentTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // This prototype has no review action, so the status is reported as a
    // record state rather than promising a workflow that does not exist.
    final review = prediction.reviewStatus == ReviewStatus.pending
        ? 'Not yet actioned by a welfare officer'
        : 'Marked reviewed by a welfare officer';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.policy_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('About this result', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ProvenanceRow(
            label: 'Model',
            value: 'Version ${prediction.modelVersion}',
          ),
          _ProvenanceRow(
            label: 'Generated',
            value: formatDateTime(prediction.createdAt),
          ),
          if (assessmentTime != null)
            _ProvenanceRow(
              label: 'Assessment submitted',
              value: formatDateTime(assessmentTime!),
            ),
          _ProvenanceRow(label: 'Welfare review', value: review),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Generated by a prototype model trained on synthetic demo data. '
            'It supports human judgement; it never replaces it.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ProvenanceRow extends StatelessWidget {
  const _ProvenanceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Human-in-the-loop panel shown for HIGH results, explaining what will
/// happen to the record.
class WelfareReviewNotice extends StatelessWidget {
  const WelfareReviewNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppColors.infoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.groups_outlined,
                  size: 20,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'A human decides, not the model',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This result is recorded against your wellness history, where an '
            'authorised welfare officer or commander can see it alongside your '
            'duty and rest records. Any support is decided by a person in '
            'conversation with you, not by this screen.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nothing is shared outside that review, and no decision about your '
            'duty, posting or career is made automatically.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Uppercases the first character so backend factor phrases such as
/// "elevated weekly duty hours" read as sentences.
String _sentenceCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
