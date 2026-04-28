from __future__ import annotations

from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.schemas.common import MessageSchema
from app.utils.plans import summary_for_day
from app.utils.responses import success
from app.utils.serializers import medicine_dict, schedule_dict
from app.utils.timezone import tashkent_today

blp = Blueprint("dashboard", __name__, description="Dashboard")


@blp.route("/today", methods=["GET"])
@jwt_required()
@blp.response(200, MessageSchema)
def today():
    user_id = int(get_jwt_identity())
    today_date = tashkent_today()
    counts, items = summary_for_day(user_id, today_date)
    medicines = [
        {
            **medicine_dict(item["medicine"], include_schedules=False),
            "schedule": schedule_dict(item["schedule"]),
            "planned_at": item["planned_at"].isoformat(),
            "status": item["status"],
        }
        for item in items
    ]
    upcoming = [item for item in medicines if item["status"] == "pending"][:10]
    return success({**counts, "date": today_date.isoformat(), "today_medicines": medicines, "today": medicines, "upcoming_medicines": upcoming}, "Bugungi reja")
