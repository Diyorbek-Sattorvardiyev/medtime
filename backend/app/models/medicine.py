from __future__ import annotations

from datetime import datetime

from app.extensions import db


class Medicine(db.Model):
    __tablename__ = "medicines"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    family_member_id = db.Column(db.Integer, db.ForeignKey("family_members.id", ondelete="SET NULL"), nullable=True, index=True)
    name = db.Column(db.String(160), nullable=False)
    dosage = db.Column(db.String(120), nullable=False)
    intake_type = db.Column(db.String(32), nullable=False)
    notes = db.Column(db.Text, nullable=True)
    stock_quantity = db.Column(db.Integer, nullable=True)
    refill_threshold = db.Column(db.Integer, nullable=True)
    refill_reminder_enabled = db.Column(db.Boolean, nullable=False, default=False)
    start_date = db.Column(db.Date, nullable=False)
    end_date = db.Column(db.Date, nullable=True)
    active = db.Column(db.Boolean, nullable=False, default=True, index=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = db.relationship("User", back_populates="medicines")
    family_member = db.relationship("FamilyMember", back_populates="medicines")
    schedules = db.relationship("MedicineSchedule", back_populates="medicine", cascade="all, delete-orphan")
    logs = db.relationship("MedicineLog", back_populates="medicine", cascade="all, delete-orphan")


class MedicineSchedule(db.Model):
    __tablename__ = "medicine_schedules"

    id = db.Column(db.Integer, primary_key=True)
    medicine_id = db.Column(db.Integer, db.ForeignKey("medicines.id", ondelete="CASCADE"), nullable=False, index=True)
    time = db.Column(db.Time, nullable=False)
    repeat_days = db.Column(db.JSON, nullable=False, default=list)
    reminder_before_minutes = db.Column(db.Integer, nullable=False, default=0)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    medicine = db.relationship("Medicine", back_populates="schedules")
    logs = db.relationship("MedicineLog", back_populates="schedule", cascade="all, delete-orphan")


class MedicineLog(db.Model):
    __tablename__ = "medicine_logs"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    medicine_id = db.Column(db.Integer, db.ForeignKey("medicines.id", ondelete="CASCADE"), nullable=False, index=True)
    schedule_id = db.Column(db.Integer, db.ForeignKey("medicine_schedules.id", ondelete="CASCADE"), nullable=False, index=True)
    planned_at = db.Column(db.DateTime, nullable=False, index=True)
    status = db.Column(db.String(20), nullable=False, default="pending", index=True)
    taken_at = db.Column(db.DateTime, nullable=True)
    snoozed_until = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    medicine = db.relationship("Medicine", back_populates="logs")
    schedule = db.relationship("MedicineSchedule", back_populates="logs")
    user = db.relationship("User")

    __table_args__ = (
        db.UniqueConstraint("schedule_id", "planned_at", name="uq_schedule_planned_at"),
    )
