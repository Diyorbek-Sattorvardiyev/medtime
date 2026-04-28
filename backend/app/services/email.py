from __future__ import annotations

from datetime import datetime

from flask import current_app, render_template
from flask_mail import Message

from app.extensions import db, mail
from app.models import NotificationLog


def send_mail_safe(to_email: str, subject: str, html: str, user_id: int | None = None, medicine_id: int | None = None, schedule_id: int | None = None):
    if not current_app.config.get("MAIL_SERVER") or not current_app.config.get("MAIL_DEFAULT_SENDER"):
        error_text = "SMTP sozlanmagan"
        if user_id:
            log_notification(user_id, medicine_id, schedule_id, "email", subject, html, "failed", error_text)
        return False, error_text
    try:
        message = Message(subject=subject, recipients=[to_email], html=html)
        mail.send(message)
        if user_id:
            log_notification(user_id, medicine_id, schedule_id, "email", subject, html, "sent", None)
        return True, None
    except Exception as exc:
        if user_id:
            log_notification(user_id, medicine_id, schedule_id, "email", subject, html, "failed", str(exc))
        current_app.logger.warning("Email yuborilmadi: %s", exc)
        return False, str(exc)


def log_notification(user_id: int, medicine_id: int | None, schedule_id: int | None, channel: str, title: str, message: str, status: str, error_message: str | None = None):
    db.session.add(
        NotificationLog(
            user_id=user_id,
            medicine_id=medicine_id,
            schedule_id=schedule_id,
            channel=channel,
            title=title,
            message=message,
            status=status,
            error_message=error_message,
            sent_at=datetime.utcnow() if status == "sent" else None,
        )
    )
    db.session.commit()


def send_verification_email(user, code: str, purpose: str):
    title = "MedReminder tasdiqlash kodi" if purpose == "register" else "MedReminder parol tiklash kodi"
    html = render_template("email/verification.html", user=user, code=code, purpose=purpose)
    return send_mail_safe(user.email, title, html)


def send_reminder_email(user, medicine, schedule, planned_at):
    title = f"Dori eslatmasi: {medicine.name}"
    html = render_template("email/reminder.html", user=user, medicine=medicine, schedule=schedule, planned_at=planned_at)
    return send_mail_safe(user.email, title, html, user.id, medicine.id, schedule.id)
