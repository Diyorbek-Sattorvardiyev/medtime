from __future__ import annotations

from collections import Counter
from datetime import datetime, time, timedelta

from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.models import Medicine, MedicineLog
from app.schemas.common import MessageSchema
from app.schemas.medicine import StatisticsQuerySchema
from app.utils.plans import summary_for_day
from app.utils.responses import success
from app.utils.timezone import tashkent_today

blp = Blueprint("statistics", __name__, description="Statistika")


@blp.route("", methods=["GET"])
@jwt_required()
@blp.arguments(StatisticsQuerySchema, location="query")
@blp.response(200, MessageSchema)
def statistics(query):
    user_id = int(get_jwt_identity())
    period = query["period"]
    today = tashkent_today()
    start_day = today - timedelta(days=period - 1)
    daily = []
    totals = Counter()
    missed_by_medicine = Counter()
    for offset in range(period):
        current = start_day + timedelta(days=offset)
        counts, _ = summary_for_day(user_id, current)
        daily.append({"date": current.isoformat(), **counts})
        totals.update({"taken": counts["taken_count"], "missed": counts["missed_count"], "pending": counts["pending_count"]})
    start_dt = datetime.combine(start_day, time.min)
    logs = MedicineLog.query.join(Medicine).filter(MedicineLog.user_id == user_id, MedicineLog.planned_at >= start_dt, MedicineLog.status == "missed").all()
    for log in logs:
        missed_by_medicine[log.medicine.name] += 1
    denominator = totals["taken"] + totals["missed"]
    adherence = round((totals["taken"] / denominator) * 100, 1) if denominator else 0
    return success(
        {
            "period": period,
            "adherence_percent": adherence,
            "taken_count": totals["taken"],
            "missed_count": totals["missed"],
            "pending_count": totals["pending"],
            "daily_breakdown": daily,
            "most_missed_medicines": [{"name": name, "missed_count": count} for name, count in missed_by_medicine.most_common(5)],
        },
        "Statistika",
    )
