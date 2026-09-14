import enum


class Role(str, enum.Enum):
    PERSONNEL = "personnel"
    WELFARE_OFFICER = "welfare_officer"
    COMMANDER = "commander"
    ADMINISTRATOR = "administrator"


class RiskLevel(str, enum.Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class DutyType(str, enum.Enum):
    DUTY = "duty"
    DEPLOYMENT = "deployment"
    LEAVE = "leave"
    REST = "rest"
    TRAINING = "training"


class ReviewStatus(str, enum.Enum):
    PENDING = "pending"
    REVIEWED = "reviewed"