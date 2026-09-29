/// Personnel home / dashboard.
///
/// Loaded from the authenticated user's own profile via GET /auth/me and the
/// personnel's own latest prediction. Only the personnel's own data is shown:
/// username, role, their opaque pseudonymized personnel key, and their real
/// model result. No score on this screen is invented.
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../assessment/assessment_form_screen.dart';
import '../checkin/wellness_checkin_screen.dart';
import '../duty/duty_record_form_screen.dart';
import '../history/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Prediction? _latest;
  DateTime? _lastCheckIn;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// The "Your current status" card always renders the latest real prediction
  /// the backend returned, and the "Last check-in" line always shows the real
  /// most recent assessment. Nothing here is a placeholder statistic.
  Future<void> _refresh() async {
    final token = widget.controller.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final predictions = await widget.controller.api.fetchPredictions(token);
      final assessments = await widget.controller.api.fetchAssessments(token);
      if (!mounted) return;
      setState(() {
        _latest = predictions.isEmpty ? null : predictions.first;
        _lastCheckIn =
            assessments.isEmpty ? null : assessments.first.submittedAt;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingErrorMessage(error);
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again with your username and password to '
          'view your wellness records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await widget.controller.logout();
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user;
    if (user == null) {
      return const Scaffold(body: LoadingView(message: 'Loading your profile'));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          children: [
            const Center(child: SyntheticDataNotice()),
            const SizedBox(height: AppSpacing.lg),
            _WelcomeHeader(user: user),
            const SizedBox(height: AppSpacing.lg),
            _WelfareCheckinCard(
              lastCheckIn: _lastCheckIn,
              loading: _loading,
              onStart: () => _open(
                context,
                WellnessCheckinScreen(controller: widget.controller),
              ),
              onHistory: () => _open(
                context,
                HistoryScreen(controller: widget.controller),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _CurrentStatusCard(
              prediction: _latest,
              loading: _loading,
              error: _error,
              onRetry: _refresh,
            ),
            const SizedBox(height: AppSpacing.lg),
            _QuickActions(
              controller: widget.controller,
              lastCheckIn: _lastCheckIn,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProfileCard(user: user),
            const SizedBox(height: AppSpacing.lg),
            const RiskDisclaimerCard(),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.user});

  final CurrentUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back', style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                user.username,
                style: theme.textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Your records are private to you and to authorised welfare '
                'staff.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.infoBorder),
          ),
          child: Text(
            user.role.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// The single primary call to action: the low-friction check-in.
class _WelfareCheckinCard extends StatelessWidget {
  const _WelfareCheckinCard({
    required this.lastCheckIn,
    required this.loading,
    required this.onStart,
    required this.onHistory,
  });

  final DateTime? lastCheckIn;
  final bool loading;
  final VoidCallback onStart;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: AppRadii.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: AppRadii.chip,
                ),
                child: const Icon(
                  Icons.support_agent_outlined,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Welfare Check-in',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A quick check-in helps us understand your current workload and '
            'wellbeing.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.history,
                size: 15,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  loading
                      ? 'Checking your last check-in…'
                      : lastCheckIn == null
                          ? 'Last check-in: no check-in recorded yet'
                          : 'Last check-in: ${formatDateTime(lastCheckIn!)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start check-in'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brand,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onHistory,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('View history'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Simulated AI check-in · demo prototype',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

/// Real, backend-produced status. Never a locally derived score.
class _CurrentStatusCard extends StatelessWidget {
  const _CurrentStatusCard({
    required this.prediction,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final Prediction? prediction;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.insights_outlined,
      title: 'Your current status',
      subtitle: 'Current model assessment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const LinearProgressIndicator()
          else if (error != null)
            InlineMessage(message: error!)
          else if (prediction == null)
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'No model assessment yet. Complete a check-in and your '
                    'result will appear here.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            )
          else
            _StatusBody(prediction: prediction!),
        ],
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.prediction});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = AppRisk.of(prediction.riskLevel);
    final score = AppRisk.probabilityOf(prediction, prediction.riskLevel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: tone.soft,
            borderRadius: AppRadii.chip,
            border: Border.all(color: tone.border),
          ),
          child: Row(
            children: [
              Icon(tone.icon, color: tone.onSoft, size: 26),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.riskLevel.label,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: tone.onSoft,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Model score ${score.toStringAsFixed(2)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tone.onSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (prediction.contributingFactors.isNotEmpty) ...[
          Text(
            'Top contributing factor: '
            '${prediction.contributingFactors.first}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          'This is a decision-support signal, not a medical diagnosis.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller, required this.lastCheckIn});

  final AuthController controller;
  final DateTime? lastCheckIn;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.grid_view_outlined,
      title: 'Other things you can do',
      subtitle: 'Full-form options',
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.favorite_outline,
            title: 'Wellness Assessment',
            subtitle: 'The full 1-minute form on stress, rest, sleep and '
                'workload',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AssessmentFormScreen(controller: controller),
              ),
            ),
          ),
          const Divider(height: AppSpacing.xxl),
          _ActionTile(
            icon: Icons.schedule_outlined,
            title: 'Duty Record',
            subtitle: 'Log a duty, deployment, training or leave entry',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DutyRecordFormScreen(controller: controller),
              ),
            ),
          ),
          const Divider(height: AppSpacing.xxl),
          _ActionTile(
            icon: Icons.history,
            title: 'My History',
            subtitle:
                'Past check-ins, risk levels and the reasons behind them',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HistoryScreen(controller: controller),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.chip,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: AppRadii.chip,
              ),
              child: Icon(icon, size: 20, color: AppColors.brand),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final CurrentUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = user.personnelOpaqueKey;
    return SectionCard(
      icon: Icons.person_outline,
      title: 'My profile',
      subtitle: 'Your account details as held by the system',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileRow(label: 'Username', value: user.username),
          const SizedBox(height: AppSpacing.md),
          _ProfileRow(label: 'Role', value: user.role.label),
          if (key != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ProfileRow(
              label: 'Personnel key',
              value: _shortKey(key),
              mono: true,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'A pseudonymous reference used by the system. It contains no '
              'personal details and is not shared outside welfare review.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  /// Shows only the first and last few characters — the full UUID is noise to
  /// a user and the value never needs to be read in full on a phone.
  static String _shortKey(String key) {
    if (key.length <= 12) return key;
    return '${key.substring(0, 8)}…${key.substring(key.length - 4)}';
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}
