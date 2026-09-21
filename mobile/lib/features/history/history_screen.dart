/// Phase 6 — History screen.
///
/// Shows the authenticated personnel's own previous assessments, predictions,
/// dates and risk levels (via GET /assessments and GET /predictions). The
/// backend scopes every read to the caller's own records, so no other
/// personnel's data can appear here.
library;

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<_HistoryData> _future;

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
    final assessments =
        await widget.controller.api.fetchAssessments(token);
    final predictions =
        await widget.controller.api.fetchPredictions(token);
    return _HistoryData(assessments, predictions);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<_HistoryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Loading your records…');
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          if (data.assessments.isEmpty && data.predictions.isEmpty) {
            return const EmptyView(
              icon: Icons.inbox_outlined,
              message:
                  'No records yet. Submit a wellness assessment to get started.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final _ = await _load();
              _reload();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Center(child: SyntheticDataNotice()),
                const SizedBox(height: 12),
                if (data.predictions.isNotEmpty) ...[
                  Text('Predictions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final p in data.predictions)
                    _PredictionCard(prediction: p),
                ],
                if (data.unmatchedAssessments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Assessments without a prediction',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final a in data.unmatchedAssessments)
                    _AssessmentCard(assessment: a),
                ],
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
    return assessments
        .where((a) => !predictedIds.contains(a.id))
        .toList();
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final factorCount = prediction.contributingFactors.length;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                  child: Icon(Icons.insights_outlined,
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDateTime(prediction.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Model ${prediction.modelVersion} · '
                        'review: ${prediction.reviewStatus.label}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                RiskBadge(prediction.riskLevel),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Confidence — LOW ${(prediction.probabilityLow * 100).round()} · '
              'MEDIUM ${(prediction.probabilityMedium * 100).round()} · '
              'HIGH ${(prediction.probabilityHigh * 100).round()}',
              style: theme.textTheme.bodySmall,
            ),
            if (factorCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Factors: ${prediction.contributingFactors.take(2).join('; ')}'
                '${factorCount > 2 ? ' …' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment});

  final WellnessAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.fact_check_outlined,
                  color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDateTime(assessment.submittedAt),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stress report ${assessment.stressLevelSelfReport}/10 · '
                    'Workload ${assessment.workloadScore}/10 · '
                    'Rest ${assessment.restHours7d.toStringAsFixed(1)}h · '
                    'Sleep ${assessment.sleepHours7d.toStringAsFixed(1)}h',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}