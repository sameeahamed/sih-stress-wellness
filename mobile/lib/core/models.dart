/// Data models mirroring the FastAPI backend response/request schemas.
///
/// Field names match the API contract exactly (see
/// `backend/app/schemas/`). Only opaque pseudonymized keys are ever held —
/// the app never deals with internal personnel IDs beyond what /auth/me
/// returns for the authenticated user's own profile.
library;

enum Role {
  personnel('personnel', 'Personnel'),
  welfareOfficer('welfare_officer', 'Welfare Officer'),
  commander('commander', 'Commander'),
  administrator('administrator', 'Administrator');

  const Role(this.wire, this.label);

  final String wire;
  final String label;

  static Role fromWire(String value) =>
      Role.values.firstWhere((r) => r.wire == value, orElse: () => Role.personnel);
}

enum RiskLevel {
  low('low', 'LOW'),
  medium('medium', 'MEDIUM'),
  high('high', 'HIGH');

  const RiskLevel(this.wire, this.label);

  final String wire;
  final String label;

  static RiskLevel fromWire(String value) => RiskLevel.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => RiskLevel.medium,
      );
}

enum DutyType {
  duty('duty', 'Duty'),
  deployment('deployment', 'Deployment'),
  leave('leave', 'Leave'),
  rest('rest', 'Rest'),
  training('training', 'Training');

  const DutyType(this.wire, this.label);

  final String wire;
  final String label;

  static DutyType fromWire(String value) =>
      DutyType.values.firstWhere((d) => d.wire == value, orElse: () => DutyType.duty);
}

enum ReviewStatus {
  pending('pending', 'Pending'),
  reviewed('reviewed', 'Reviewed');

  const ReviewStatus(this.wire, this.label);

  final String wire;
  final String label;

  static ReviewStatus fromWire(String value) => ReviewStatus.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => ReviewStatus.pending,
      );
}

/// `POST /auth/token` response body.
class Token {
  const Token({required this.accessToken, required this.tokenType});

  final String accessToken;
  final String tokenType;

  factory Token.fromJson(Map<String, dynamic> json) => Token(
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
      );
}

/// `GET /auth/me` response body.
class CurrentUser {
  const CurrentUser({
    required this.username,
    required this.role,
    required this.isActive,
    this.personnelOpaqueKey,
  });

  final String username;
  final Role role;
  final bool isActive;

  /// The authenticated user's own opaque pseudonymized personnel key, when
  /// the account is linked to a personnel record. Never another person's key.
  final String? personnelOpaqueKey;

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        username: json['username'] as String,
        role: Role.fromWire(json['role'] as String),
        isActive: json['is_active'] as bool? ?? true,
        personnelOpaqueKey: json['personnel_opaque_key'] as String?,
      );
}

/// Request body for `POST /assessments` (mirrors WellnessAssessmentCreate).
class AssessmentCreate {
  const AssessmentCreate({
    required this.stressLevelSelfReport,
    required this.restHours7d,
    required this.sleepHours7d,
    required this.workloadScore,
    this.notes,
  });

  final int stressLevelSelfReport;
  final double restHours7d;
  final double sleepHours7d;
  final int workloadScore;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'stress_level_self_report': stressLevelSelfReport,
        'rest_hours_7d': restHours7d,
        'sleep_hours_7d': sleepHours7d,
        'workload_score': workloadScore,
        if (notes != null) 'notes': notes,
      };
}

