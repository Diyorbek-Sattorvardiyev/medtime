from __future__ import annotations

from marshmallow import Schema, fields, validate

from app.schemas.common import validate_password


class RegisterSchema(Schema):
    full_name = fields.Str(required=True, validate=validate.Length(min=2, max=120))
    email = fields.Email(required=True)
    password = fields.Str(required=True, validate=validate_password)
    avatar_url = fields.Str(required=True, validate=validate.Length(min=1, max=500))


class VerifyEmailSchema(Schema):
    email = fields.Email(required=True)
    code = fields.Str(required=True, validate=validate.Length(min=4, max=10))


class ResendCodeSchema(Schema):
    email = fields.Email(required=True)


class LoginSchema(Schema):
    email = fields.Email(required=True)
    password = fields.Str(required=True)


class GoogleLoginSchema(Schema):
    id_token = fields.Str(required=True)


class ForgotPasswordSchema(Schema):
    email = fields.Email(required=True)


class ResetPasswordSchema(Schema):
    email = fields.Email(required=True)
    code = fields.Str(required=True)
    new_password = fields.Str(required=True, validate=validate_password)
