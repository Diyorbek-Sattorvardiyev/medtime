from __future__ import annotations

from datetime import datetime, timedelta

from flask import current_app
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.extensions import db
from app.models import TelegramConnectCode, User
from app.schemas.common import MessageSchema
from app.schemas.telegram import TelegramWebhookSchema
from app.utils.responses import error, success
from app.utils.security import random_token_urlsafe

blp = Blueprint("telegram", __name__, description="Telegram")


@blp.route("/connect-link", methods=["GET"])
@jwt_required()
@blp.response(200, MessageSchema)
def connect_link():
    user_id = int(get_jwt_identity())
    TelegramConnectCode.query.filter_by(user_id=user_id, is_used=False).update({"is_used": True})
    code = random_token_urlsafe(18)
    db.session.add(TelegramConnectCode(user_id=user_id, code=code, expires_at=datetime.utcnow() + timedelta(minutes=15)))
    db.session.commit()
    username = current_app.config["TELEGRAM_BOT_USERNAME"]
    return success({"code": code, "telegram_url": f"https://t.me/{username}?start={code}"}, "Telegram ulanish havolasi")


@blp.route("/webhook", methods=["POST"])
@blp.arguments(TelegramWebhookSchema)
@blp.response(200, MessageSchema)
def webhook(data):
    message = data.get("message") or {}
    text = (message.get("text") or "").strip()
    chat = message.get("chat") or {}
    chat_id = chat.get("id")
    if not text.startswith("/start ") or not chat_id:
        return success({}, "E'tiborga olinmadi")
    code_value = text.split(maxsplit=1)[1]
    code = (
        TelegramConnectCode.query.filter_by(code=code_value, is_used=False)
        .filter(TelegramConnectCode.expires_at > datetime.utcnow())
        .first()
    )
    if not code:
        return error("Telegram ulanish kodi yaroqsiz", status_code=400)
    user = User.query.get(code.user_id)
    user.telegram_chat_id = str(chat_id)
    user.telegram_notifications_enabled = True
    code.is_used = True
    db.session.commit()
    return success({}, "Telegram ulandi")


@blp.route("/disconnect", methods=["DELETE"])
@jwt_required()
@blp.response(200, MessageSchema)
def disconnect():
    user = User.query.get_or_404(int(get_jwt_identity()))
    user.telegram_chat_id = None
    user.telegram_notifications_enabled = False
    db.session.commit()
    return success({}, "Telegram uzildi")