/// `GET /assessments` item (mirrors WellnessAssessmentRead).
class WellnessAssessment {
  const WellnessAssessment({
    required this.id,
    required this.personnelKey,
    required this.stressLevelSelfReport,
    required this.restHours7d,
    required this.sleepHours7d,
    required this.workloadScore,
    required this.submittedAt,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String personnelKey;
  final int stressLevelSelfReport;
  final double restHours7d;
  final double sleepHours7d;
  final int workloadScore;
  final String? notes;
  final DateTime submittedAt;
  final DateTime createdAt;

  factory WellnessAssessment.fromJson(Map<String, dynamic> json) =>
      WellnessAssessment(
        id: json['id'] as String,
        personnelKey: json['personnel_key'] as String,
        stressLevelSelfReport: json['stress_level_self_report'] as int,
        restHours7d: (json['rest_hours_7d'] as num).toDouble(),
        sleepHours7d: (json['sleep_hours_7d'] as num).toDouble(),
        workloadScore: json['workload_score'] as int,
        notes: json['notes'] as String?,
        submittedAt: DateTime.parse(json['submitted_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// `POST /assessments` response (mirrors AssessmentSubmitResponse): the
/// saved assessment plus its automatic stress-risk prediction, if generated.
class AssessmentSubmitResponse {
  const AssessmentSubmitResponse({
    required this.assessment,
    required this.prediction,
    required this.predictionSkippedReason,
  });

  final WellnessAssessment assessment;
  final Prediction? prediction;
  final String? predictionSkippedReason;

  factory AssessmentSubmitResponse.fromJson(Map<String, dynamic> json) =>
      AssessmentSubmitResponse(
        assessment: WellnessAssessment.fromJson(json),
        prediction: json['prediction'] == null
            ? null
            : Prediction.fromJson(json['prediction'] as Map<String, dynamic>),
        predictionSkippedReason: json['prediction_skipped_reason'] as String?,
      );
}

/// Request body for `POST /duty-records` (mirrors DutyRecordCreate).
///
/// Duration safety: when start and end times are both set, the backend derives
/// `duty_hours` server-side and ignores any client value — so the app only
/// sends `dutyHours` when no clock times are provided. The backend remains the
/// source of truth.
class DutyRecordCreate {
  const DutyRecordCreate({
    required this.recordDate,
    required this.dutyType,
    this.startTime,
    this.endTime,
    this.dutyHours,
    this.deploymentId,
  });

  final DateTime recordDate;
  final DutyType dutyType;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? dutyHours;
  final String? deploymentId;

  Map<String, dynamic> toJson() {
    final hasClockTimes = startTime != null && endTime != null;
    return {
      'record_date': formatDateOnly(recordDate),
      'duty_type': dutyType.wire,
      if (startTime != null) 'start_time': startTime!.toUtc().toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toUtc().toIso8601String(),
      // The backend derives duty_hours from clock times and never trusts a
      // client-supplied duration, so omit it whenever clock times are set.
      if (!hasClockTimes && dutyHours != null) 'duty_hours': dutyHours,
      if (deploymentId != null && deploymentId!.trim().isNotEmpty)
        'deployment_id': deploymentId!.trim(),
    };
  }
}

/// `GET /duty-records` item (mirrors DutyRecordRead).
class DutyRecord {
  const DutyRecord({
    required this.id,
    required this.personnelKey,
    required this.recordDate,
    required this.dutyType,
    required this.dutyHours,
    required this.createdAt,
    required this.updatedAt,
    this.startTime,
    this.endTime,
    this.deploymentId,
  });

  final String id;
  final String personnelKey;
  final DateTime recordDate;
  final DutyType dutyType;
  final double dutyHours;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? deploymentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DutyRecord.fromJson(Map<String, dynamic> json) => DutyRecord(
        id: json['id'] as String,
        personnelKey: json['personnel_key'] as String,
        recordDate: DateTime.parse(json['record_date'] as String),
        dutyType: DutyType.fromWire(json['duty_type'] as String),
        dutyHours: (json['duty_hours'] as num).toDouble(),
        startTime: json['start_time'] == null
            ? null
            : DateTime.parse(json['start_time'] as String),
        endTime: json['end_time'] == null
            ? null
            : DateTime.parse(json['end_time'] as String),
        deploymentId: json['deployment_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

/// Stress-risk prediction (mirrors PredictionRead). Only the fields the
/// backend deliberately exposes to the owning personnel are surfaced.
class Prediction {
  const Prediction({
    required this.id,
    required this.personnelKey,
    required this.riskLevel,
    required this.probabilityLow,
    required this.probabilityMedium,
    required this.probabilityHigh,
    required this.contributingFactors,
    required this.modelVersion,
    required this.reviewStatus,
    required this.createdAt,
    this.assessmentId,
  });

  final String id;
  final String personnelKey;
  final String? assessmentId;
  final RiskLevel riskLevel;
  final double probabilityLow;
  final double probabilityMedium;
  final double probabilityHigh;
  final List<String> contributingFactors;
  final String modelVersion;
  final ReviewStatus reviewStatus;
  final DateTime createdAt;

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
        id: json['id'] as String,
        personnelKey: json['personnel_key'] as String,
        assessmentId: json['assessment_id'] as String?,
        riskLevel: RiskLevel.fromWire(json['risk_level'] as String),
        probabilityLow: (json['probability_low'] as num).toDouble(),
        probabilityMedium: (json['probability_medium'] as num).toDouble(),
        probabilityHigh: (json['probability_high'] as num).toDouble(),
        contributingFactors: (json['contributing_factors'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        modelVersion: json['model_version'] as String? ?? '',
        reviewStatus: ReviewStatus.fromWire(json['review_status'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Format a DateTime as the backend date-only field `YYYY-MM-DD`.
String formatDateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Human-friendly date rendering used across screens.
String formatDateTime(DateTime date) {
  final local = date.toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$m-$d $h:$min';
}