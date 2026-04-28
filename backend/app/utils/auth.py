from __future__ import annotations

from flask_jwt_extended import get_jwt_identity

from app.models import User


def current_user() -> User:
    return User.query.get_or_404(int(get_jwt_identity()))
