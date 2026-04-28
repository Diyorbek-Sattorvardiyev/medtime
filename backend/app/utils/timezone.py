from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo


TASHKENT = ZoneInfo("Asia/Tashkent")


def tashkent_now() -> datetime:
    return datetime.now(TASHKENT).replace(tzinfo=None)


def tashkent_today():
    return tashkent_now().date()
