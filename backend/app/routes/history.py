from __future__ import annotations

from datetime import datetime, time, timedelta

from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.models import Medicine, MedicineLog
from app.schemas.common import MessageSchema
from app.schemas.medicine import HistoryQuerySchema
from app.utils.responses import success
from app.utils.serializers import log_dict

blp = Blueprint("history", __name__, description="Tarix")


@blp.route("", methods=["GET"])
@jwt_required()
@blp.arguments(HistoryQuerySchema, location="query")
@blp.response(200, MessageSchema)
def history(query):
    user_id = int(get_jwt_identity())
    q = MedicineLog.query.join(Medicine).filter(MedicineLog.user_id == user_id)
    if query.get("date"):
        start = datetime.combine(query["date"], time.min)
        q = q.filter(MedicineLog.planned_at >= start, MedicineLog.planned_at < start + timedelta(days=1))
    if query.get("medicine_id"):
        q = q.filter(MedicineLog.medicine_id == query["medicine_id"])
    if query.get("family_member_id"):
        q = q.filter(Medicine.family_member_id == query["family_member_id"])
    if query.get("status"):
        q = q.filter(MedicineLog.status == query["status"])
    items = q.order_by(MedicineLog.planned_at.desc()).limit(300).all()
    return success({"history": [log_dict(item) for item in items]}, "Dori tarixi")
