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

enum AuthStatus {
  restoring,

  /// No usable stored session; the login screen must be shown.
  unauthenticated,

  /// A stored token was verified against the API.
  authenticated,

  /// A stored token is present but could not be verified because the network
  /// was unreachable. The token is deliberately KEPT: the session may still be
  /// valid, and dropping it here would sign the user out for a connectivity
  /// blip. Retrying is the user's decision.
  offline,
}

class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.tokenStore}) {
    api.onUnauthorized = _handleUnauthorized;
  }

  final ApiClient api;
  final TokenStore tokenStore;

  AuthStatus _status = AuthStatus.restoring;
  String? _token;
  CurrentUser? _user;
  String? _restoreError;

  AuthStatus get status => _status;
  String? get token => _token;
  CurrentUser? get user => _user;

  /// Why the last restore could not complete, when it could not.
  String? get restoreError => _restoreError;

  /// On a 401 from any endpoint the session is dropped and the auth gate
  /// returns the user to the login screen.
  Future<void> _handleUnauthorized() async {
    await _logout();
  }

  /// Called on startup: try to rehydrate a previously stored token.
  ///
  /// Every step is guarded so no failure mode can leave the app stuck on the
  /// restoring screen. Secure storage can throw (a corrupt or unreadable
  /// Keystore entry after a device restore), and the token is only discarded
  /// when the server actively rejects it - not when the network is down.
  Future<void> restore() async {
    _status = AuthStatus.restoring;
    _restoreError = null;
    notifyListeners();
    try {
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
      } on ApiException catch (e) {
        if (e.isUnauthorized) {
          // The server rejected the token, so it is genuinely dead.
          await _discardToken();
        } else {
          // Server reachable but unhappy (5xx, etc): keep the token, let the
          // user retry rather than forcing a re-login.
          _restoreError = 'Could not verify your session. Please try again.';
          _status = AuthStatus.offline;
        }
        notifyListeners();
      } on Object {
        // Network unreachable. The stored token may still be valid.
        _restoreError =
            'Cannot reach the server. Check your connection and try again.';
        _status = AuthStatus.offline;
        notifyListeners();
      }
    } on Object {
      // Secure storage itself failed. Nothing can be restored, but the app
      // must still leave the restoring state rather than hang.
      _restoreError = 'Could not read your saved session. Please sign in again.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// Retry a restore that failed because the network was unavailable.
  Future<void> retryRestore() async {
    _status = AuthStatus.restoring;
    notifyListeners();
    await restore();
  }

  Future<void> _discardToken() async {
    try {
      await tokenStore.delete();
    } on Object {
      // If the delete fails the in-memory session is still cleared below, and
      // the next restore will retry the cleanup.
    }
    _token = null;
    _user = null;
  }

  /// Exchange credentials for a token, persist it, and load the profile.
  ///
  /// Returns null on success, or a human-readable error message.
  Future<String?> login(String username, String password) async {
    try {
      final token = await api.login(username, password);
      try {
        await tokenStore.write(token);
      } on Object {
        // Persisting failed, so this session cannot survive a restart. Fail
        // the login rather than leaving the user in a session that vanishes.
        return 'Could not save your session securely. Please try again.';
      }
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
    await _discardToken();
    _restoreError = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}