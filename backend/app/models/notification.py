from __future__ import annotations

from datetime import datetime

from app.extensions import db


class NotificationLog(db.Model):
    __tablename__ = "notification_logs"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    medicine_id = db.Column(db.Integer, db.ForeignKey("medicines.id", ondelete="SET NULL"), nullable=True, index=True)
    schedule_id = db.Column(db.Integer, db.ForeignKey("medicine_schedules.id", ondelete="SET NULL"), nullable=True, index=True)
    channel = db.Column(db.String(20), nullable=False)
    title = db.Column(db.String(160), nullable=False)
    message = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), nullable=False, default="sent")
    error_message = db.Column(db.Text, nullable=True)
    sent_at = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    user = db.relationship("User")
    medicine = db.relationship("Medicine")
    schedule = db.relationship("MedicineSchedule")

