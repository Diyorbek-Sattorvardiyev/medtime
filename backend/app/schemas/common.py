from __future__ import annotations

from marshmallow import Schema, ValidationError, fields, validates

VALID_INTAKE_TYPES = {"before_food", "after_food", "no_matter"}
VALID_DAYS = {"MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"}
VALID_STATUSES = {"pending", "taken", "missed", "snoozed"}


def validate_password(value: str) -> None:
    if len(value) < 6:
        raise ValidationError("Parol kamida 6 belgidan iborat bo'lishi kerak")


class MessageSchema(Schema):
    success = fields.Bool()
    message = fields.Str()
    data = fields.Raw()
    errors = fields.Raw()


class PaginationQuerySchema(Schema):
    page = fields.Int(load_default=1)
    per_page = fields.Int(load_default=50)


class EmptySchema(Schema):
    pass
