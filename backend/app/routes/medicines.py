from __future__ import annotations

from datetime import date, datetime, timedelta

from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint
from sqlalchemy.orm import joinedload, selectinload

from app.extensions import db
from app.models import FamilyMember, Medicine, MedicineLog, MedicineSchedule
from app.schemas.common import MessageSchema
from app.schemas.medicine import MedicineActionSchema, MedicineBulkActionSchema, MedicineQuerySchema, MedicineSchema
from app.utils.plans import DAYS, ensure_log, log_for, planned_datetime
from app.utils.responses import error, success
from app.utils.serializers import log_dict, medicine_dict

blp = Blueprint("medicines", __name__, description="Dorilar")


def owned_medicine_or_404(medicine_id: int, user_id: int):
    return (
        Medicine.query.options(
            joinedload(Medicine.family_member),
            selectinload(Medicine.schedules),
        )
        .filter_by(id=medicine_id, user_id=user_id)
        .first_or_404()
    )


def validate_member(user_id: int, member_id: int | None):
    if member_id is None:
        return True
    return FamilyMember.query.filter_by(id=member_id, user_id=user_id).first() is not None


def replace_schedules(medicine: Medicine, schedules: list[dict]):
    medicine.schedules.clear()
    db.session.flush()
    for item in schedules:
        medicine.schedules.append(
            MedicineSchedule(
                time=item["time"],
                repeat_days=item["repeat_days"],
                reminder_before_minutes=item.get("reminder_before_minutes", 0),
            )
        )


def medicine_with_today_status(medicine: Medicine, today: date):
    data = medicine_dict(medicine)
    weekday = DAYS[today.weekday()]
    now = datetime.utcnow()
    for schedule_data, schedule in zip(data.get("schedules", []), medicine.schedules):
        if weekday not in (schedule.repeat_days or []):
            continue
        planned_at = planned_datetime(today, schedule)
        log = log_for(medicine.user_id, schedule.id, planned_at)
        schedule_data["planned_at"] = planned_at.isoformat()
        schedule_data["status"] = log.status if log else ("missed" if planned_at < now else "pending")
    return data


@blp.route("", methods=["POST"])
@jwt_required()
@blp.arguments(MedicineSchema)
@blp.response(201, MessageSchema)
def create_medicine(data):
    user_id = int(get_jwt_identity())
    if not validate_member(user_id, data.get("family_member_id")):
        return error("Oila a'zosi topilmadi", status_code=404)
    schedules = data.pop("schedules")
    medicine = Medicine(user_id=user_id, **data)
    db.session.add(medicine)
    db.session.flush()
    replace_schedules(medicine, schedules)
    db.session.commit()
    return success(medicine_dict(medicine), "Dori qo'shildi", 201)


@blp.route("", methods=["GET"])
@jwt_required()
@blp.arguments(MedicineQuerySchema, location="query")
@blp.response(200, MessageSchema)
def list_medicines(query):
    user_id = int(get_jwt_identity())
    q = Medicine.query.options(
        joinedload(Medicine.family_member),
        selectinload(Medicine.schedules),
    ).filter_by(user_id=user_id)
    if "active" in query:
        q = q.filter(Medicine.active.is_(query["active"]))
    if query.get("family_member_id") is not None:
        q = q.filter(Medicine.family_member_id == query["family_member_id"])
    if query.get("search"):
        q = q.filter(Medicine.name.ilike(f"%{query['search']}%"))
    items = q.order_by(Medicine.created_at.desc()).all()
    today = date.today()
    return success({"medicines": [medicine_with_today_status(item, today) for item in items]}, "Dorilar ro'yxati")


@blp.route("/actions/bulk", methods=["POST"])
@jwt_required()
@blp.arguments(MedicineBulkActionSchema)
@blp.response(200, MessageSchema)
def bulk_actions(data):
    user_id = int(get_jwt_identity())
    processed = 0
    results = []
    for item in data["actions"]:
        action = item["action"]
        status = {"taken": "taken", "missed": "missed", "snooze": "snoozed"}[action]
        if action == "snooze" and "minutes" not in item:
            results.append({"ok": False, "message": "Snooze uchun minutes majburiy"})
            break
        log, err = action_log(user_id, item["medicine_id"], item, status)
        if err:
            results.append({"ok": False, "message": "Amal bajarilmadi"})
            break
        results.append({"ok": True, "log": log_dict(log)})
        processed += 1
    return success({"processed": processed, "results": results}, "Offline amallar sync qilindi")


