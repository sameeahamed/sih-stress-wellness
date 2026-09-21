import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/session.dart';
import 'core/token_store.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'widgets/common.dart';

void main() {
  runApp(SihStressWellnessApp(
    apiClient: ApiClient(baseUrl: AppConfig.apiBaseUrl),
    tokenStore: SecureTokenStore(),
  ));
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
    _controller.restore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stress & Welfare Monitoring',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          primary: const Color(0xFF3F51B5),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F6FB),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE3E8F1)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4DCE9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4DCE9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 2),
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          switch (_controller.status) {
            case AuthStatus.restoring:
              return const Scaffold(body: LoadingView());
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
          }
        },
      ),
    );
  }
}