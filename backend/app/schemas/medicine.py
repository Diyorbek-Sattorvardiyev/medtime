from __future__ import annotations

from marshmallow import Schema, ValidationError, fields, validate, validates_schema

from app.schemas.common import VALID_DAYS, VALID_INTAKE_TYPES, VALID_STATUSES


class ScheduleSchema(Schema):
    id = fields.Int()
    time = fields.Time(required=True, format="%H:%M")
    repeat_days = fields.List(fields.Str(validate=validate.OneOf(sorted(VALID_DAYS))), required=True, validate=validate.Length(min=1))
    reminder_before_minutes = fields.Int(load_default=0, validate=validate.Range(min=0, max=1440))


class MedicineSchema(Schema):
    family_member_id = fields.Int(allow_none=True)
    name = fields.Str(required=True, validate=validate.Length(min=1, max=160))
    dosage = fields.Str(required=True, validate=validate.Length(min=1, max=120))
    intake_type = fields.Str(required=True, validate=validate.OneOf(sorted(VALID_INTAKE_TYPES)))
    notes = fields.Str(allow_none=True)
    stock_quantity = fields.Int(allow_none=True, validate=validate.Range(min=0, max=100000))
    refill_threshold = fields.Int(allow_none=True, validate=validate.Range(min=0, max=100000))
    refill_reminder_enabled = fields.Bool(load_default=False)
    start_date = fields.Date(required=True)
    end_date = fields.Date(allow_none=True)
    schedules = fields.List(fields.Nested(ScheduleSchema), required=True, validate=validate.Length(min=1))

    @validates_schema
    def validate_dates(self, data, **kwargs):
        if data.get("end_date") and data["end_date"] < data["start_date"]:
            raise ValidationError({"end_date": ["Tugash sanasi boshlanish sanasidan oldin bo'lmasin"]})


class MedicineQuerySchema(Schema):
    active = fields.Bool()
    family_member_id = fields.Int()
    search = fields.Str()


class MedicineActionSchema(Schema):
    schedule_id = fields.Int(required=True)
    planned_at = fields.DateTime(required=True)
    minutes = fields.Int(validate=validate.Range(min=1, max=1440))


class MedicineQueuedActionSchema(MedicineActionSchema):
    medicine_id = fields.Int(required=True)
    action = fields.Str(required=True, validate=validate.OneOf(["taken", "missed", "snooze"]))


class MedicineBulkActionSchema(Schema):
    actions = fields.List(fields.Nested(MedicineQueuedActionSchema), required=True, validate=validate.Length(min=1, max=100))


class HistoryQuerySchema(Schema):
    date = fields.Date()
    medicine_id = fields.Int()
    family_member_id = fields.Int()
    status = fields.Str(validate=validate.OneOf(sorted(VALID_STATUSES)))


class CalendarMonthQuerySchema(Schema):
    month = fields.Str(required=True, validate=validate.Regexp(r"^\d{4}-\d{2}$"))


class CalendarDayQuerySchema(Schema):
    date = fields.Date(required=True)


class StatisticsQuerySchema(Schema):
    period = fields.Int(load_default=7, validate=validate.OneOf([7, 30, 90]))
