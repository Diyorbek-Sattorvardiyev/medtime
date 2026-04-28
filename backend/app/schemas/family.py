from __future__ import annotations

from marshmallow import Schema, fields, validate


class FamilyMemberSchema(Schema):
    full_name = fields.Str(required=True, validate=validate.Length(min=2, max=120))
    relationship = fields.Str(required=True, validate=validate.Length(min=2, max=80))
    birth_date = fields.Date(allow_none=True)
    avatar_url = fields.Url(allow_none=True)
    avatar_color = fields.Str(allow_none=True, validate=validate.Length(max=32))


class FamilyMemberUpdateSchema(Schema):
    full_name = fields.Str(validate=validate.Length(min=2, max=120))
    relationship = fields.Str(validate=validate.Length(min=2, max=80))
    birth_date = fields.Date(allow_none=True)
    avatar_url = fields.Url(allow_none=True)
    avatar_color = fields.Str(allow_none=True, validate=validate.Length(max=32))
