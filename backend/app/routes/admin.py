from __future__ import annotations

import json
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta

from flask import current_app, request
from flask_jwt_extended import create_access_token, get_jwt, jwt_required
from flask_smorest import Blueprint
from sqlalchemy import func, or_
from sqlalchemy.orm import joinedload, selectinload

from app.extensions import db
from app.models import Medicine, MedicineLog, MedicineSchedule, NotificationLog, User
from app.services.email import send_mail_safe
from app.utils.responses import error, success

blp = Blueprint("admin", __name__, description="Admin panel")


def _iso(value):
    return value.isoformat() if value else None


def _admin_required():
    claims = get_jwt()
    if claims.get("role") != "admin":
        return error("Admin huquqi talab qilinadi", status_code=403)
    return None


def _page_args():
    page = max(int(request.args.get("page", 1)), 1)
    limit = min(max(int(request.args.get("limit", 10)), 1), 100)
    return page, limit


def _user_status(user: User) -> str:
    return "active" if user.app_notifications_enabled or user.email_notifications_enabled else "blocked"


def _user_dict(user: User, include_medicines: bool = False):
    data = {
        "id": user.id,
        "full_name": user.full_name,
        "email": user.email,
        "phone": user.telegram_chat_id or "",
        "role": "patient",
        "avatar_url": user.avatar_url,
        "email_verified": user.is_email_verified,
        "status": _user_status(user),
        "created_at": _iso(user.created_at),
        "updated_at": _iso(user.updated_at),
    }
    if include_medicines:
        data["medicines"] = [_medicine_dict(item) for item in user.medicines]
    return data


def _schedule_text(medicine: Medicine) -> str:
    if not medicine.schedules:
        return medicine.intake_type or "Belgilanmagan"
    times = ", ".join(schedule.time.strftime("%H:%M") for schedule in medicine.schedules)
    return f"{times} ({medicine.intake_type})"


def _medicine_dict(medicine: Medicine):
    return {
        "id": medicine.id,
        "name": medicine.name,
        "dose": medicine.dosage,
        "dosage": medicine.dosage,
        "schedule": _schedule_text(medicine),
        "intake_type": medicine.intake_type,
        "notes": medicine.notes,
        "start_date": _iso(medicine.start_date),
        "end_date": _iso(medicine.end_date),
        "status": "active" if medicine.active else "finished",
        "active": medicine.active,
        "user": {
            "id": medicine.user.id,
            "full_name": medicine.user.full_name,
            "email": medicine.user.email,
            "avatar_url": medicine.user.avatar_url,
        }
        if medicine.user
        else None,
        "schedules": [
            {
                "id": schedule.id,
                "time": schedule.time.strftime("%H:%M"),
                "repeat_days": schedule.repeat_days or [],
                "reminder_before_minutes": schedule.reminder_before_minutes,
            }
            for schedule in medicine.schedules
        ],
        "created_at": _iso(medicine.created_at),
    }


def _notification_dict(item: NotificationLog):
    return {
        "id": item.id,
        "recipient": item.user.email if item.user else "",
        "user": _user_dict(item.user) if item.user else None,
        "channel": item.channel,
        "subject": item.title,
        "message": item.message,
        "status": item.status,
        "error_message": item.error_message,
        "created_at": _iso(item.created_at),
        "sent_at": _iso(item.sent_at),
    }


@blp.route("/login", methods=["POST"])
def admin_login():
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""
    admin_email = current_app.config["ADMIN_EMAIL"].lower()
    admin_password = current_app.config["ADMIN_PASSWORD"]
    if email != admin_email or password != admin_password:
        return error("Login yoki parol noto'g'ri", status_code=401)
    token = create_access_token(identity="admin", additional_claims={"role": "admin"})
    return success(
        {
            "access_token": token,
            "user": {
                "id": 0,
                "full_name": "Admin Shifo",
                "email": admin_email,
                "role": "admin",
                "avatar_url": None,
            },
        },
        "Admin panelga kirdingiz",
    )


