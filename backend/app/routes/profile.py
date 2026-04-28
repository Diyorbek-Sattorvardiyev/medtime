from __future__ import annotations

from flask_jwt_extended import jwt_required
from flask_smorest import Blueprint

from app.extensions import db
from app.models import User
from app.schemas.common import MessageSchema
from app.schemas.profile import EmailUpdateSchema, NotificationSettingsSchema, ProfileUpdateSchema
from app.services.auth import create_email_code
from app.utils.auth import current_user
from app.utils.responses import error, success
from app.utils.serializers import user_dict

blp = Blueprint("profile", __name__, description="Profil")


@blp.route("", methods=["GET"])
@jwt_required()
@blp.response(200, MessageSchema)
def get_profile():
    return success(user_dict(current_user()), "Profil ma'lumotlari")


@blp.route("", methods=["PUT"])
@jwt_required()
@blp.arguments(ProfileUpdateSchema)
@blp.response(200, MessageSchema)
def update_profile(data):
    user = current_user()
    for key in ["full_name", "avatar_url", "language", "dark_mode"]:
        if key in data:
            setattr(user, key, data[key])
    db.session.commit()
    return success(user_dict(user), "Profil yangilandi")


@blp.route("/notification-settings", methods=["PUT"])
@jwt_required()
@blp.arguments(NotificationSettingsSchema)
@blp.response(200, MessageSchema)
def update_notification_settings(data):
    user = current_user()
    for key in ["app_notifications_enabled", "email_notifications_enabled", "telegram_notifications_enabled"]:
        if key in data:
            setattr(user, key, data[key])
    db.session.commit()
    return success(user_dict(user), "Bildirishnoma sozlamalari yangilandi")


@blp.route("/email", methods=["PUT"])
@jwt_required()
@blp.arguments(EmailUpdateSchema)
@blp.response(200, MessageSchema)
def update_email(data):
    user = current_user()
    new_email = data["email"].lower()
    exists = User.query.filter(User.email == new_email, User.id != user.id).first()
    if exists:
        return error("Bu email band", status_code=409)
    user.email = new_email
    user.is_email_verified = False
    user.email_verified_at = None
    db.session.commit()
    code = create_email_code(user, "register")
    payload = user_dict(user)
    from flask import current_app
    if current_app.config["RETURN_VERIFICATION_CODE"]:
        payload["verification_code"] = code
    return success(payload, "Yangi emailga tasdiqlash kodi yuborildi")
