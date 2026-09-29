/// History screen.
///
/// Shows the authenticated personnel's own previous assessments and
/// predictions via GET /assessments and GET /predictions. The backend scopes
/// every read to the caller's own records, so no other personnel's data can
/// appear here.
library;

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/risk.dart';
import '../assessment/assessment_form_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<_HistoryData> _future;
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HistoryData> _load() async {
    final token = widget.controller.token;
    if (token == null) {
      throw const ApiException(401, 'Not signed in.');
    }
    final results = await Future.wait([
      widget.controller.api.fetchAssessments(token),
      widget.controller.api.fetchPredictions(token),
    ]);
    final data = _HistoryData(
      results[0] as List<WellnessAssessment>,
      results[1] as List<Prediction>,
    );
    _loadedAt = DateTime.now();
    return data;
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _refresh() async {
    _reload();
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My History')),
      body: FutureBuilder<_HistoryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Loading your records');
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: userFacingErrorMessage(snapshot.error!),
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          if (data.predictions.isEmpty && data.assessments.isEmpty) {
            return EmptyView(
              icon: Icons.timeline_outlined,
              message:
                  'You have not completed a wellness check-in yet. Your past '
                  'check-ins and stress-risk levels will appear here.',
              action: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AssessmentFormScreen(controller: widget.controller),
                  ),
                ),
                child: const Text('Start a check-in'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppSpacing.huge,
              ),
              children: [
                const Center(child: SyntheticDataNotice()),
                const SizedBox(height: AppSpacing.lg),
                if (_loadedAt != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.update,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Last updated ${formatDateTime(_loadedAt!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                if (data.predictions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SectionHeading(
                    title: 'Your results',
                    subtitle: 'Newest first',
                    count: data.predictions.length,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final p in data.predictions)
                    _PredictionTimelineTile(
                      key: ValueKey<String>(p.id),
                      prediction: p,
                    ),
                ],
                if (data.unmatchedAssessments.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.huge),
                  _SectionHeading(
                    title: 'Check-ins without a result',
                    subtitle: 'Waiting on enough recent duty information',
                    count: data.unmatchedAssessments.length,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final a in data.unmatchedAssessments)
                    _AssessmentTimelineTile(
                      key: ValueKey<String>(a.id),
                      assessment: a,
                    ),
                ],
                const SizedBox(height: AppSpacing.huge),
                const RiskDisclaimerCard(headline: 'About these results'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryData {
  _HistoryData(this.assessments, this.predictions);

  final List<WellnessAssessment> assessments;
  final List<Prediction> predictions;

  List<WellnessAssessment> get unmatchedAssessments {
    final predictedIds = predictions
        .map((p) => p.assessmentId)
        .whereType<String>()
        .toSet();
    return assessments.where((a) => !predictedIds.contains(a.id)).toList();
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.brand,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// One entry in the personal results timeline. Expands to reveal the model's
/// confidence and contributing factors.
class _PredictionTimelineTile extends StatelessWidget {
  const _PredictionTimelineTile({super.key, required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = AppRisk.of(prediction.riskLevel);
    final confidence = AppRisk.probabilityOf(prediction, prediction.riskLevel);
    final isPending = prediction.reviewStatus == ReviewStatus.pending;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 22),
            decoration: BoxDecoration(
              color: tone.strong,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Card(
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.card,
                  ),
                  collapsedShape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.card,
                  ),
                  trailing: const Icon(Icons.expand_more, size: 20),
                  title: RiskBadge(
                    prediction.riskLevel,
                    probability: confidence,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prediction.riskLevel.plainMeaning,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatDateTime(prediction.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    _DetailRow(
                      label: 'What happens next',
                      value: prediction.riskLevel.nextStep,
                    ),
                    _DetailRow(
                      label: 'Welfare review',
                      value: isPending
                          ? 'Not yet reviewed'
                          : 'Reviewed by a welfare officer',
                    ),
                    _DetailRow(
                      label: 'Model',
                      value: 'Version ${prediction.modelVersion}',
                    ),
                    if (prediction.contributingFactors.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Contributing model factors',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final factor in prediction.contributingFactors)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  factor,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        'These are model factors, not medical causes.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentTimelineTile extends StatelessWidget {
  const _AssessmentTimelineTile({super.key, required this.assessment});

  final WellnessAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadii.chip,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.pending_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDateTime(assessment.submittedAt),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Self-reported stress ${assessment.stressLevelSelfReport}'
                      '/10 · Workload ${assessment.workloadScore}/10 · '
                      'Rest ${assessment.restHours7d.toStringAsFixed(1)}h · '
                      'Sleep ${assessment.sleepHours7d.toStringAsFixed(1)}h',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
