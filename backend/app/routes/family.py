from __future__ import annotations

from datetime import date

from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.extensions import db
from app.models import FamilyMember
from app.schemas.common import MessageSchema
from app.schemas.family import FamilyMemberSchema, FamilyMemberUpdateSchema
from app.utils.plans import summary_for_day
from app.utils.responses import error, success
from app.utils.serializers import family_dict, medicine_dict, schedule_dict

blp = Blueprint("family", __name__, description="Oila a'zolari")


def owned_member_or_404(member_id: int, user_id: int):
    return FamilyMember.query.filter_by(id=member_id, user_id=user_id).first_or_404()


def member_summary(user_id: int, member_id: int):
    counts, items = summary_for_day(user_id, date.today(), member_id)
    counts["today_medicines"] = [
        {
            **medicine_dict(item["medicine"], include_schedules=False),
            "schedule": schedule_dict(item["schedule"]),
            "planned_at": item["planned_at"].isoformat(),
            "status": item["status"],
        }
        for item in items
    ]
    return counts


@blp.route("", methods=["POST"])
@jwt_required()
@blp.arguments(FamilyMemberSchema)
@blp.response(201, MessageSchema)
def create_member(data):
    user_id = int(get_jwt_identity())
    member = FamilyMember(user_id=user_id, **data)
    db.session.add(member)
    db.session.commit()
    return success(family_dict(member, member_summary(user_id, member.id)), "Oila a'zosi qo'shildi", 201)


@blp.route("", methods=["GET"])
@jwt_required()
@blp.response(200, MessageSchema)
def list_members():
    user_id = int(get_jwt_identity())
    items = FamilyMember.query.filter_by(user_id=user_id).order_by(FamilyMember.created_at.desc()).all()
    return success({"family_members": [family_dict(item, member_summary(user_id, item.id)) for item in items]}, "Oila a'zolari")


@blp.route("/<int:member_id>", methods=["GET"])
@jwt_required()
@blp.response(200, MessageSchema)
def get_member(member_id):
    user_id = int(get_jwt_identity())
    item = owned_member_or_404(member_id, user_id)
    return success(family_dict(item, member_summary(user_id, item.id)), "Oila a'zosi")


@blp.route("/<int:member_id>", methods=["PUT"])
@jwt_required()
@blp.arguments(FamilyMemberUpdateSchema)
@blp.response(200, MessageSchema)
def update_member(data, member_id):
    user_id = int(get_jwt_identity())
    item = owned_member_or_404(member_id, user_id)
    for key, value in data.items():
        setattr(item, key, value)
    db.session.commit()
    return success(family_dict(item, member_summary(user_id, item.id)), "Oila a'zosi yangilandi")


@blp.route("/<int:member_id>", methods=["DELETE"])
@jwt_required()
@blp.response(200, MessageSchema)
def delete_member(member_id):
    user_id = int(get_jwt_identity())
    item = owned_member_or_404(member_id, user_id)
    db.session.delete(item)
    db.session.commit()
    return success({}, "Oila a'zosi o'chirildi")
