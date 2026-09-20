/// Deterministic in-memory ApiClient fake for widget/unit tests.
///
/// Mirrors the methods the app uses so widget tests can drive the full
/// login → home → assessment → prediction → history → logout flow without any
/// network access.
library;

import 'package:sih_stress_wellness/core/api_client.dart';
import 'package:sih_stress_wellness/core/models.dart';
import 'package:sih_stress_wellness/core/session.dart';
import 'package:sih_stress_wellness/core/token_store.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(baseUrl: 'http://fake');

  bool failLogin = false;
  String? loginErrorDetail;
  bool failMe = false;
  bool failRestoreWith401 = false;

  CurrentUser meUser = CurrentUser(
    username: 'demo_personnel',
    role: Role.personnel,
    isActive: true,
    personnelOpaqueKey: '11111111-1111-1111-1111-111111111111',
  );

  AssessmentSubmitResponse Function()? onSubmitAssessment;
  ApiException? submitAssessmentError;

  DutyRecord Function()? onSubmitDutyRecord;
  ApiException? submitDutyRecordError;

  List<WellnessAssessment> assessments = [];
  List<Prediction> predictions = [];

  @override
  Future<String> login(String username, String password) async {
    if (failLogin) {
      throw ApiException(401, loginErrorDetail ?? 'Incorrect username or password');
    }
    return 'test-token';
  }

  @override
  Future<CurrentUser> me(String token) async {
    if (failRestoreWith401) {
      onUnauthorized?.call();
      throw const ApiException(401, 'Invalid or expired token');
    }
    if (failMe) {
      throw const ApiException(500, 'Server error');
    }
    return meUser;
  }

  @override
  Future<AssessmentSubmitResponse> submitAssessment(
    String token,
    AssessmentCreate assessment,
  ) async {
    if (submitAssessmentError != null) {
      onUnauthorized?.call();
      throw submitAssessmentError!;
    }
    final response = onSubmitAssessment;
    if (response != null) return response();
    return AssessmentSubmitResponse(
      assessment: WellnessAssessment(
        id: 'a1',
        personnelKey: meUser.personnelOpaqueKey!,
        stressLevelSelfReport: assessment.stressLevelSelfReport,
        restHours7d: assessment.restHours7d,
        sleepHours7d: assessment.sleepHours7d,
        workloadScore: assessment.workloadScore,
        submittedAt: DateTime.utc(2026, 9, 20, 10),
        createdAt: DateTime.utc(2026, 9, 20, 10),
      ),
      prediction: Prediction(
        id: 'p1',
        personnelKey: meUser.personnelOpaqueKey!,
        riskLevel: RiskLevel.high,
        probabilityLow: 0.1,
        probabilityMedium: 0.2,
        probabilityHigh: 0.7,
        contributingFactors: const ['elevated weekly duty hours'],
        modelVersion: 'v1',
        reviewStatus: ReviewStatus.pending,
        createdAt: DateTime.utc(2026, 9, 20, 10),
      ),
      predictionSkippedReason: null,
    );
  }

  @override
  Future<List<WellnessAssessment>> fetchAssessments(String token) async {
    return assessments;
  }

  @override
  Future<List<Prediction>> fetchPredictions(String token) async {
    return predictions;
  }

  @override
  Future<DutyRecord> submitDutyRecord(
    String token,
    DutyRecordCreate record,
  ) async {
    if (submitDutyRecordError != null) {
      onUnauthorized?.call();
      throw submitDutyRecordError!;
    }
    final response = onSubmitDutyRecord;
    if (response != null) return response();
    return DutyRecord(
      id: 'r1',
      personnelKey: meUser.personnelOpaqueKey!,
      recordDate: record.recordDate,
      dutyType: record.dutyType,
      dutyHours: record.dutyHours ?? 8.0,
      startTime: record.startTime,
      endTime: record.endTime,
      createdAt: DateTime.utc(2026, 9, 19, 16),
      updatedAt: DateTime.utc(2026, 9, 19, 16),
    );
  }
}

/// Builds an authenticated [AuthController] backed by a fake client.
Future<({AuthController controller, FakeApiClient api})> authenticatedController({
  FakeApiClient? api,
  bool seededStore = true,
}) async {
  final fake = api ?? FakeApiClient();
  final store = InMemoryTokenStore();
  if (seededStore) {
    await store.write('test-token');
  }
  final controller = AuthController(api: fake, tokenStore: store);
  await controller.restore();
  return (controller: controller, api: fake);
}