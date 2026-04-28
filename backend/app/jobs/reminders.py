from __future__ import annotations

from datetime import timedelta

from app.extensions import db, scheduler
from app.models import Medicine, MedicineSchedule, NotificationLog
from app.services.email import send_reminder_email
from app.services.telegram import send_telegram_message
from app.utils.plans import DAYS, planned_datetime
from app.utils.timezone import tashkent_now


def register_scheduler_jobs(app):
    if scheduler.get_job("medicine-reminders"):
        return
    scheduler.configure(timezone=app.config.get("SCHEDULER_TIMEZONE", "Asia/Tashkent"))
    scheduler.add_job(lambda: send_due_reminders(app), "interval", minutes=1, id="medicine-reminders", max_instances=1, replace_existing=True)


def send_due_reminders(app):
    with app.app_context():
        now = tashkent_now().replace(second=0, microsecond=0)
        today = now.date()
        weekday = DAYS[today.weekday()]
        schedules = (
            MedicineSchedule.query.join(Medicine)
            .filter(
                Medicine.active.is_(True),
                Medicine.start_date <= today,
                db.or_(Medicine.end_date.is_(None), Medicine.end_date >= today),
            )
            .all()
        )
        for schedule in schedules:
            if weekday not in (schedule.repeat_days or []):
                continue
            planned_at = planned_datetime(today, schedule)
            reminder_at = planned_at - timedelta(minutes=schedule.reminder_before_minutes)
            if abs((now - reminder_at).total_seconds()) > 59:
                continue
            medicine = schedule.medicine
            user = medicine.user
            if user.email_notifications_enabled:
                maybe_send_email(user, medicine, schedule, planned_at)
            if user.telegram_notifications_enabled and user.telegram_chat_id:
                maybe_send_telegram(user, medicine, schedule, planned_at)


def already_sent(user_id: int, schedule_id: int, channel: str, planned_at: datetime) -> bool:
    start = planned_at - timedelta(minutes=2)
    end = planned_at + timedelta(minutes=2)
    return (
        NotificationLog.query.filter_by(user_id=user_id, schedule_id=schedule_id, channel=channel, status="sent")
        .filter(NotificationLog.created_at >= start, NotificationLog.created_at <= end)
        .first()
        is not None
    )


def maybe_send_email(user, medicine, schedule, planned_at):
    if already_sent(user.id, schedule.id, "email", planned_at):
        return
    send_reminder_email(user, medicine, schedule, planned_at)


def maybe_send_telegram(user, medicine, schedule, planned_at):
    if already_sent(user.id, schedule.id, "telegram", planned_at):
        return
    text = f"MedReminder: {medicine.name} ({medicine.dosage}) qabul qilish vaqti {planned_at.strftime('%H:%M')}."
    send_telegram_message(user, text, medicine.id, schedule.id)
