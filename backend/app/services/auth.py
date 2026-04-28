from __future__ import annotations

from datetime import datetime, timedelta

from app.extensions import db
from app.models import EmailVerificationCode, User
from app.services.email import send_verification_email
from app.utils.security import random_code


def create_email_code(user: User, purpose: str) -> str:
    EmailVerificationCode.query.filter_by(user_id=user.id, purpose=purpose, is_used=False).update({"is_used": True})
    code = random_code()
    db.session.add(
        EmailVerificationCode(
            user_id=user.id,
            code=code,
            purpose=purpose,
            expires_at=datetime.utcnow() + timedelta(minutes=15),
        )
    )
    db.session.commit()
    send_verification_email(user, code, purpose)
    return code


def valid_email_code(user: User, code: str, purpose: str) -> EmailVerificationCode | None:
    return (
        EmailVerificationCode.query.filter_by(user_id=user.id, code=code, purpose=purpose, is_used=False)
        .filter(EmailVerificationCode.expires_at > datetime.utcnow())
        .order_by(EmailVerificationCode.created_at.desc())
        .first()
    )
