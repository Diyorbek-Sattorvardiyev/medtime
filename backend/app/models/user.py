from __future__ import annotations

from datetime import datetime

from app.extensions import db


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(255), nullable=False, unique=True, index=True)
    password_hash = db.Column(db.String(255), nullable=True)
    google_id = db.Column(db.String(255), nullable=True, unique=True)
    is_email_verified = db.Column(db.Boolean, nullable=False, default=False)
    email_verified_at = db.Column(db.DateTime, nullable=True)
    avatar_url = db.Column(db.String(500), nullable=True)
    language = db.Column(db.String(2), nullable=False, default="uz")
    dark_mode = db.Column(db.Boolean, nullable=False, default=False)
    app_notifications_enabled = db.Column(db.Boolean, nullable=False, default=True)
    email_notifications_enabled = db.Column(db.Boolean, nullable=False, default=True)
    telegram_notifications_enabled = db.Column(db.Boolean, nullable=False, default=False)
    telegram_chat_id = db.Column(db.String(80), nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    refresh_tokens = db.relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")
    verification_codes = db.relationship("EmailVerificationCode", back_populates="user", cascade="all, delete-orphan")
    family_members = db.relationship("FamilyMember", back_populates="user", cascade="all, delete-orphan")
    medicines = db.relationship("Medicine", back_populates="user", cascade="all, delete-orphan")

