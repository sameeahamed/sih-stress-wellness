/// Phase 5 — Prediction result screen.
///
/// Shows the automatic LOW / MEDIUM / HIGH stress-risk prediction returned
/// with the assessment submission (mirrors PredictionRead: risk level, per-
/// class probabilities, SHAP contributing factors, model version). The result
/// is explicitly framed as a risk indicator, not a medical diagnosis. If the
/// backend skipped the prediction (e.g. not enough duty data) the reason is
/// shown instead.
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';
import '../../features/history/history_screen.dart';

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
        title: const Text('Assessment Result'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: SyntheticDataNotice()),
          const SizedBox(height: 16),
          const RiskDisclaimerCard(),
          const SizedBox(height: 16),
          if (prediction == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 32),
                    const SizedBox(height: 8),
                    Text('Assessment submitted',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'A stress-risk prediction was not generated for this '
                      'submission.',
                    ),
                    if (result.predictionSkippedReason != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        result.predictionSkippedReason!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Predicted stress-risk level',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Center(child: RiskBadge(prediction.riskLevel)),
                    const SizedBox(height: 12),
                    Text(
                      'AI-generated welfare risk indicator — not a medical '
                      'diagnosis.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _ProbabilityBar(
                      label: 'LOW',
                      value: prediction.probabilityLow,
                      color: Colors.green.shade700,
                    ),
                    _ProbabilityBar(
                      label: 'MEDIUM',
                      value: prediction.probabilityMedium,
                      color: Colors.amber.shade800,
                    ),
                    _ProbabilityBar(
                      label: 'HIGH',
                      value: prediction.probabilityHigh,
                      color: Colors.red.shade700,
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.model_training,
                            size: 18, color: Color(0xFF8896AB)),
                        const SizedBox(width: 6),
                        Text(
                          'Model ${prediction.modelVersion}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        const Icon(Icons.schedule,
                            size: 16, color: Color(0xFF8896AB)),
                        const SizedBox(width: 6),
                        Text(
                          formatDateTime(result.assessment.submittedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (prediction.contributingFactors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contributing factors',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'Model-derived contributing factors (SHAP). These are '
                        'risk factors for the model output, not diagnoses.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      for (final factor in prediction.contributingFactors)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(Icons.circle,
                                    size: 8, color: Colors.blueGrey),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(factor)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
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
            child: const Text('View history'),
          ),
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

class _ProbabilityBar extends StatelessWidget {
  const _ProbabilityBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clamped,
                minHeight: 10,
                color: color,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              (clamped * 100).round().toString(),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}