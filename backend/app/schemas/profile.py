from __future__ import annotations

from marshmallow import Schema, fields, validate


class ProfileUpdateSchema(Schema):
    full_name = fields.Str(validate=validate.Length(min=2, max=120))
    avatar_url = fields.Url(allow_none=True)
    language = fields.Str(validate=validate.OneOf(["uz", "en", "ru"]))
    dark_mode = fields.Bool()


class NotificationSettingsSchema(Schema):
    app_notifications_enabled = fields.Bool()
    email_notifications_enabled = fields.Bool()
    telegram_notifications_enabled = fields.Bool()


class EmailUpdateSchema(Schema):
    email = fields.Email(required=True)
