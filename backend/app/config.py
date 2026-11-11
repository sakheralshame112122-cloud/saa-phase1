"""Runtime configuration — names come from the environment; no value is ever stored in git."""

from __future__ import annotations

import os
from dataclasses import dataclass


def _int(name: str, default: int) -> int:
    raw = os.getenv(name)
    return int(raw) if raw not in (None, "") else default


@dataclass(frozen=True)
class Settings:
    app_env: str
    version: str
    mysql_host: str
    mysql_port: int
    mysql_database: str
    mysql_user: str
    mysql_password: str
    mysql_socket: str | None
    redis_url: str


def load_settings() -> Settings:
    from app import __version__

    return Settings(
        app_env=os.getenv("APP_ENV", "local"),
        version=__version__,
        mysql_host=os.getenv("MYSQL_HOST", "mysql"),
        mysql_port=_int("MYSQL_PORT", 3306),
        mysql_database=os.getenv("MYSQL_DATABASE", "saa_core"),
        mysql_user=os.getenv("MYSQL_USER", "saa"),
        mysql_password=os.getenv("MYSQL_PASSWORD", ""),
        mysql_socket=os.getenv("MYSQL_SOCKET") or None,
        redis_url=os.getenv("REDIS_URL", "redis://redis:6379/0"),
    )


SETTINGS = load_settings()