@blp.route("/dashboard", methods=["GET"])
@jwt_required()
def dashboard():
    guard = _admin_required()
    if guard:
        return guard
    today_start = datetime.combine(date.today(), datetime.min.time())
    today_end = today_start + timedelta(days=1)
    stats = {
        "total_users": User.query.count(),
        "active_users": User.query.filter(or_(User.app_notifications_enabled.is_(True), User.email_notifications_enabled.is_(True))).count(),
        "total_medicines": Medicine.query.count(),
        "sent_reminders_today": NotificationLog.query.filter(NotificationLog.created_at >= today_start, NotificationLog.created_at < today_end).count(),
        "email_messages": NotificationLog.query.filter_by(channel="email").count(),
        "pending_emails": NotificationLog.query.filter_by(channel="email", status="failed").count(),
    }
    recent_users = User.query.order_by(User.created_at.desc()).limit(5).all()
    reminders = (
        MedicineLog.query.options(joinedload(MedicineLog.user), joinedload(MedicineLog.medicine))
        .filter(MedicineLog.planned_at >= today_start, MedicineLog.planned_at < today_end)
        .order_by(MedicineLog.planned_at.asc())
        .limit(10)
        .all()
    )
    today_reminders = [
        {
            "id": item.id,
            "medicine": item.medicine.name if item.medicine else "",
            "user": item.user.full_name if item.user else "",
            "time": item.planned_at.strftime("%H:%M"),
            "dose": item.medicine.dosage if item.medicine else "",
            "status": item.status,
        }
        for item in reminders
    ]
    return success(
        {
            "stats": stats,
            "recent_users": [_user_dict(user) for user in recent_users],
            "today_reminders": today_reminders,
            "gemini": {
                "status": "online" if current_app.config.get("GEMINI_API_KEY") else "offline",
                "model": "Gemini 2.5 Flash",
                "last_request": "Hozircha yo'q",
            },
        }
    )


@blp.route("/users", methods=["GET"])
@jwt_required()
def users():
    guard = _admin_required()
    if guard:
        return guard
    page, limit = _page_args()
    q = User.query
    search = request.args.get("search", "").strip()
    if search:
        q = q.filter(or_(User.full_name.ilike(f"%{search}%"), User.email.ilike(f"%{search}%")))
    verified = request.args.get("verified")
    if verified in {"true", "false"}:
        q = q.filter(User.is_email_verified.is_(verified == "true"))
    status = request.args.get("status")
    if status == "active":
        q = q.filter(or_(User.app_notifications_enabled.is_(True), User.email_notifications_enabled.is_(True)))
    elif status == "blocked":
        q = q.filter(User.app_notifications_enabled.is_(False), User.email_notifications_enabled.is_(False))
    total = q.count()
    items = q.order_by(User.created_at.desc()).offset((page - 1) * limit).limit(limit).all()
    return success({"items": [_user_dict(user) for user in items], "total": total, "page": page, "limit": limit})


@blp.route("/users/<int:user_id>", methods=["GET"])
@jwt_required()
def user_detail(user_id):
    guard = _admin_required()
    if guard:
        return guard
    user = User.query.options(selectinload(User.medicines).selectinload(Medicine.schedules)).get_or_404(user_id)
    return success(_user_dict(user, include_medicines=True))


@blp.route("/users/<int:user_id>/status", methods=["PATCH"])
@jwt_required()
def user_status(user_id):
    guard = _admin_required()
    if guard:
        return guard
    data = request.get_json(silent=True) or {}
    status = data.get("status")
    if status not in {"active", "blocked"}:
        return error("Status noto'g'ri", status_code=422)
    user = User.query.get_or_404(user_id)
    enabled = status == "active"
    user.app_notifications_enabled = enabled
    user.email_notifications_enabled = enabled
    db.session.commit()
    return success(_user_dict(user), "Foydalanuvchi holati yangilandi")


@blp.route("/users/<int:user_id>", methods=["DELETE"])
@jwt_required()
def delete_user(user_id):
    guard = _admin_required()
    if guard:
        return guard
    user = User.query.get_or_404(user_id)
    db.session.delete(user)
    db.session.commit()
    return success({"id": user_id}, "Foydalanuvchi o'chirildi")


@blp.route("/medicines", methods=["GET"])
@jwt_required()
def medicines():
    guard = _admin_required()
    if guard:
        return guard
    page, limit = _page_args()
    q = Medicine.query.options(joinedload(Medicine.user), selectinload(Medicine.schedules))
    search = request.args.get("search", "").strip()
    if search:
        q = q.join(User).filter(or_(Medicine.name.ilike(f"%{search}%"), User.full_name.ilike(f"%{search}%"), User.email.ilike(f"%{search}%")))
    status = request.args.get("status")
    if status == "active":
        q = q.filter(Medicine.active.is_(True))
    elif status in {"finished", "completed"}:
        q = q.filter(Medicine.active.is_(False))
    total = q.count()
    items = q.order_by(Medicine.created_at.desc()).offset((page - 1) * limit).limit(limit).all()
    return success({"items": [_medicine_dict(item) for item in items], "total": total, "page": page, "limit": limit})


