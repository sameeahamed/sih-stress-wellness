/// App entry point and auth gate.
///
/// The whole app is themed from a single Material 3 definition
/// (`theme/app_theme.dart`); no screen defines its own colours or type.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/session.dart';
import 'core/token_store.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

void main() {
  runApp(
    SihStressWellnessApp(
      apiClient: ApiClient(baseUrl: AppConfig.apiBaseUrl),
      tokenStore: SecureTokenStore(),
    ),
  );
}

class SihStressWellnessApp extends StatefulWidget {
  const SihStressWellnessApp({
    super.key,
    required this.apiClient,
    required this.tokenStore,
  });

  final ApiClient apiClient;
  final TokenStore tokenStore;

  @override
  State<SihStressWellnessApp> createState() => _SihStressWellnessAppState();
}

class _SihStressWellnessAppState extends State<SihStressWellnessApp> {
  late final AuthController _controller;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _controller = AuthController(
      api: widget.apiClient,
      tokenStore: widget.tokenStore,
    );
    // Fire-and-forget, but never unhandled: restore() already contains its own
    // fallbacks, and this guards against a future change reintroducing a throw
    // that would leave the app stuck on the restoring view.
    unawaited(_controller.restore().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppIdentity.productName,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      home: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          switch (_controller.status) {
            case AuthStatus.restoring:
              return const _RestoringView();
            case AuthStatus.unauthenticated:
              // A 401 (or logout) while a feature screen is pushed above the
              // home route must collapse the stack so the login screen is
              // actually visible again.
              final navigator = _navigatorKey.currentState;
              if (navigator != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  navigator.popUntil((route) => route.isFirst);
                });
              }
              return LoginScreen(controller: _controller);
            case AuthStatus.authenticated:
              return HomeScreen(controller: _controller);
            case AuthStatus.offline:
              // The stored token is intact but unverifiable right now. Offer
              // a retry rather than a login form, so the user is not forced to
              // re-authenticate for a connectivity problem.
              return _RestoreFailedView(
                message:
                    _controller.restoreError ??
                    'Cannot reach the server right now.',
                onRetry: () => unawaited(_controller.retryRestore()),
              );
          }
        },
      ),
    );
  }
}

/// Shown when a stored session exists but could not be revalidated because the
/// server was unreachable. The session is kept; the user retries.
class _RestoreFailedView extends StatelessWidget {
  const _RestoreFailedView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppMark(size: 64),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppIdentity.productName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                button: true,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your session is still saved on this device.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Branded splash shown while a stored session is revalidated, so the first
/// frame of the app is never a bare spinner on an empty screen.
class _RestoringView extends StatelessWidget {
  const _RestoringView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppMark(size: 64),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppIdentity.productName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Restoring your secure session…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
