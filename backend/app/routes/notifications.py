from __future__ import annotations

from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.models import NotificationLog
from app.schemas.common import MessageSchema
from app.utils.responses import success
from app.utils.serializers import notification_dict

blp = Blueprint("notifications", __name__, description="Bildirishnomalar")


@blp.route("", methods=["GET"])
@jwt_required()
@blp.response(200, MessageSchema)
def notifications():
    user_id = int(get_jwt_identity())
    items = NotificationLog.query.filter_by(user_id=user_id).order_by(NotificationLog.created_at.desc()).limit(100).all()
    return success({"notifications": [notification_dict(item) for item in items]}, "Bildirishnoma tarixi")
