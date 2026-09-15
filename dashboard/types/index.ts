export type Role = "personnel" | "welfare_officer" | "commander" | "administrator";
export type RiskLevel = "low" | "medium" | "high";
export type ReviewStatus = "pending" | "reviewed";

export interface CurrentUser {
  id: string;
  username: string;
  role: Role;
  is_active: boolean;
  personnel_opaque_key: string | null;
}

export interface Token {
  access_token: string;
  token_type: "bearer";
}

export interface WellnessAssessment {
  id: string;
  personnel_key: string;
  stress_level_self_report: number;
  rest_hours_7d: number;
  sleep_hours_7d: number;
  workload_score: number;
  notes: string | null;
  submitted_at: string;
  created_at: string;
}

export interface Prediction {
  id: string;
  personnel_key: string;
  assessment_id: string | null;
  risk_level: RiskLevel;
  probability_low: number;
  probability_medium: number;
  probability_high: number;
  contributing_factors: string[];
  model_version: string;
  review_status: ReviewStatus;
  created_at: string;
}
