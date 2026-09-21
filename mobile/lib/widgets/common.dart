/// Small shared widgets: risk badge, disclaimers, and loading/empty/error
/// states used consistently across the app.
library;

import 'package:flutter/material.dart';

import '../core/models.dart';

/// Colored chip that renders a LOW / MEDIUM / HIGH risk level.
class RiskBadge extends StatelessWidget {
  const RiskBadge(this.level, {super.key});

  final RiskLevel level;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (level) {
      RiskLevel.low => (const Color(0xFFE8F5E9), const Color(0xFF1B5E20)),
      RiskLevel.medium => (const Color(0xFFFFF8E1), const Color(0xFFF57F17)),
      RiskLevel.high => (const Color(0xFFFFEBEE), const Color(0xFFB71C1C)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        level.label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: foreground, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Visible prototype notice shown on every screen (SYNTHETIC DATA only).
class SyntheticDataNotice extends StatelessWidget {
  const SyntheticDataNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const Chip(
      avatar: Icon(Icons.info_outline, size: 18),
      label: Text('SYNTHETIC DEMO DATA'),
    );
  }
}

/// The mandatory disclaimer: a prediction is a risk indicator, never a
/// medical diagnosis.
class RiskDisclaimerCard extends StatelessWidget {
  const RiskDisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.health_and_safety_outlined, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'This is a risk indicator, not a medical diagnosis.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}