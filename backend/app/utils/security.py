from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta

import bcrypt
from flask_jwt_extended import create_access_token, create_refresh_token, get_jti

from app.extensions import db
from app.models import RefreshToken, User


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def check_password(password: str, password_hash: str | None) -> bool:
    if not password_hash:
        return False
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


def random_code(length: int = 6) -> str:
    return "".join(secrets.choice("0123456789") for _ in range(length))


def random_token_urlsafe(length: int = 32) -> str:
    return secrets.token_urlsafe(length)


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_tokens(user: User) -> dict:
    identity = str(user.id)
    access_token = create_access_token(identity=identity)
    refresh_token = create_refresh_token(identity=identity)
    db.session.add(
        RefreshToken(
            user_id=user.id,
            token_hash=token_hash(get_jti(refresh_token)),
            expires_at=datetime.utcnow() + timedelta(days=30),
        )
    )
    db.session.commit()
    return {"access_token": access_token, "refresh_token": refresh_token, "user_id": user.id}


def find_active_refresh(jti: str) -> RefreshToken | None:
    item = RefreshToken.query.filter_by(token_hash=token_hash(jti), revoked=False).first()
    if item and item.expires_at > datetime.utcnow():
        return item
    return None


def revoke_refresh(jti: str) -> bool:
    item = find_active_refresh(jti)
    if not item:
        return False
    item.revoked = True
    db.session.commit()
    return True


def revoke_all_user_refresh_tokens(user_id: int) -> None:
    RefreshToken.query.filter_by(user_id=user_id, revoked=False).update({"revoked": True})
    db.session.commit()
