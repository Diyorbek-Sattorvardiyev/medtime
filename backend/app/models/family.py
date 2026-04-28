from __future__ import annotations

from datetime import datetime

from app.extensions import db


class FamilyMember(db.Model):
    __tablename__ = "family_members"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    full_name = db.Column(db.String(120), nullable=False)
    relationship = db.Column(db.String(80), nullable=False)
    birth_date = db.Column(db.Date, nullable=True)
    avatar_url = db.Column(db.String(500), nullable=True)
    avatar_color = db.Column(db.String(32), nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = db.relationship("User", back_populates="family_members")
    medicines = db.relationship("Medicine", back_populates="family_member")
