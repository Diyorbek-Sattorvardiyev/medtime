from __future__ import annotations

from datetime import date, datetime


def iso(value):
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


def user_dict(user):
    return {
        "id": user.id,
        "full_name": user.full_name,
        "email": user.email,
        "is_email_verified": user.is_email_verified,
        "email_verified_at": iso(user.email_verified_at),
        "avatar_url": user.avatar_url,
        "language": user.language,
        "dark_mode": user.dark_mode,
        "app_notifications_enabled": user.app_notifications_enabled,
        "email_notifications_enabled": user.email_notifications_enabled,
        "telegram_notifications_enabled": user.telegram_notifications_enabled,
        "telegram_connected": bool(user.telegram_chat_id),
        "created_at": iso(user.created_at),
        "updated_at": iso(user.updated_at),
    }


def family_dict(member, summary=None):
    data = {
        "id": member.id,
        "user_id": member.user_id,
        "full_name": member.full_name,
        "relationship": member.relationship,
        "birth_date": iso(member.birth_date),
        "avatar_url": member.avatar_url,
        "avatar_color": member.avatar_color,
        "created_at": iso(member.created_at),
        "updated_at": iso(member.updated_at),
    }
    if summary is not None:
        data.update(summary)
    return data


def schedule_dict(schedule):
    return {
        "id": schedule.id,
        "medicine_id": schedule.medicine_id,
        "time": schedule.time.strftime("%H:%M"),
        "repeat_days": schedule.repeat_days or [],
        "reminder_before_minutes": schedule.reminder_before_minutes,
        "created_at": iso(schedule.created_at),
    }


def medicine_dict(medicine, include_schedules=True, logs=None):
    data = {
        "id": medicine.id,
        "user_id": medicine.user_id,
        "family_member_id": medicine.family_member_id,
        "family_member_name": medicine.family_member.full_name if medicine.family_member else None,
        "name": medicine.name,
        "dosage": medicine.dosage,
        "image_url": medicine.image_url,
        "intake_type": medicine.intake_type,
        "notes": medicine.notes,
        "stock_quantity": medicine.stock_quantity,
        "refill_threshold": medicine.refill_threshold,
        "refill_reminder_enabled": medicine.refill_reminder_enabled,
        "refill_needed": bool(
            medicine.refill_reminder_enabled
            and medicine.stock_quantity is not None
            and medicine.refill_threshold is not None
            and medicine.stock_quantity <= medicine.refill_threshold
        ),
        "start_date": iso(medicine.start_date),
        "end_date": iso(medicine.end_date),
        "active": medicine.active,
        "created_at": iso(medicine.created_at),
        "updated_at": iso(medicine.updated_at),
    }
    if include_schedules:
        data["schedules"] = [schedule_dict(item) for item in medicine.schedules]
    if logs is not None:
        data["last_logs"] = [log_dict(item) for item in logs]
    return data


def log_dict(log):
    return {
        "id": log.id,
        "user_id": log.user_id,
        "medicine_id": log.medicine_id,
        "medicine_name": log.medicine.name if log.medicine else None,
        "family_member_id": log.medicine.family_member_id if log.medicine else None,
        "schedule_id": log.schedule_id,
        "planned_at": iso(log.planned_at),
        "status": log.status,
        "taken_at": iso(log.taken_at),
        "snoozed_until": iso(log.snoozed_until),
        "created_at": iso(log.created_at),
    }


def notification_dict(item):
    return {
        "id": item.id,
        "user_id": item.user_id,
        "medicine_id": item.medicine_id,
        "schedule_id": item.schedule_id,
        "channel": item.channel,
        "title": item.title,
        "message": item.message,
        "status": item.status,
        "error_message": item.error_message,
        "sent_at": iso(item.sent_at),
        "created_at": iso(item.created_at),
    }