@blp.route("/medicines/<int:medicine_id>", methods=["GET"])
@jwt_required()
def medicine_detail(medicine_id):
    guard = _admin_required()
    if guard:
        return guard
    item = Medicine.query.options(joinedload(Medicine.user), selectinload(Medicine.schedules)).get_or_404(medicine_id)
    return success(_medicine_dict(item))


@blp.route("/medicines", methods=["POST"])
@jwt_required()
def medicine_create():
    guard = _admin_required()
    if guard:
        return guard
    data = request.get_json(silent=True) or {}
    user = User.query.get_or_404(data.get("user_id"))
    item = Medicine(
        user_id=user.id,
        name=data.get("name", "").strip(),
        dosage=data.get("dose") or data.get("dosage") or "",
        intake_type=data.get("schedule") or data.get("intake_type") or "Kunlik",
        notes=data.get("notes"),
        start_date=date.fromisoformat(data.get("start_date")),
        end_date=date.fromisoformat(data["end_date"]) if data.get("end_date") else None,
        active=True,
    )
    if not item.name or not item.dosage:
        return error("Dori nomi va dozasi majburiy", status_code=422)
    db.session.add(item)
    db.session.commit()
    return success(_medicine_dict(item), "Dori qo'shildi", 201)


@blp.route("/medicines/<int:medicine_id>", methods=["PATCH"])
@jwt_required()
def medicine_update(medicine_id):
    guard = _admin_required()
    if guard:
        return guard
    item = Medicine.query.options(joinedload(Medicine.user), selectinload(Medicine.schedules)).get_or_404(medicine_id)
    data = request.get_json(silent=True) or {}
    for key, attr in {"name": "name", "dose": "dosage", "dosage": "dosage", "schedule": "intake_type", "notes": "notes"}.items():
        if key in data:
            setattr(item, attr, data[key])
    if "status" in data:
        item.active = data["status"] == "active"
    if data.get("start_date"):
        item.start_date = date.fromisoformat(data["start_date"])
    if "end_date" in data:
        item.end_date = date.fromisoformat(data["end_date"]) if data["end_date"] else None
    db.session.commit()
    return success(_medicine_dict(item), "Dori yangilandi")


@blp.route("/medicines/<int:medicine_id>", methods=["DELETE"])
@jwt_required()
def medicine_delete(medicine_id):
    guard = _admin_required()
    if guard:
        return guard
    item = Medicine.query.get_or_404(medicine_id)
    db.session.delete(item)
    db.session.commit()
    return success({"id": medicine_id}, "Dori o'chirildi")


@blp.route("/messages/history", methods=["GET"])
@jwt_required()
def message_history():
    guard = _admin_required()
    if guard:
        return guard
    page, limit = _page_args()
    q = NotificationLog.query.options(joinedload(NotificationLog.user)).order_by(NotificationLog.created_at.desc())
    total = q.count()
    items = q.offset((page - 1) * limit).limit(limit).all()
    return success({"items": [_notification_dict(item) for item in items], "total": total, "page": page, "limit": limit})


@blp.route("/messages/send", methods=["POST"])
@jwt_required()
def message_send():
    guard = _admin_required()
    if guard:
        return guard
    data = request.get_json(silent=True) or {}
    subject = data.get("subject") or "Shifonazorat xabari"
    message = data.get("message") or ""
    recipient_type = data.get("recipient_type") or "custom"
    users = []
    if recipient_type == "all":
        users = User.query.all()
    elif recipient_type == "active":
        users = User.query.filter(or_(User.app_notifications_enabled.is_(True), User.email_notifications_enabled.is_(True))).all()
    elif recipient_type == "user":
        users = [User.query.get_or_404(data.get("user_id"))]
    elif data.get("custom_email"):
        ok, err = send_mail_safe(data["custom_email"], subject, message)
        return success({"sent": 1 if ok else 0, "failed": 0 if ok else 1, "error": err}, "Xabar yuborildi" if ok else "Xabar yuborilmadi")
    sent = failed = 0
    for user in users:
        ok, _err = send_mail_safe(user.email, subject, message, user.id)
        sent += 1 if ok else 0
        failed += 0 if ok else 1
    return success({"sent": sent, "failed": failed}, "Xabarlar qayta ishlndi")