@blp.route("/<int:medicine_id>", methods=["GET"])
@jwt_required()
@blp.response(200, MessageSchema)
def get_medicine(medicine_id):
    user_id = int(get_jwt_identity())
    item = owned_medicine_or_404(medicine_id, user_id)
    logs = (
        MedicineLog.query.options(joinedload(MedicineLog.medicine))
        .filter_by(user_id=user_id, medicine_id=item.id)
        .order_by(MedicineLog.planned_at.desc())
        .limit(10)
        .all()
    )
    return success(medicine_dict(item, logs=logs), "Dori ma'lumotlari")


@blp.route("/<int:medicine_id>", methods=["PUT"])
@jwt_required()
@blp.arguments(MedicineSchema)
@blp.response(200, MessageSchema)
def update_medicine(data, medicine_id):
    user_id = int(get_jwt_identity())
    item = owned_medicine_or_404(medicine_id, user_id)
    if not validate_member(user_id, data.get("family_member_id")):
        return error("Oila a'zosi topilmadi", status_code=404)
    schedules = data.pop("schedules")
    for key, value in data.items():
        setattr(item, key, value)
    replace_schedules(item, schedules)
    db.session.commit()
    return success(medicine_dict(item), "Dori yangilandi")


@blp.route("/<int:medicine_id>", methods=["DELETE"])
@jwt_required()
@blp.response(200, MessageSchema)
def delete_medicine(medicine_id):
    user_id = int(get_jwt_identity())
    item = owned_medicine_or_404(medicine_id, user_id)
    item.active = False
    db.session.commit()
    return success({}, "Dori faolsizlantirildi")


def action_log(user_id: int, medicine_id: int, data: dict, status: str):
    medicine = owned_medicine_or_404(medicine_id, user_id)
    schedule = MedicineSchedule.query.filter_by(id=data["schedule_id"], medicine_id=medicine.id).first()
    if not schedule:
        return None, error("Schedule topilmadi", status_code=404)
    log = ensure_log(user_id, medicine.id, schedule.id, data["planned_at"])
    log.status = status
    if status == "taken":
        log.taken_at = datetime.utcnow()
        log.snoozed_until = None
        if medicine.stock_quantity is not None and medicine.stock_quantity > 0:
            medicine.stock_quantity -= 1
    elif status == "missed":
        log.taken_at = None
        log.snoozed_until = None
    elif status == "snoozed":
        log.snoozed_until = datetime.utcnow() + timedelta(minutes=data["minutes"])
    db.session.commit()
    return log, None


@blp.route("/<int:medicine_id>/mark-taken", methods=["POST"])
@jwt_required()
@blp.arguments(MedicineActionSchema)
@blp.response(200, MessageSchema)
def mark_taken(data, medicine_id):
    log, err = action_log(int(get_jwt_identity()), medicine_id, data, "taken")
    if err:
        return err
    return success(log_dict(log), "Dori qabul qilindi")


@blp.route("/<int:medicine_id>/mark-missed", methods=["POST"])
@jwt_required()
@blp.arguments(MedicineActionSchema)
@blp.response(200, MessageSchema)
def mark_missed(data, medicine_id):
    log, err = action_log(int(get_jwt_identity()), medicine_id, data, "missed")
    if err:
        return err
    return success(log_dict(log), "Dori o'tkazib yuborildi")


@blp.route("/<int:medicine_id>/snooze", methods=["POST"])
@jwt_required()
@blp.arguments(MedicineActionSchema)
@blp.response(200, MessageSchema)
def snooze(data, medicine_id):
    if "minutes" not in data:
        return error("Snooze uchun minutes majburiy", status_code=422)
    log, err = action_log(int(get_jwt_identity()), medicine_id, data, "snoozed")
    if err:
        return err
    return success(log_dict(log), "Eslatma kechiktirildi")
