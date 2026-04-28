from __future__ import annotations

import calendar as cal
from datetime import date

from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.schemas.common import MessageSchema
from app.schemas.medicine import CalendarDayQuerySchema, CalendarMonthQuerySchema
from app.utils.plans import summary_for_day
from app.utils.responses import success
from app.utils.serializers import medicine_dict, schedule_dict

blp = Blueprint("calendar", __name__, description="Kalendar")


@blp.route("", methods=["GET"])
@jwt_required()
@blp.arguments(CalendarMonthQuerySchema, location="query")
@blp.response(200, MessageSchema)
def month(query):
    user_id = int(get_jwt_identity())
    year, month_num = map(int, query["month"].split("-"))
    days = []
    for day in range(1, cal.monthrange(year, month_num)[1] + 1):
        current = date(year, month_num, day)
        counts, _ = summary_for_day(user_id, current)
        days.append({"date": current.isoformat(), **counts})
    return success({"month": query["month"], "days": days}, "Oylik kalendar")


@blp.route("/day", methods=["GET"])
@jwt_required()
@blp.arguments(CalendarDayQuerySchema, location="query")
@blp.response(200, MessageSchema)
def day(query):
    user_id = int(get_jwt_identity())
    counts, items = summary_for_day(user_id, query["date"])
    planned = [
        {
            **medicine_dict(item["medicine"], include_schedules=False),
            "schedule": schedule_dict(item["schedule"]),
            "planned_at": item["planned_at"].isoformat(),
            "status": item["status"],
        }
        for item in items
    ]
    return success({"date": query["date"].isoformat(), **counts, "medicines": planned, "items": planned}, "Kunlik reja")
