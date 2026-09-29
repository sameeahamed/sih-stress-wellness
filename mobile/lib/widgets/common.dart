/// Small shared widgets used consistently across the app: the risk badge,
/// prototype / disclaimer notices, section cards, form banners, and the
/// loading / empty / error states.
library;

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../theme/app_theme.dart';

/// Neutral geometric app mark. Intentionally not a crest, emblem or any other
/// official-looking insignia — this is a prototype and must not imply
/// government ownership.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.shield_outlined, size: size * 0.5, color: Colors.white),
    );
  }
}

/// Colored chip that renders a LOW / MEDIUM / HIGH risk level.
///
/// Risk is never encoded by colour alone: the level word and a severity icon
/// are always shown as well.
class RiskBadge extends StatelessWidget {
  const RiskBadge(
    this.level, {
    super.key,
    this.probability,
    this.dense = false,
  });

  final RiskLevel level;

  /// Optional model confidence (0..1) shown next to the level.
  final double? probability;

  /// Compact variant for dense lists.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tone = AppRisk.of(level);
    final theme = Theme.of(context);
    final label = probability == null
        ? level.label
        : '${level.label}  ${(probability!.clamp(0.0, 1.0) * 100).round()}%';
    return Semantics(
      label:
          'Stress risk level ${level.label}'
          '${probability == null ? '' : ', ${(probability!.clamp(0.0, 1.0) * 100).round()} percent confidence'}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10,
          vertical: dense ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: tone.soft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tone.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tone.icon, size: dense ? 13 : 15, color: tone.onSoft),
            const SizedBox(width: 5),
            Text(
              label,
              style:
                  (dense
                          ? theme.textTheme.labelSmall
                          : theme.textTheme.labelMedium)
                      ?.copyWith(
                        color: tone.onSoft,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet, always-visible prototype notice. It states clearly that the demo
/// runs on synthetic data, without competing with the screen's real content.
class SyntheticDataNotice extends StatelessWidget {
  const SyntheticDataNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.chip,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.science_outlined,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              'SYNTHETIC DEMO DATA',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The mandatory disclaimer: the result is a risk indicator for early
/// intervention, never a medical diagnosis and never an automatic decision.
class RiskDisclaimerCard extends StatelessWidget {
  const RiskDisclaimerCard({
    super.key,
    this.headline = 'What this result means',
  });

  final String headline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 20, color: AppColors.info),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This is a risk indicator, not a medical diagnosis.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'It is decision support only. A HIGH result is always '
                  'reviewed by a human welfare officer before any action is '
                  'taken.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
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

/// A titled card used to group related form fields or list rows.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brandSoft,
                      borderRadius: AppRadii.chip,
                    ),
                    child: Icon(icon, size: 20, color: AppColors.brand),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

/// Inline, non-blocking message for a failed submission or a form warning.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.message,
    this.tone = InlineMessageTone.error,
  });

  final String message;
  final InlineMessageTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, Color border, IconData icon) = switch (tone) {
      InlineMessageTone.error => (
        AppColors.danger,
        AppColors.dangerSoft,
        AppColors.dangerBorder,
        Icons.error_outline,
      ),
      InlineMessageTone.info => (
        AppColors.info,
        AppColors.infoSoft,
        AppColors.infoBorder,
        Icons.info_outline,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadii.chip,
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: fg, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum InlineMessageTone { error, info }

/// A persistent bottom action bar so the primary button is always reachable,
/// even when a long form is scrolled.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Spinner shown while a screen loads its data.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a list has nothing to display yet.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;

  /// Optional call to action, e.g. "Start an assessment".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.brand),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when a request failed, with a plain-language explanation and a
/// retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 30,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Turns a raw API/parsing failure into something a uniformed officer can act
/// on. Technical wording is dropped; the user's next step is stated instead.
///
/// Where the backend has already supplied a specific, plain-English reason
/// (for example a field validation message) that reason is kept, because it is
/// more useful than any generic fallback.
String userFacingErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.isNetwork) {
      return 'We could not reach the server. Please check your connection and '
          'try again.';
    }
    if (error.isUnauthorized) {
      return 'Your session has ended. Please sign in again.';
    }
    final hasDetail =
        error.message.isNotEmpty && !error.message.startsWith('Request failed');
    final status = error.statusCode ?? 0;
    if (status >= 500) {
      return 'The server is having trouble right now. Please try again in a '
          'moment.';
    }
    if (hasDetail) {
      return error.message;
    }
    if (status == 0) {
      return 'The request could not be completed. Please try again.';
    }
    return 'Something went wrong while saving your entry. Please try again.';
  }
  if (error is FormatException) {
    return 'The server sent a response the app could not read. Please try '
        'again.';
  }
  return 'Something went wrong. Please try again.';
}
