from __future__ import annotations

from marshmallow import Schema, fields


class TelegramWebhookSchema(Schema):
    update_id = fields.Int()
    message = fields.Dict()
