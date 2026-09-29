/// Personnel home / dashboard.
///
/// Loaded from the authenticated user's own profile via GET /auth/me. Only the
/// personnel's own data is shown: username, role, and their opaque
/// pseudonymized personnel key (never an internal database id).
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../assessment/assessment_form_screen.dart';
import '../duty/duty_record_form_screen.dart';
import '../history/history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AuthController controller;

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
    await controller.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    if (user == null) {
      return const Scaffold(body: LoadingView(message: 'Loading your profile'));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
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
          _WelcomeHeader(user: user),
          const SizedBox(height: AppSpacing.xl),
          const _WhatThisAppDoes(),
          const SizedBox(height: AppSpacing.lg),
          _QuickActions(controller: controller),
          const SizedBox(height: AppSpacing.lg),
          _ProfileCard(user: user),
          const SizedBox(height: AppSpacing.lg),
          const RiskDisclaimerCard(),
        ],
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
              Text(
                'Welcome, ${user.username}',
                style: theme.textTheme.titleLarge,
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

/// Sets expectations before the user fills in a form. Replaces the previous
/// purely decorative hero block.
class _WhatThisAppDoes extends StatelessWidget {
  const _WhatThisAppDoes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
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
                  Icons.monitor_heart_outlined,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Check in on your wellness',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Log a duty or rest entry, then complete a short wellness '
            'check-in. Each check-in produces a LOW, MEDIUM or HIGH stress-risk '
            'level with the reasons behind it.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.grid_view_outlined,
      title: 'What would you like to do?',
      subtitle: 'Three things you can do in this app',
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.favorite_outline,
            title: 'Wellness Assessment',
            subtitle: 'A 1-minute check-in on stress, rest, sleep and workload',
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
            subtitle: 'Past check-ins, risk levels and the reasons behind them',
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
