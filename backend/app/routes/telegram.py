from __future__ import annotations

from datetime import datetime, timedelta

import requests
from flask import current_app, request
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
    return success(
        {"code": code, "connect_code": code, "telegram_url": f"https://t.me/{username}?start={code}"},
        "Telegram ulanish havolasi",
    )


@blp.route("/connect-status", methods=["GET"])
@jwt_required()
@blp.response(200, MessageSchema)
def connect_status():
    user = User.query.get_or_404(int(get_jwt_identity()))
    code_value = (request.args.get("code") or "").strip()
    if user.telegram_chat_id:
        return success({"connected": True}, "Telegram ulangan")
    if code_value:
        _sync_bot_updates(code_value)
        db.session.refresh(user)
    return success({"connected": bool(user.telegram_chat_id)}, "Telegram ulanish holati")


@blp.route("/webhook", methods=["POST"])
@blp.arguments(TelegramWebhookSchema)
@blp.response(200, MessageSchema)
def webhook(data):
    message = data.get("message") or {}
    connected = _connect_from_message(message)
    if not connected:
        return success({}, "E'tiborga olinmadi")
    return success({}, "Telegram ulandi")


def _connect_from_message(message):
    text = (message.get("text") or "").strip()
    chat = message.get("chat") or {}
    chat_id = chat.get("id")
    if not text.startswith("/start ") or not chat_id:
        return False
    code_value = text.split(maxsplit=1)[1].strip()
    code = (
        TelegramConnectCode.query.filter_by(code=code_value, is_used=False)
        .filter(TelegramConnectCode.expires_at > datetime.utcnow())
        .first()
    )
    if not code:
        return False
    user = User.query.get(code.user_id)
    if not user:
        return False
    user.telegram_chat_id = str(chat_id)
    user.telegram_notifications_enabled = True
    code.is_used = True
    db.session.commit()
    return True


def _sync_bot_updates(code_value):
    token = current_app.config.get("TELEGRAM_BOT_TOKEN")
    if not token:
        return
    try:
        response = requests.get(
            f"https://api.telegram.org/bot{token}/getUpdates",
            params={"timeout": 0, "allowed_updates": '["message"]'},
            timeout=10,
        )
        response.raise_for_status()
        updates = response.json().get("result") or []
    except Exception:
        return
    for update in updates:
        message = update.get("message") or {}
        text = (message.get("text") or "").strip()
        if text == f"/start {code_value}" and _connect_from_message(message):
            return


@blp.route("/disconnect", methods=["DELETE"])
@jwt_required()
@blp.response(200, MessageSchema)
def disconnect():
    user = User.query.get_or_404(int(get_jwt_identity()))
    user.telegram_chat_id = None
    user.telegram_notifications_enabled = False
    db.session.commit()
    return success({}, "Telegram uzildi")
