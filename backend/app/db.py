"""MySQL connectivity (8.4.6) — one engine, real queries for readiness."""

from __future__ import annotations

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

from app.config import SETTINGS

_engine: Engine | None = None


def dsn(with_database: bool = True) -> str:
    base = (
        f"mysql+pymysql://{SETTINGS.mysql_user}:{SETTINGS.mysql_password}"
        f"@{SETTINGS.mysql_host}:{SETTINGS.mysql_port}/"
    )
    if SETTINGS.mysql_socket:
        base = f"mysql+pymysql://{SETTINGS.mysql_user}:{SETTINGS.mysql_password}@/"
    url = base + (SETTINGS.mysql_database if with_database else "")
    if SETTINGS.mysql_socket:
        url += f"?unix_socket={SETTINGS.mysql_socket}"
    return url


def engine() -> Engine:
    global _engine
    if _engine is None:
        _engine = create_engine(dsn(), pool_pre_ping=True, pool_recycle=1800, future=True)
    return _engine


def ping() -> tuple[bool, str]:
    """Real round-trip: SELECT 1 must return 1."""
    try:
        with engine().connect() as conn:
            got = conn.execute(text("SELECT 1")).scalar_one()
        return (got == 1, "ok" if got == 1 else f"unexpected:{got}")
    except Exception as exc:
        return (False, f"{type(exc).__name__}")
