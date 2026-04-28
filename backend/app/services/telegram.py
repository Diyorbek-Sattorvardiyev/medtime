from __future__ import annotations

from datetime import datetime

import requests
from flask import current_app

from app.extensions import db
from app.models import NotificationLog


def send_telegram_message(user, text: str, medicine_id: int | None = None, schedule_id: int | None = None):
    token = current_app.config.get("TELEGRAM_BOT_TOKEN")
    if not token or not user.telegram_chat_id:
        return log(user.id, medicine_id, schedule_id, text, "failed", "Telegram bot token yoki chat_id yo'q")
    try:
        response = requests.post(
            f"https://api.telegram.org/bot{token}/sendMessage",
            json={"chat_id": user.telegram_chat_id, "text": text},
            timeout=15,
        )
        response.raise_for_status()
        return log(user.id, medicine_id, schedule_id, text, "sent", None)
    except Exception as exc:
        return log(user.id, medicine_id, schedule_id, text, "failed", str(exc))


def log(user_id: int, medicine_id: int | None, schedule_id: int | None, message: str, status: str, error_message: str | None):
    db.session.add(
        NotificationLog(
            user_id=user_id,
            medicine_id=medicine_id,
            schedule_id=schedule_id,
            channel="telegram",
            title="Dori eslatmasi",
            message=message,
            status=status,
            error_message=error_message,
            sent_at=datetime.utcnow() if status == "sent" else None,
        )
    )
    db.session.commit()
    return status == "sent", error_message
