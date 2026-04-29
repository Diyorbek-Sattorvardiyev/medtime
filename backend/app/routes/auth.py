from __future__ import annotations

from datetime import datetime

from flask import current_app
from flask_jwt_extended import get_jwt, get_jwt_identity, jwt_required
from flask_smorest import Blueprint
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.extensions import db, limiter
from app.models import User
from app.schemas.auth import ForgotPasswordSchema, GoogleLoginSchema, LoginSchema, RegisterSchema, ResendCodeSchema, ResetPasswordSchema, VerifyEmailSchema
from app.schemas.common import MessageSchema
from app.services.auth import create_email_code, valid_email_code
from app.utils.responses import error, success
from app.utils.security import check_password, find_active_refresh, hash_password, issue_tokens, revoke_all_user_refresh_tokens, revoke_refresh

blp = Blueprint("auth", __name__, description="Autentifikatsiya")


@blp.route("/register", methods=["POST"])
@blp.arguments(RegisterSchema)
@blp.response(201, MessageSchema)
@limiter.limit("5 per minute")
def register(data):
    if User.query.filter_by(email=data["email"].lower()).first():
        return error("Bu email allaqachon ro'yxatdan o'tgan", status_code=409)
    user = User(full_name=data["full_name"], email=data["email"].lower(), password_hash=hash_password(data["password"]), avatar_url=data["avatar_url"])
    db.session.add(user)
    db.session.commit()
    create_email_code(user, "register")
    return success({"user_id": user.id}, "Ro'yxatdan o'tdingiz. Email tasdiqlash kodi yuborildi", 201)


@blp.route("/verify-email", methods=["POST"])
@blp.arguments(VerifyEmailSchema)
@blp.response(200, MessageSchema)
def verify_email(data):
    user = User.query.filter_by(email=data["email"].lower()).first()
    if not user:
        return error("Foydalanuvchi topilmadi", status_code=404)
    code = valid_email_code(user, data["code"], "register")
    if not code:
        return error("Kod noto'g'ri yoki muddati tugagan", status_code=400)
    code.is_used = True
    user.is_email_verified = True
    user.email_verified_at = datetime.utcnow()
    db.session.commit()
    return success(issue_tokens(user), "Email tasdiqlandi")


@blp.route("/resend-code", methods=["POST"])
@blp.arguments(ResendCodeSchema)
@blp.response(200, MessageSchema)
@limiter.limit("3 per minute")
def resend_code(data):
    user = User.query.filter_by(email=data["email"].lower()).first()
    if not user:
        return error("Foydalanuvchi topilmadi", status_code=404)
    create_email_code(user, "register")
    return success({}, "Tasdiqlash kodi qayta yuborildi")


@blp.route("/login", methods=["POST"])
@blp.arguments(LoginSchema)
@blp.response(200, MessageSchema)
@limiter.limit("10 per minute")
def login(data):
    user = User.query.filter_by(email=data["email"].lower()).first()
    if not user or not check_password(data["password"], user.password_hash):
        return error("Email yoki parol noto'g'ri", status_code=401)
    if not user.is_email_verified:
        return error("Email hali tasdiqlanmagan", status_code=403)
    return success(issue_tokens(user), "Tizimga kirdingiz")


@blp.route("/google", methods=["POST"])
@blp.arguments(GoogleLoginSchema)
@blp.response(200, MessageSchema)
@limiter.limit("10 per minute")
def google_login(data):
    try:
        info = google_id_token.verify_oauth2_token(data["id_token"], google_requests.Request(), current_app.config.get("GOOGLE_CLIENT_ID"))
    except Exception as exc:
        return error("Google token noto'g'ri", {"reason": str(exc)}, 401)
    email = info.get("email", "").lower()
    if not email:
        return error("Google token email qaytarmadi", status_code=400)
    user = User.query.filter(db.or_(User.google_id == info.get("sub"), User.email == email)).first()
    if not user:
        user = User(full_name=info.get("name") or email.split("@")[0], email=email, google_id=info.get("sub"), avatar_url=info.get("picture"), is_email_verified=True, email_verified_at=datetime.utcnow())
        db.session.add(user)
    else:
        user.google_id = user.google_id or info.get("sub")
        user.avatar_url = user.avatar_url or info.get("picture")
        user.is_email_verified = True
        user.email_verified_at = user.email_verified_at or datetime.utcnow()
    db.session.commit()
    return success(issue_tokens(user), "Google orqali tizimga kirdingiz")


@blp.route("/refresh", methods=["POST"])
@jwt_required(refresh=True)
@blp.response(200, MessageSchema)
def refresh():
    jti = get_jwt()["jti"]
    item = find_active_refresh(jti)
    if not item or item.user_id != int(get_jwt_identity()):
        return error("Refresh token yaroqsiz", status_code=401)
    item.revoked = True
    db.session.commit()
    user = User.query.get(item.user_id)
    return success(issue_tokens(user), "Token yangilandi")


@blp.route("/logout", methods=["POST"])
@jwt_required(refresh=True)
@blp.response(200, MessageSchema)
def logout():
    revoke_refresh(get_jwt()["jti"])
    return success({}, "Tizimdan chiqildi")


@blp.route("/forgot-password", methods=["POST"])
@blp.arguments(ForgotPasswordSchema)
@blp.response(200, MessageSchema)
@limiter.limit("3 per minute")
def forgot_password(data):
    user = User.query.filter_by(email=data["email"].lower()).first()
    if user:
        create_email_code(user, "forgot_password")
    return success({}, "Agar email mavjud bo'lsa, parol tiklash kodi yuborildi")


@blp.route("/reset-password", methods=["POST"])
@blp.arguments(ResetPasswordSchema)
@blp.response(200, MessageSchema)
def reset_password(data):
    user = User.query.filter_by(email=data["email"].lower()).first()
    if not user:
        return error("Kod noto'g'ri yoki muddati tugagan", status_code=400)
    code = valid_email_code(user, data["code"], "forgot_password")
    if not code:
        return error("Kod noto'g'ri yoki muddati tugagan", status_code=400)
    code.is_used = True
    user.password_hash = hash_password(data["new_password"])
    user.is_email_verified = True
    user.email_verified_at = user.email_verified_at or datetime.utcnow()
    db.session.commit()
    revoke_all_user_refresh_tokens(user.id)
    return success({}, "Parol yangilandi")
