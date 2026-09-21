/// App-level session state: authentication status, the current user, and the
/// stored access token.
///
/// Handles Phase-1 concerns: login, token persistence (never the password),
/// logout, and returning to the login screen when any API call reports 401.
library;

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';
import 'token_store.dart';

enum AuthStatus { restoring, unauthenticated, authenticated }

class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.tokenStore}) {
    api.onUnauthorized = _handleUnauthorized;
  }

  final ApiClient api;
  final TokenStore tokenStore;

  AuthStatus _status = AuthStatus.restoring;
  String? _token;
  CurrentUser? _user;

  AuthStatus get status => _status;
  String? get token => _token;
  CurrentUser? get user => _user;

  /// On a 401 from any endpoint the session is dropped and the auth gate
  /// returns the user to the login screen.
  Future<void> _handleUnauthorized() async {
    await _logout();
  }

  /// Called on startup: try to rehydrate a previously stored token.
  Future<void> restore() async {
    _status = AuthStatus.restoring;
    notifyListeners();
    final stored = await tokenStore.read();
    if (stored == null || stored.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final user = await api.me(stored);
      _token = stored;
      _user = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
    } on ApiException {
      await tokenStore.delete();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (_) {
      await tokenStore.delete();
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// Exchange credentials for a token, persist it, and load the profile.
  ///
  /// Returns null on success, or a human-readable error message.
  Future<String?> login(String username, String password) async {
    try {
      final token = await api.login(username, password);
      await tokenStore.write(token);
      final user = await api.me(token);
      _token = token;
      _user = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Unexpected error. Please try again.';
    }
  }

  Future<void> logout() => _logout();

  Future<void> _logout() async {
    await tokenStore.delete();
    _token = null;
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}