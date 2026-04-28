from __future__ import annotations

from datetime import date, datetime, time, timedelta

from sqlalchemy.orm import joinedload

from app.extensions import db
from app.models import Medicine, MedicineLog, MedicineSchedule
from app.utils.timezone import tashkent_now

DAYS = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]


def planned_datetime(day: date, schedule: MedicineSchedule) -> datetime:
    return datetime.combine(day, schedule.time)


def schedules_for_day(user_id: int, day: date, family_member_id: int | None = None):
    weekday = DAYS[day.weekday()]
    query = (
        MedicineSchedule.query.join(Medicine)
        .options(
            joinedload(MedicineSchedule.medicine).joinedload(Medicine.family_member)
        )
        .filter(
            Medicine.user_id == user_id,
            Medicine.active.is_(True),
            Medicine.start_date <= day,
            db.or_(Medicine.end_date.is_(None), Medicine.end_date >= day),
        )
        .order_by(MedicineSchedule.time.asc())
    )
    if family_member_id is not None:
        query = query.filter(Medicine.family_member_id == family_member_id)
    return [item for item in query.all() if weekday in (item.repeat_days or [])]


def log_for(user_id: int, schedule_id: int, planned_at: datetime) -> MedicineLog | None:
    return MedicineLog.query.filter_by(user_id=user_id, schedule_id=schedule_id, planned_at=planned_at).first()


def ensure_log(user_id: int, medicine_id: int, schedule_id: int, planned_at: datetime) -> MedicineLog:
    item = log_for(user_id, schedule_id, planned_at)
    if item:
        return item
    item = MedicineLog(user_id=user_id, medicine_id=medicine_id, schedule_id=schedule_id, planned_at=planned_at)
    db.session.add(item)
    db.session.flush()
    return item


def day_items(user_id: int, day: date, family_member_id: int | None = None, create_pending=False):
    items = []
    now = tashkent_now()
    for schedule in schedules_for_day(user_id, day, family_member_id):
        planned_at = planned_datetime(day, schedule)
        log = log_for(user_id, schedule.id, planned_at)
        if create_pending and not log:
            log = ensure_log(user_id, schedule.medicine_id, schedule.id, planned_at)
        status = log.status if log else ("missed" if planned_at < now else "pending")
        items.append(
            {
                "medicine": schedule.medicine,
                "schedule": schedule,
                "planned_at": planned_at,
                "status": status,
                "log": log,
            }
        )
    if create_pending:
        db.session.commit()
    return items


def summary_for_day(user_id: int, day: date, family_member_id: int | None = None):
    items = day_items(user_id, day, family_member_id)
    counts = {"taken_count": 0, "missed_count": 0, "pending_count": 0}
    for item in items:
        status = "pending" if item["status"] == "snoozed" else item["status"]
        key = f"{status}_count"
        if key in counts:
            counts[key] += 1
    return counts, items


def count_logs(user_id: int, start: datetime, end: datetime, status: str | None = None):
    query = MedicineLog.query.filter(MedicineLog.user_id == user_id, MedicineLog.planned_at >= start, MedicineLog.planned_at < end)
    if status:
        query = query.filter(MedicineLog.status == status)
    return query.count()
