import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sih_stress_wellness/core/models.dart';

Map<String, dynamic> _json(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  group('Token', () {
    test('parses the OAuth2 response body', () {
      final token = Token.fromJson(
        _json('{"access_token":"abc","token_type":"bearer"}'),
      );
      expect(token.accessToken, 'abc');
      expect(token.tokenType, 'bearer');
    });
  });

  group('CurrentUser', () {
    test('parses role, active flag and opaque personnel key', () {
      final user = CurrentUser.fromJson(_json(
        '{"id":"u1","username":"demo_personnel","role":"personnel",'
        '"is_active":true,"personnel_opaque_key":'
        '"11111111-1111-1111-1111-111111111111"}',
      ));
      expect(user.username, 'demo_personnel');
      expect(user.role, Role.personnel);
      expect(user.isActive, isTrue);
      expect(user.personnelOpaqueKey, '11111111-1111-1111-1111-111111111111');
    });

    test('parses an officer account without a personnel key', () {
      final user = CurrentUser.fromJson(_json(
        '{"id":"u2","username":"officer","role":"welfare_officer",'
        '"is_active":true,"personnel_opaque_key":null}',
      ));
      expect(user.role, Role.welfareOfficer);
      expect(user.personnelOpaqueKey, isNull);
    });
  });

  group('AssessmentCreate', () {
    test('serializes to the backend field names', () {
      final create = AssessmentCreate(
        stressLevelSelfReport: 7,
        restHours7d: 6.5,
        sleepHours7d: 5.0,
        workloadScore: 8,
        notes: 'feeling stretched',
      );
      final json = create.toJson();
      expect(json, {
        'stress_level_self_report': 7,
        'rest_hours_7d': 6.5,
        'sleep_hours_7d': 5.0,
        'workload_score': 8,
        'notes': 'feeling stretched',
      });
    });

    test('omits null notes', () {
      final create = AssessmentCreate(
        stressLevelSelfReport: 2,
        restHours7d: 9,
        sleepHours7d: 8,
        workloadScore: 3,
        notes: null,
      );
      expect(create.toJson().containsKey('notes'), isFalse);
    });
  });

  group('WellnessAssessment', () {
    test('parses a read model', () {
      final a = WellnessAssessment.fromJson(_json(
        '{"id":"a1","personnel_key":"k1","stress_level_self_report":8,'
        '"rest_hours_7d":6.5,"sleep_hours_7d":5.0,"workload_score":8,'
        '"notes":"tired","submitted_at":"2026-09-20T10:00:00Z",'
        '"created_at":"2026-09-20T10:00:00Z"}',
      ));
      expect(a.id, 'a1');
      expect(a.stressLevelSelfReport, 8);
      expect(a.restHours7d, 6.5);
      expect(a.submittedAt.isUtc, isTrue);
    });
  });

  group('Prediction', () {
    test('parses risk level, probabilities and factors', () {
      final p = Prediction.fromJson(_json(
        '{"id":"p1","personnel_key":"k1","assessment_id":"a1",'
        '"risk_level":"high","probability_low":0.1,"probability_medium":0.2,'
        '"probability_high":0.7,"contributing_factors":'
        '["elevated weekly duty hours","reduced sleep"],"model_version":"v1",'
        '"review_status":"pending","created_at":"2026-09-20T10:00:00Z"}',
      ));
      expect(p.riskLevel, RiskLevel.high);
      expect(p.probabilityHigh, 0.7);
      expect(p.contributingFactors.length, 2);
      expect(p.modelVersion, 'v1');
      expect(p.reviewStatus, ReviewStatus.pending);
    });

    test('parses a prediction without contributing factors', () {
      final p = Prediction.fromJson(_json(
        '{"id":"p2","personnel_key":"k1","assessment_id":null,'
        '"risk_level":"low","probability_low":0.8,"probability_medium":0.15,'
        '"probability_high":0.05,"contributing_factors":[],"model_version":"v1",'
        '"review_status":"pending","created_at":"2026-09-20T10:00:00Z"}',
      ));
      expect(p.assessmentId, isNull);
      expect(p.contributingFactors, isEmpty);
      expect(p.riskLevel, RiskLevel.low);
    });
  });

  group('AssessmentSubmitResponse', () {
    test('carries prediction norms', () {
      final response = AssessmentSubmitResponse.fromJson(_json(
        '{"id":"a1","personnel_key":"k1","stress_level_self_report":6,'
        '"rest_hours_7d":6.0,"sleep_hours_7d":5.5,"workload_score":6,'
        '"notes":null,"submitted_at":"2026-09-20T10:00:00Z",'
        '"created_at":"2026-09-20T10:00:00Z",'
        '"prediction":{"id":"p1","personnel_key":"k1","assessment_id":"a1",'
        '"risk_level":"medium","probability_low":0.2,"probability_medium":0.6,'
        '"probability_high":0.2,"contributing_factors":["steady work load"],'
        '"model_version":"v1","review_status":"pending",'
        '"created_at":"2026-09-20T10:00:00Z"},'
        '"prediction_skipped_reason":null}',
      ));
      expect(response.assessment.id, 'a1');
      expect(response.prediction, isNotNull);
      expect(response.prediction!.riskLevel, RiskLevel.medium);
      expect(response.predictionSkippedReason, isNull);
    });

    test('surfaces a skipped prediction reason', () {
      final response = AssessmentSubmitResponse.fromJson(_json(
        '{"id":"a2","personnel_key":"k1","stress_level_self_report":3,'
        '"rest_hours_7d":8.0,"sleep_hours_7d":7.0,"workload_score":3,'
        '"notes":null,"submitted_at":"2026-09-21T10:00:00Z",'
        '"created_at":"2026-09-21T10:00:00Z",'
        '"prediction":null,'
        '"prediction_skipped_reason":"Not enough duty data"}',
      ));
      expect(response.prediction, isNull);
      expect(response.predictionSkippedReason, 'Not enough duty data');
    });
  });

  group('DutyRecordCreate', () {
    test('serializes self-reported hours', () {
      final create = DutyRecordCreate(
        recordDate: DateTime(2026, 9, 19),
        dutyType: DutyType.leave,
        dutyHours: 8,
      );
      final json = create.toJson();
      expect(json['record_date'], '2026-09-19');
      expect(json['duty_type'], 'leave');
      expect(json['duty_hours'], 8.0);
      expect(json.containsKey('start_time'), isFalse);
      expect(json.containsKey('end_time'), isFalse);
    });

    test('serializes clock times but never both hours and times preference '
        'when the caller supplies times', () {
      final create = DutyRecordCreate(
        recordDate: DateTime(2026, 9, 19),
        dutyType: DutyType.duty,
        startTime: DateTime.utc(2026, 9, 19, 8),
        endTime: DateTime.utc(2026, 9, 19, 16),
        dutyHours: 999,
      );
      final json = create.toJson();
      expect(json['start_time'], '2026-09-19T08:00:00.000Z');
      expect(json['end_time'], '2026-09-19T16:00:00.000Z');
      expect(json.containsKey('duty_hours'), isFalse);
    });
  });

  group('DutyRecord', () {
    test('parses a read model with derived duration', () {
      final r = DutyRecord.fromJson(_json(
        '{"id":"r1","personnel_key":"k1","record_date":"2026-09-19",'
        '"duty_type":"duty","duty_hours":8.0,'
        '"start_time":"2026-09-19T08:00:00Z","end_time":"2026-09-19T16:00:00Z",'
        '"deployment_id":null,"created_at":"2026-09-19T16:00:00Z",'
        '"updated_at":"2026-09-19T16:00:00Z"}',
      ));
      expect(r.dutyType, DutyType.duty);
      expect(r.dutyHours, 8.0);
      expect(r.startTime, isNotNull);
      expect(r.deploymentId, isNull);
    });
  });

  group('Enums', () {
    test('wire values match the backend', () {
      expect(RiskLevel.fromWire('low'), RiskLevel.low);
      expect(RiskLevel.fromWire('high').label, 'HIGH');
      expect(DutyType.fromWire('deployment'), DutyType.deployment);
      expect(Role.fromWire('welfare_officer'), Role.welfareOfficer);
      expect(ReviewStatus.fromWire('reviewed'), ReviewStatus.reviewed);
    });
  });

  group('formatDateOnly', () {
    test('pads year, month and day', () {
      expect(formatDateOnly(DateTime(2026, 3, 5)), '2026-03-05');
      expect(formatDateOnly(DateTime(2026, 11, 30)), '2026-11-30');
    });
  });
}