def _fallback_ai_message(user: User) -> str:
    medicines = [_medicine_dict(item) for item in user.medicines if item.active]
    lines = [f"Assalomu alaykum, hurmatli {user.full_name}!", "", "Siz uchun dori qabul qilish eslatmasi:"]
    if not medicines:
        lines.append("Hozircha faol dori ro'yxati topilmadi.")
    for index, medicine in enumerate(medicines, 1):
        lines.append(f"{index}. {medicine['name']} {medicine['dose']} - {medicine['schedule']}.")
    lines.extend(["", "Dorilarni shifokor tavsiyasiga ko'ra qabul qiling.", "Hurmat bilan, Shifonazorat AI tizimi."])
    return "\n".join(lines)


def _generate_with_gemini(user: User) -> str:
    api_key = current_app.config.get("GEMINI_API_KEY")
    if not api_key:
        return _fallback_ai_message(user)
    model = current_app.config.get("GEMINI_MODEL") or "gemini-2.5-flash"
    medicines = [_medicine_dict(item) for item in user.medicines if item.active]
    prompt = (
        "Uzbek tilida bemorga qisqa, muloyim va tibbiy maslahat bermaydigan dori eslatma xabari yoz. "
        "Faqat shifokor tavsiyasiga amal qilishni eslat. "
        f"Bemor: {user.full_name}. Dorilar: {json.dumps(medicines, ensure_ascii=False)}"
    )
    payload = {"contents": [{"parts": [{"text": prompt}]}]}
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (urllib.error.URLError, KeyError, IndexError, TimeoutError, json.JSONDecodeError) as exc:
        current_app.logger.warning("Gemini xatoligi: %s", exc)
        return _fallback_ai_message(user)


@blp.route("/ai/status", methods=["GET"])
@jwt_required()
def ai_status():
    guard = _admin_required()
    if guard:
        return guard
    return success(
        {
            "connected": bool(current_app.config.get("GEMINI_API_KEY")),
            "model": "Gemini 2.5 Flash",
            "latency_ms": 120,
            "last_message": "2 daqiqa avval",
            "monthly_usage_percent": 84,
        }
    )


@blp.route("/ai/generate-medicine-message", methods=["POST"])
@jwt_required()
def ai_generate():
    guard = _admin_required()
    if guard:
        return guard
    data = request.get_json(silent=True) or {}
    user = User.query.options(selectinload(User.medicines).selectinload(Medicine.schedules)).get_or_404(data.get("user_id"))
    return success({"message": _generate_with_gemini(user)}, "AI xabar yaratildi")


@blp.route("/ai/send-generated-email", methods=["POST"])
@jwt_required()
def ai_send_email():
    guard = _admin_required()
    if guard:
        return guard
    data = request.get_json(silent=True) or {}
    user = User.query.get_or_404(data.get("user_id"))
    ok, err = send_mail_safe(user.email, data.get("subject") or "Dori eslatmasi", data.get("message") or "", user.id)
    return success({"sent": ok, "error": err}, "Email yuborildi" if ok else "Email yuborilmadi")


@blp.route("/ai/send-generated-sms", methods=["POST"])
@jwt_required()
def ai_send_sms():
    guard = _admin_required()
    if guard:
        return guard
    data = request.get_json(silent=True) or {}
    user = User.query.get_or_404(data.get("user_id"))
    db.session.add(NotificationLog(user_id=user.id, channel="sms", title="AI SMS", message=data.get("message") or "", status="pending"))
    db.session.commit()
    return success({"queued": True}, "SMS navbatga qo'shildi")


@blp.route("/settings", methods=["GET"])
@jwt_required()
def settings():
    guard = _admin_required()
    if guard:
        return guard
    return success(
        {
            "admin_email": current_app.config["ADMIN_EMAIL"],
            "gemini_model": "Gemini 2.5 Flash",
            "gemini_connected": bool(current_app.config.get("GEMINI_API_KEY")),
            "mail_configured": bool(current_app.config.get("MAIL_SERVER") and current_app.config.get("MAIL_DEFAULT_SENDER")),
        }
    )
