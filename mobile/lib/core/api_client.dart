/// Typed HTTP client for the FastAPI REST API.
///
/// Mirrors the backend contract (see `backend/app/api/routes/`). Every
/// protected request attaches `Authorization: Bearer <token>`. A 401 anywhere
/// triggers the `onUnauthorized` callback so the app can return the user to
/// the login screen.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  /// HTTP status code, or null when the request never reached the server
  /// (network / connection error).
  final int? statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;

  bool get isNetwork => statusCode == null;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Invoked when any request returns 401 (invalid/expired token) so the app
  /// can clear the session and present the login screen.
  VoidCallback? onUnauthorized;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _decode(http.Response res) async {
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }
    if (res.statusCode >= 400) {
      _handleError(res.statusCode, body);
    }
    if (body is Map<String, dynamic>) {
      return body;
    }
    if (body is List && body.isNotEmpty) {
      return {'_list': body};
    }
    if (body is List) {
      return {'_list': <dynamic>[]};
    }
    return <String, dynamic>{};
  }

  void _handleError(int statusCode, dynamic body) {
    if (statusCode == 401) {
      onUnauthorized?.call();
      throw const ApiException(401, 'Session expired. Please log in again.');
    }
    String message = 'Request failed ($statusCode)';
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        message = detail
            .map((e) => e is Map ? e['msg']?.toString() : e.toString())
            .whereType<String>()
            .join('\n');
      }
    }
    throw ApiException(statusCode, message);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? jsonBody,
    Map<String, String>? formBody,
  }) async {
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final http.Response res;
    try {
      switch (method) {
        case 'POST' when formBody != null:
          headers['Content-Type'] = 'application/x-www-form-urlencoded';
          res = await _client.post(_uri(path), headers: headers, body: formBody);
        case 'POST':
          headers['Content-Type'] = 'application/json';
          res = await _client.post(
            _uri(path),
            headers: headers,
            body: jsonBody == null ? null : jsonEncode(jsonBody),
          );
        default:
          res = await _client.get(_uri(path), headers: headers);
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        null,
        'Could not reach the server. Check your connection and try again.',
      );
    }
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw const ApiException(401, 'Session expired. Please log in again.');
    }
    return _decode(res);
  }

  /// POST /auth/token — OAuth2 password flow. Returns the access token.
  Future<String> login(String username, String password) async {
    final body = await _request(
      'POST',
      '/auth/token',
      formBody: {'username': username, 'password': password},
    );
    final token = body['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException(400, 'Login failed: no token returned');
    }
    return token;
  }

  /// GET /auth/me — the authenticated user's own minimal profile.
  Future<CurrentUser> me(String token) async {
    final body = await _request('GET', '/auth/me', token: token);
    return CurrentUser.fromJson(body);
  }

  /// POST /assessments — submit a wellness assessment; returns the saved
  /// assessment with its automatic stress-risk prediction.
  Future<AssessmentSubmitResponse> submitAssessment(
    String token,
    AssessmentCreate assessment,
  ) async {
    final body = await _request(
      'POST',
      '/assessments',
      token: token,
      jsonBody: assessment.toJson(),
    );
    return AssessmentSubmitResponse.fromJson(body);
  }

  /// GET /assessments — the authenticated personnel's own assessments.
  Future<List<WellnessAssessment>> fetchAssessments(String token) async {
    final body = await _request('GET', '/assessments', token: token);
    final list = (body['_list'] as List<dynamic>? ?? []);
    return list
        .map((e) => WellnessAssessment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /duty-records — submit a duty workload record.
  Future<DutyRecord> submitDutyRecord(
    String token,
    DutyRecordCreate record,
  ) async {
    final body = await _request(
      'POST',
      '/duty-records',
      token: token,
      jsonBody: record.toJson(),
    );
    return DutyRecord.fromJson(body);
  }

  /// GET /predictions — the authenticated personnel's own predictions.
  Future<List<Prediction>> fetchPredictions(String token) async {
    final body = await _request('GET', '/predictions', token: token);
    final list = (body['_list'] as List<dynamic>? ?? []);
    return list
        .map((e) => Prediction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}